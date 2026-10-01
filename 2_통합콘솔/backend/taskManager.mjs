import path from "node:path";
import crypto from "node:crypto";
import fs from "node:fs";
import { spawn } from "node:child_process";
import { query } from "@anthropic-ai/claude-agent-sdk";
import {
  createWorktree,
  removeWorktree,
  getCurrentBranch,
  ensureInitialCommit,
  getRevision,
  commitAll,
  fastForwardMerge,
  deleteBranch,
  branchExists,
  assertFrozenTarget,
  restoreFrozenTarget,
} from "./git.mjs";
import { collectDiff, saveSnapshot } from "./diff.mjs";
import { requestReview } from "./codexReview.mjs";

const tasks = new Map();
let activeTaskId = null;
let pendingReviewTaskId = null;
let pendingCleanupTaskId = null;
let tasksFile = null;

function persistedTask(task) {
  const { queryHandle, abortController, timeoutHandle, ...data } = task;
  return data;
}

function persistTasks() {
  if (!tasksFile) return;
  fs.mkdirSync(path.dirname(tasksFile), { recursive: true });
  const temporary = `${tasksFile}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify([...tasks.values()].map(persistedTask), null, 2));
  fs.renameSync(temporary, tasksFile);
}

export function initTaskManager(runtimeRoot) {
  tasksFile = path.join(runtimeRoot, "tasks.json");
  tasks.clear();
  activeTaskId = null;
  pendingReviewTaskId = null;
  pendingCleanupTaskId = null;

  if (!fs.existsSync(tasksFile)) return;
  const stored = JSON.parse(fs.readFileSync(tasksFile, "utf8"));
  for (const rawTask of stored) {
    const task = { ...rawTask, queryHandle: null, abortController: null, timeoutHandle: null };
    task.runs ??= [];
    if (["starting", "running", "revising", "revision_aborting"].includes(task.status)) {
      task.status = "failed";
      task.error = "서버가 작업 실행 중 재시작되었습니다. 남은 worktree를 확인한 뒤 정리해주세요.";
      task.finishedAt = new Date().toISOString();
    }
    if (task.review?.status === "running") {
      task.review = {
        ...task.review,
        status: "failed",
        error: "서버 재시작으로 Codex 리뷰가 중단되었습니다.",
        completedAt: new Date().toISOString(),
      };
    }
    tasks.set(task.id, task);
  }

  const pending = [...tasks.values()]
    .filter((task) => task.status === "completed")
    .sort((a, b) => String(b.finishedAt).localeCompare(String(a.finishedAt)));
  pendingReviewTaskId = pending[0]?.id ?? null;
  const cleanupPending = [...tasks.values()]
    .filter((task) => (task.status === "failed" || task.status === "aborted") && !task.artifactsCleaned)
    .sort((a, b) => String(b.finishedAt).localeCompare(String(a.finishedAt)));
  pendingCleanupTaskId = cleanupPending[0]?.id ?? null;
  persistTasks();
}

export function getTask(id) {
  return tasks.get(id);
}

export function isBusy() {
  return activeTaskId !== null || pendingReviewTaskId !== null || pendingCleanupTaskId !== null;
}

export function busyReason() {
  if (activeTaskId) return "다른 작업이 실행 중입니다.";
  if (pendingReviewTaskId) return "이전 작업의 승인/반려가 필요합니다.";
  if (pendingCleanupTaskId) return "이전 실패 작업의 임시 worktree를 먼저 정리해주세요.";
  return null;
}

export function projectRemovalBlockReason(projectId) {
  if (activeTaskId && tasks.get(activeTaskId)?.projectId === projectId) {
    return "실행 중인 작업을 먼저 완료하거나 중단해주세요.";
  }
  if (pendingReviewTaskId && tasks.get(pendingReviewTaskId)?.projectId === projectId) {
    return "승인/반려 대기 중인 작업을 먼저 처리해주세요.";
  }
  if (pendingCleanupTaskId && tasks.get(pendingCleanupTaskId)?.projectId === projectId) {
    return "실패 작업의 임시 worktree를 먼저 정리해주세요.";
  }
  return null;
}

function taskTimeoutMs() {
  const configured = Number(process.env.CLAUDE_TASK_TIMEOUT_MS);
  return Number.isFinite(configured) && configured > 0 ? configured : 30 * 60 * 1000;
}

function getTaskAgentConfig(task, agent) {
  return task.agentConfig?.[agent] ?? { model: "default", effort: null };
}

function beginAgentRun(task, { agent, kind, config }) {
  task.runs ??= [];
  const run = {
    id: crypto.randomUUID(),
    agent,
    kind,
    requestedModel: config.model,
    effort: config.effort,
    actualModels: [],
    status: "running",
    usage: null,
    estimatedCostUsd: null,
    threadId: null,
    startedAt: new Date().toISOString(),
    completedAt: null,
  };
  task.runs.push(run);
  return run;
}

function publishRun(task, run, broadcast) {
  emit(task, { type: "usage", run: structuredClone(run) }, broadcast);
}

function completeUnfinishedRun(task, run, status, broadcast) {
  if (!run || run.status !== "running") return;
  run.status = status;
  run.completedAt = new Date().toISOString();
  publishRun(task, run, broadcast);
}

function applyClaudeResult(run, message) {
  const modelEntries = Object.entries(message.modelUsage ?? {});
  const usage = {
    inputTokens: 0,
    cachedInputTokens: 0,
    cacheCreationInputTokens: 0,
    outputTokens: 0,
    reasoningTokens: 0,
  };
  const actualModels = new Set(run.actualModels);
  let modelCost = 0;

  for (const [model, modelUsage] of modelEntries) {
    actualModels.add(modelUsage.canonicalModel || model);
    usage.inputTokens += Number(modelUsage.inputTokens) || 0;
    usage.cachedInputTokens += Number(modelUsage.cacheReadInputTokens) || 0;
    usage.cacheCreationInputTokens += Number(modelUsage.cacheCreationInputTokens) || 0;
    usage.outputTokens += Number(modelUsage.outputTokens) || 0;
    usage.reasoningTokens += Number(modelUsage.thinkingTokens) || 0;
    modelCost += Number(modelUsage.costUSD) || 0;
  }

  run.actualModels = [...actualModels];
  run.usage = modelEntries.length > 0 ? usage : null;
  run.estimatedCostUsd = Number.isFinite(message.total_cost_usd)
    ? message.total_cost_usd
    : modelEntries.length > 0
      ? modelCost
      : null;
  run.status = message.is_error ? "failed" : "done";
  run.completedAt = new Date().toISOString();
}

export function serializeTask(task) {
  const { queryHandle, abortController, timeoutHandle, diff, ...safe } = task;
  return {
    ...safe,
    diff: diff ? { changedFiles: diff.changedFiles, stat: diff.stat, diffHash: diff.diffHash } : null,
  };
}

function emit(task, event, broadcast) {
  const stamped = { ...event, taskId: task.id, at: new Date().toISOString() };
  task.events.push(stamped);
  persistTasks();
  broadcast(stamped);
}

export async function startTask(
  { instruction, projectId, projectPath, baseBranch, worktreesRoot, reviewsRoot, agentConfig },
  broadcast
) {
  if (isBusy()) {
    throw new Error(busyReason() ?? "BUSY");
  }

  const id = crypto.randomUUID();
  const branchName = `task/${id.slice(0, 8)}`;
  const worktreeDir = path.join(worktreesRoot, id);
  const task = {
    id,
    projectId,
    instruction,
    projectPath,
    branchName,
    worktreeDir,
    baseBranch: null,
    baseSha: null,
    targetSha: null,
    status: "starting",
    events: [],
    diff: null,
    review: null,
    createdAt: new Date().toISOString(),
    finishedAt: null,
    error: null,
    queryHandle: null,
    abortController: new AbortController(),
    timeoutHandle: null,
    timedOut: false,
    artifactsCleaned: false,
    cleanupError: null,
    operation: "initial",
    abortRequested: false,
    revisionCount: 0,
    reviewHistory: [],
    agentConfig: structuredClone(agentConfig),
    runs: [],
  };
  tasks.set(id, task);
  activeTaskId = id;
  persistTasks();

  runTask(task, { baseBranch, broadcast, reviewsRoot }).catch(() => {});

  return task;
}

async function runTask(task, { baseBranch, broadcast, reviewsRoot }) {
  let agentRun = null;
  try {
    emit(task, { type: "log", role: "Claude", text: `요청 확인: "${task.instruction}"` }, broadcast);

    await ensureInitialCommit(task.projectPath);
    const resolvedBase = baseBranch || (await getCurrentBranch(task.projectPath));
    await createWorktree({
      projectPath: task.projectPath,
      baseBranch: resolvedBase,
      branchName: task.branchName,
      worktreeDir: task.worktreeDir,
    });
    task.baseBranch = resolvedBase;
    task.baseSha = await getRevision(task.worktreeDir, "HEAD");

    if (task.status === "aborted") return;

    task.status = "running";
    emit(task, { type: "status", status: "running" }, broadcast);

    const timeoutMs = taskTimeoutMs();
    task.timeoutMs = timeoutMs;
    task.timeoutHandle = setTimeout(() => {
      task.timedOut = true;
      task.abortController?.abort();
      task.queryHandle?.close?.();
    }, timeoutMs);

    const claudeConfig = getTaskAgentConfig(task, "claude");
    agentRun = beginAgentRun(task, { agent: "claude", kind: "implementation", config: claudeConfig });
    publishRun(task, agentRun, broadcast);

    const q = query({
      prompt: task.instruction,
      options: {
        cwd: task.worktreeDir,
        permissionMode: "acceptEdits",
        abortController: task.abortController,
        ...(claudeConfig.model !== "default" ? { model: claudeConfig.model } : {}),
        ...(claudeConfig.effort ? { effort: claudeConfig.effort } : {}),
      },
    });
    task.queryHandle = q;

    for await (const message of q) {
      if (task.status === "aborted") break;
      handleMessage(task, message, broadcast, agentRun);
    }

    if (task.status === "aborted") return;
    if (task.timedOut) {
      throw new Error(`Claude 작업이 제한 시간(${Math.round(timeoutMs / 60000)}분)을 초과했습니다.`);
    }
    if (task.status === "failed") {
      throw new Error(task.error || "Claude 작업이 실패했습니다.");
    }

    const commitMessage = task.instruction.trim().slice(0, 72) || `Task ${task.id.slice(0, 8)}`;
    await commitAll({ cwd: task.worktreeDir, message: commitMessage });
    task.targetSha = await getRevision(task.worktreeDir, "HEAD");
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });

    const diffResult = await collectDiff({ worktreeDir: task.worktreeDir, baseSha: task.baseSha });
    diffResult.targetSha = task.targetSha;
    saveSnapshot({
      reviewsRoot,
      taskId: task.id,
      diffResult,
      branchName: task.branchName,
      targetSha: task.targetSha,
    });
    task.diff = diffResult;
    task.status = "completed";
    task.finishedAt = new Date().toISOString();
    pendingReviewTaskId = task.id;
    if (activeTaskId === task.id) activeTaskId = null;
    emit(task, { type: "status", status: "completed" }, broadcast);
  } catch (err) {
    if (task.status !== "aborted") {
      task.status = "failed";
      task.error = task.timedOut
        ? `Claude 작업이 제한 시간(${Math.round(task.timeoutMs / 60000)}분)을 초과했습니다.`
        : String(err?.message ?? err);
      task.finishedAt = new Date().toISOString();
      pendingCleanupTaskId = task.id;
      if (activeTaskId === task.id) activeTaskId = null;
      emit(task, { type: "status", status: "failed", error: task.error }, broadcast);
    }
  } finally {
    completeUnfinishedRun(task, agentRun, task.status === "aborted" ? "aborted" : "failed", broadcast);
    if (task.timeoutHandle) clearTimeout(task.timeoutHandle);
    task.timeoutHandle = null;
    task.queryHandle = null;
    task.abortController = null;
    task.operation = null;
    if (task.status === "aborted") {
      const cleaned = await cleanupArtifacts(task);
      if (cleaned) {
        emit(task, { type: "artifacts_cleaned" }, broadcast);
      } else {
        pendingCleanupTaskId = task.id;
        persistTasks();
      }
    }
    if (activeTaskId === task.id) activeTaskId = null;
    persistTasks();
  }
}

function handleMessage(task, message, broadcast, agentRun) {
  if (message.type === "assistant") {
    if (message.message?.model && agentRun && !agentRun.actualModels.includes(message.message.model)) {
      agentRun.actualModels.push(message.message.model);
    }
    for (const block of message.message?.content ?? []) {
      if (block.type === "text" && block.text?.trim()) {
        emit(task, { type: "log", role: "Claude", text: block.text.trim() }, broadcast);
      } else if (block.type === "tool_use") {
        emit(task, { type: "log", role: "도구", text: summarizeToolUse(block) }, broadcast);
      }
    }
  } else if (message.type === "user") {
    for (const block of message.message?.content ?? []) {
      if (block.type === "tool_result") {
        const summary = summarizeToolResult(block);
        if (summary) emit(task, { type: "log", role: "도구", text: summary }, broadcast);
      }
    }
  } else if (message.type === "result") {
    if (agentRun) {
      applyClaudeResult(agentRun, message);
      publishRun(task, agentRun, broadcast);
    }
    if (message.is_error) {
      task.status = "failed";
      task.error = typeof message.result === "string" ? message.result : "unknown error";
    }
  }
}

function summarizeToolUse(block) {
  const name = block.name ?? "tool";
  const input = block.input ?? {};
  if (name === "Edit" || name === "Write") {
    return `파일 수정 · ${input.file_path ?? ""}`;
  }
  if (name === "Bash") {
    return `실행 · ${input.command ?? ""}`;
  }
  if (name === "Read") {
    return `파일 읽기 · ${input.file_path ?? ""}`;
  }
  return `${name} 호출`;
}

function summarizeToolResult(block) {
  const content = Array.isArray(block.content)
    ? block.content.map((c) => c.text ?? "").join(" ")
    : block.content;
  if (!content) return null;
  return String(content).split("\n")[0].slice(0, 200);
}

export async function abortTask(id, broadcast) {
  const task = tasks.get(id);
  if (!task || !["running", "starting", "revising"].includes(task.status)) return false;

  const isRevision = task.operation === "revision";
  task.abortRequested = true;
  task.status = isRevision ? "revision_aborting" : "aborted";
  if (!isRevision) task.finishedAt = new Date().toISOString();
  try {
    task.abortController?.abort();
    task.queryHandle?.close?.();
  } catch {
    // ignore
  }
  emit(task, { type: "status", status: task.status }, broadcast);
  return true;
}

function assertExpectedSnapshot(task, { expectedDiffHash, expectedTargetSha }) {
  if (!task.diff || task.diff.diffHash !== expectedDiffHash || task.targetSha !== expectedTargetSha) {
    throw new Error("화면에서 확인한 diff와 현재 승인 대상이 다릅니다. diff를 새로 불러와 다시 확인해주세요.");
  }
}

async function cleanupArtifacts(task) {
  const errors = [];
  if (fs.existsSync(task.worktreeDir)) {
    try {
      await removeWorktree({ projectPath: task.projectPath, worktreeDir: task.worktreeDir });
    } catch (err) {
      errors.push(String(err?.message ?? err));
    }
  }

  try {
    if (await branchExists({ projectPath: task.projectPath, branchName: task.branchName })) {
      await deleteBranch({ projectPath: task.projectPath, branchName: task.branchName, force: true });
    }
  } catch (err) {
    errors.push(String(err?.message ?? err));
  }

  task.artifactsCleaned = errors.length === 0;
  task.cleanupError = errors.length > 0 ? errors.join("\n") : null;
  return task.artifactsCleaned;
}

export async function approveTask(id, expectedSnapshot, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId) {
    throw new Error("승인 대상 작업이 아닙니다.");
  }
  if (task.status !== "completed" || activeTaskId) {
    throw new Error("Claude 작업이 진행 중입니다. 완료 후 다시 시도해주세요.");
  }
  if (task.review?.status === "running") {
    throw new Error("Codex 리뷰가 진행 중입니다. 완료 후 다시 시도해주세요.");
  }

  assertExpectedSnapshot(task, expectedSnapshot);
  await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
  const mergedSha = await fastForwardMerge({
    projectPath: task.projectPath,
    targetSha: task.targetSha,
    expectedBaseBranch: task.baseBranch,
    expectedBaseSha: task.baseSha,
  });

  await cleanupArtifacts(task);

  task.status = "approved";
  task.approvedAt = new Date().toISOString();
  task.mergedSha = mergedSha;
  pendingReviewTaskId = null;
  emit(
    task,
    { type: "status", status: "approved", artifactsCleaned: task.artifactsCleaned, cleanupError: task.cleanupError },
    broadcast
  );
  return task;
}

export async function rejectTask(id, reason, expectedSnapshot, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId) {
    throw new Error("반려 대상 작업이 아닙니다.");
  }
  if (task.status !== "completed" || activeTaskId) {
    throw new Error("Claude 작업이 진행 중입니다. 완료 후 다시 시도해주세요.");
  }
  if (task.review?.status === "running") {
    throw new Error("Codex 리뷰가 진행 중입니다. 완료 후 다시 시도해주세요.");
  }

  assertExpectedSnapshot(task, expectedSnapshot);
  await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
  const cleaned = await cleanupArtifacts(task);
  if (!cleaned) throw new Error(`worktree 정리 실패: ${task.cleanupError}`);

  task.status = "rejected";
  task.rejectedAt = new Date().toISOString();
  task.rejectReason = reason;
  pendingReviewTaskId = null;
  emit(task, { type: "status", status: "rejected", artifactsCleaned: true }, broadcast);
  return task;
}

export async function cleanupTaskArtifacts(id, broadcast) {
  const task = tasks.get(id);
  const cleanupStatuses = new Set(["failed", "aborted", "approved", "rejected"]);
  if (!task || !cleanupStatuses.has(task.status) || task.artifactsCleaned) {
    throw new Error("정리할 임시 작업이 없습니다.");
  }
  if (task.id === activeTaskId) {
    throw new Error("작업 프로세스가 아직 종료 중입니다. 잠시 후 다시 시도해주세요.");
  }

  const cleaned = await cleanupArtifacts(task);
  if (!cleaned) throw new Error(`worktree 정리 실패: ${task.cleanupError}`);
  if (pendingCleanupTaskId === task.id) pendingCleanupTaskId = null;
  emit(task, { type: "artifacts_cleaned" }, broadcast);
  return task;
}

// 사용자가 Claude 작업 결과를 직접 실행/확인해볼 수 있도록 worktree 폴더를
// 탐색기로 열어준다. 승인/반려/정리 전까지는 worktree가 디스크에 남아 있다.
export function openTaskFolder(id) {
  const task = tasks.get(id);
  if (!task) throw new Error("작업을 찾을 수 없습니다.");
  if (!fs.existsSync(task.worktreeDir)) {
    throw new Error("작업 폴더가 없습니다 (이미 정리되었거나 아직 생성되지 않았습니다).");
  }
  spawn("explorer", [task.worktreeDir], { detached: true, stdio: "ignore" }).unref();
}

function buildRevisionPrompt(task, extraInstruction) {
  const review = task.review;
  const findings = (review.findings ?? []).map((finding, index) => ({
    number: index + 1,
    file: finding.file,
    line: finding.line,
    severity: finding.severity,
    message: finding.message,
  }));
  const lines = [
    "Codex 코드 리뷰를 바탕으로 현재 구현을 수정해줘.",
    `원래 작업 요청: ${task.instruction}`,
    `리뷰 요약: ${review.summary || "없음"}`,
    `리뷰 findings: ${JSON.stringify(findings, null, 2)}`,
    "리뷰 지적을 실제 코드와 대조한 뒤 타당한 문제를 수정하고, 관련 테스트도 보완해줘.",
    "현재 작업 범위를 벗어난 변경은 만들지 마.",
  ];
  if (extraInstruction) lines.push(`사용자 추가 지시: ${extraInstruction}`);
  return lines.join("\n\n");
}

export async function requestRevision({ id, extraInstruction, reviewsRoot }, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId || task.status !== "completed") {
    throw new Error("수정 요청 대상 작업이 아닙니다.");
  }
  if (activeTaskId || task.review?.status === "running") {
    throw new Error("다른 작업 또는 리뷰가 진행 중입니다.");
  }
  if (task.review?.status !== "done") {
    throw new Error("완료된 Codex 리뷰가 있어야 수정 요청을 할 수 있습니다.");
  }

  await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
  const previous = {
    targetSha: task.targetSha,
    diff: task.diff,
    review: task.review,
  };

  task.status = "revising";
  task.operation = "revision";
  task.abortRequested = false;
  task.timedOut = false;
  task.error = null;
  task.abortController = new AbortController();
  activeTaskId = task.id;
  emit(task, { type: "status", status: "revising" }, broadcast);

  runRevision(task, { previous, extraInstruction, reviewsRoot, broadcast }).catch(() => {});
  return task;
}

async function runRevision(task, { previous, extraInstruction, reviewsRoot, broadcast }) {
  const timeoutMs = taskTimeoutMs();
  let agentRun = null;
  try {
    emit(task, { type: "log", role: "Claude", text: "Codex 리뷰를 바탕으로 수정 작업을 시작합니다." }, broadcast);
    task.timeoutMs = timeoutMs;
    task.timeoutHandle = setTimeout(() => {
      task.timedOut = true;
      task.abortController?.abort();
      task.queryHandle?.close?.();
    }, timeoutMs);

    const claudeConfig = getTaskAgentConfig(task, "claude");
    agentRun = beginAgentRun(task, {
      agent: "claude",
      kind: `revision-${(task.revisionCount ?? 0) + 1}`,
      config: claudeConfig,
    });
    publishRun(task, agentRun, broadcast);

    const q = query({
      prompt: buildRevisionPrompt(task, extraInstruction),
      options: {
        cwd: task.worktreeDir,
        permissionMode: "acceptEdits",
        abortController: task.abortController,
        ...(claudeConfig.model !== "default" ? { model: claudeConfig.model } : {}),
        ...(claudeConfig.effort ? { effort: claudeConfig.effort } : {}),
      },
    });
    task.queryHandle = q;

    for await (const message of q) {
      if (task.abortRequested) break;
      handleMessage(task, message, broadcast, agentRun);
    }

    if (task.abortRequested) throw new Error("수정 요청이 중단되었습니다.");
    if (task.timedOut) throw new Error(`수정 작업이 제한 시간(${Math.round(timeoutMs / 60000)}분)을 초과했습니다.`);
    if (task.status === "failed") throw new Error(task.error || "수정 작업이 실패했습니다.");

    const revisionNumber = (task.revisionCount ?? 0) + 1;
    const commitMessage = `Revise task ${task.id.slice(0, 8)} (${revisionNumber})`;
    await commitAll({ cwd: task.worktreeDir, message: commitMessage });
    const targetSha = await getRevision(task.worktreeDir, "HEAD");
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha });

    const diffResult = await collectDiff({ worktreeDir: task.worktreeDir, baseSha: task.baseSha });
    diffResult.targetSha = targetSha;
    saveSnapshot({
      reviewsRoot,
      taskId: task.id,
      diffResult,
      branchName: task.branchName,
      targetSha,
    });

    task.reviewHistory ??= [];
    task.reviewHistory.push({
      ...previous.review,
      reviewedTargetSha: previous.targetSha,
      supersededAt: new Date().toISOString(),
    });
    task.targetSha = targetSha;
    task.diff = diffResult;
    task.review = null;
    task.revisionCount = revisionNumber;
    task.status = "completed";
    task.finishedAt = new Date().toISOString();
    task.error = null;
    if (activeTaskId === task.id) activeTaskId = null;
    emit(task, { type: "status", status: "completed", revised: true }, broadcast);
  } catch (err) {
    try {
      await restoreFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: previous.targetSha });
      task.targetSha = previous.targetSha;
      task.diff = previous.diff;
      task.review = previous.review;
      task.status = "completed";
      const failureReason = task.timedOut
        ? `수정 작업이 제한 시간(${Math.round(timeoutMs / 60000)}분)을 초과했습니다.`
        : String(err?.message ?? err);
      task.error = task.abortRequested
        ? "수정 요청을 중단하고 이전 검토 버전으로 복구했습니다."
        : `수정 요청 실패, 이전 검토 버전으로 복구했습니다: ${failureReason}`;
      if (activeTaskId === task.id) activeTaskId = null;
      emit(
        task,
        { type: "status", status: "completed", revisionFailed: true, error: task.error },
        broadcast
      );
    } catch (restoreError) {
      task.status = "failed";
      task.error = `수정 실패 후 복구에도 실패했습니다: ${String(restoreError?.message ?? restoreError)}`;
      pendingReviewTaskId = null;
      pendingCleanupTaskId = task.id;
      if (activeTaskId === task.id) activeTaskId = null;
      emit(task, { type: "status", status: "failed", error: task.error }, broadcast);
    }
  } finally {
    completeUnfinishedRun(task, agentRun, task.abortRequested ? "aborted" : "failed", broadcast);
    if (task.timeoutHandle) clearTimeout(task.timeoutHandle);
    task.timeoutHandle = null;
    task.queryHandle = null;
    task.abortController = null;
    task.abortRequested = false;
    task.timedOut = false;
    task.operation = null;
    if (activeTaskId === task.id) activeTaskId = null;
    persistTasks();
  }
}

export function requestCodexReview({ id, extraInstruction, reviewsRoot }, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId) {
    throw new Error("리뷰 요청 대상 작업이 아닙니다.");
  }
  if (task.status !== "completed" || activeTaskId) {
    throw new Error("Claude 작업이 진행 중입니다. 완료 후 다시 시도해주세요.");
  }
  if (task.review?.status === "running") {
    throw new Error("이미 리뷰가 진행 중입니다.");
  }

  const codexConfig = getTaskAgentConfig(task, "codex");
  const agentRun = beginAgentRun(task, { agent: "codex", kind: "review", config: codexConfig });
  task.review = {
    status: "running",
    findings: [],
    summary: null,
    error: null,
    requestedAt: new Date().toISOString(),
    completedAt: null,
    runId: agentRun.id,
    model: codexConfig.model,
    effort: codexConfig.effort,
    usage: null,
  };
  publishRun(task, agentRun, broadcast);
  emit(task, { type: "review_status", status: "running" }, broadcast);

  (async () => {
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });

    const result = await requestReview({
      worktreeDir: task.worktreeDir,
      reviewsRoot,
      taskId: task.id,
      instruction: task.instruction,
      extraInstruction,
      baseSha: task.baseSha,
      targetSha: task.targetSha,
      model: codexConfig.model,
      effort: codexConfig.effort,
    });
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
    return result;
  })()
    .then((result) => {
      agentRun.status = "done";
      agentRun.usage = result.usage ?? null;
      agentRun.threadId = result.threadId ?? null;
      agentRun.actualModels = codexConfig.model === "default" ? [] : [codexConfig.model];
      agentRun.completedAt = new Date().toISOString();
      task.review = {
        status: "done",
        findings: result.findings ?? [],
        summary: result.summary ?? "",
        error: null,
        requestedAt: task.review.requestedAt,
        completedAt: new Date().toISOString(),
        runId: agentRun.id,
        model: codexConfig.model,
        effort: codexConfig.effort,
        usage: result.usage ?? null,
      };
      publishRun(task, agentRun, broadcast);
      emit(task, { type: "review_status", status: "done" }, broadcast);
    })
    .catch((err) => {
      agentRun.status = "failed";
      agentRun.completedAt = new Date().toISOString();
      task.review = {
        ...task.review,
        status: "failed",
        error: String(err?.message ?? err),
        completedAt: new Date().toISOString(),
      };
      publishRun(task, agentRun, broadcast);
      emit(task, { type: "review_status", status: "failed", error: task.review.error }, broadcast);
    });

  return task;
}
