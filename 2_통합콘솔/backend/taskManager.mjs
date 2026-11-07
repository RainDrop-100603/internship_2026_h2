import path from "node:path";
import crypto from "node:crypto";
import fs from "node:fs";
import { spawn } from "node:child_process";
import { query } from "@anthropic-ai/claude-agent-sdk";
import {
  createWorktree,
  removeWorktree,
  pruneWorktrees,
  getCurrentBranch,
  ensureInitialCommit,
  getRevision,
  commitAll,
  fastForwardMerge,
  deleteBranch,
  branchExists,
  assertFrozenTarget,
  assertFastForwardable,
  restoreFrozenTarget,
} from "./git.mjs";
import { collectDiff, saveSnapshot } from "./diff.mjs";
import { requestReview } from "./codexReview.mjs";
import {
  pullAbapObjects,
  applyAbapChanges,
  rehearseAbapChanges,
  deleteRehearsalObjects,
  rehearsalKey,
  classifyAbapFile,
} from "./abapSync.mjs";
import { resolveAgentConfig } from "./settings.mjs";
import { readCodexSessionModel, sameModel } from "./modelCatalog.mjs";

const ABAP_SYNC_PACKAGE = process.env.ABAP_SYNC_PACKAGE || "ZPKG_YJ_1014";

// 콘솔에는 도구 사용 승인 화면이 없다. 승인이 필요한 도구 호출을 SDK 기본 동작에 맡기면
// "you haven't granted it yet"으로 거부되고, Claude가 사용자 승인을 기다리며 멈춰버린다.
// 그래서 (1) 읽기 전용 웹 조회는 미리 허용하고, (2) 나머지는 이유를 설명하며 즉시 거부해
// Claude가 승인 요청 없이 허용된 도구로 계속 진행하게 한다.
const AUTO_ALLOWED_TOOLS = new Set(["WebFetch", "WebSearch"]);

async function resolveWithoutPrompt(toolName, input) {
  if (AUTO_ALLOWED_TOOLS.has(toolName)) return { behavior: "allow", updatedInput: input };
  return {
    behavior: "deny",
    message:
      `통합 콘솔에는 도구 승인 화면이 없어 ${toolName}은(는) 자동 거부된다. ` +
      "사용자에게 승인을 요청하거나 기다리지 말고, 파일 읽기·편집 등 허용된 도구로 작업을 계속하라. " +
      "이 도구 없이 확인하지 못한 부분은 최종 결과 요약에 '확인 필요'로 적어라.",
  };
}

function agentQueryOptions(task) {
  return {
    cwd: task.worktreeDir,
    permissionMode: "acceptEdits",
    canUseTool: resolveWithoutPrompt,
    // worktree는 원본 저장소의 복사본이라 .mcp.json(abap-trial)이 함께 딸려 온다.
    // Claude가 SAP 서버를 직접 호출하면 diff·Codex 리뷰·승인을 건너뛰게 되므로 MCP는 로드하지 않는다.
    // (ABAP 서버 반영은 승인 시 백엔드의 abapSync만 수행한다.)
    strictMcpConfig: true,
    abortController: task.abortController,
  };
}

const tasks = new Map();
let activeTaskId = null;
let pendingReviewTaskId = null;
let pendingCleanupTaskId = null;
let tasksFile = null;
// 승인(서버 반영 + 병합)이 진행 중인 작업 ID. 메모리에만 둔다.
const approvingTaskIds = new Set();
// 승인 전 서버 검사(리허설)가 진행 중인 작업 ID. 검사와 승인·수정이 겹치지 않게 한다.
const abapCheckingTaskIds = new Set();

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
    // 요청 모델이 실제로 가리키는 모델 ID(카탈로그 기준). 실행 후 보고된 모델과 비교한다.
    expectedModel: config.expectedModel ?? null,
    mainModel: null,
    modelMismatch: null,
    actualModels: [],
    actualEffort: null,
    modelSource: null,
    effortSource: null,
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

export function applyClaudeRuntimeMetadata(run, message) {
  if (!run || message?.type !== "system" || message?.subtype !== "init") return false;

  let changed = false;
  if (message.model && !run.actualModels.includes(message.model)) {
    run.actualModels.push(message.model);
    run.modelSource = "reported";
    changed = true;
  }
  // init의 model이 이 세션의 주 모델이다. result의 modelUsage에 함께 나오는 다른 모델(예: Haiku)은
  // SDK가 내부 보조 작업에 쓰는 것이라 주 모델과 구분한다.
  if (message.model && run.mainModel !== message.model) {
    run.mainModel = message.model;
    run.modelMismatch =
      run.expectedModel && !sameModel(run.expectedModel, message.model)
        ? { expected: run.expectedModel, actual: message.model }
        : null;
    changed = true;
  }
  if (message.effort && run.actualEffort !== message.effort) {
    run.actualEffort = message.effort;
    run.effortSource = "reported";
    changed = true;
  }
  return changed;
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
  if (modelEntries.length > 0) run.modelSource = "reported";
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
  { instruction, projectId, projectPath, baseBranch, worktreesRoot, reviewsRoot, agentConfig, abapMode },
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
    mergeBaseSha: null,
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
    abapMode: Boolean(abapMode),
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
    // 원본 프로젝트가 실제로 이 커밋에 있었는지(ff-merge 검증용) — ABAP pull로
    // baseSha가 뒤로 밀리더라도 이 값은 원본 프로젝트 HEAD를 그대로 가리켜야 한다.
    task.mergeBaseSha = await getRevision(task.worktreeDir, "HEAD");

    if (task.abapMode) {
      const { pulled, skipped } = await pullAbapObjects({
        packageName: ABAP_SYNC_PACKAGE,
        worktreeDir: task.worktreeDir,
      });
      emit(
        task,
        {
          type: "log",
          role: "도구",
          text: `ABAP 가져오기 완료 · ${pulled.length}개 오브젝트${skipped.length ? ` (미지원 타입 ${skipped.length}개 건너뜀)` : ""}`,
        },
        broadcast
      );
      await commitAll({ cwd: task.worktreeDir, message: "ABAP pull baseline" });
    }
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

    // 지정한 모델을 이 환경에서 쓸 수 없으면 기본 모델로 바꾸지 않고 여기서 실패시킨다.
    const claudeConfig = await resolveAgentConfig("claude", getTaskAgentConfig(task, "claude"));
    agentRun = beginAgentRun(task, { agent: "claude", kind: "implementation", config: claudeConfig });
    publishRun(task, agentRun, broadcast);

    const q = query({
      prompt: task.abapMode ? `${abapPreamble()}\n\n${task.instruction}` : task.instruction,
      options: {
        ...agentQueryOptions(task),
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
    task.finishedAt = new Date().toISOString();
    if (activeTaskId === task.id) activeTaskId = null;

    if (diffResult.changedFiles.length === 0) {
      emit(task, { type: "log", role: "도구", text: "변경 사항이 없어 자동 승인 처리합니다." }, broadcast);
      await finalizeApproved(task, broadcast, { autoApproved: true });
    } else {
      task.status = "completed";
      pendingReviewTaskId = task.id;
      emit(task, { type: "status", status: "completed" }, broadcast);
    }
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
  if (applyClaudeRuntimeMetadata(agentRun, message)) {
    publishRun(task, agentRun, broadcast);
    if (agentRun.modelMismatch) {
      const { expected, actual } = agentRun.modelMismatch;
      emit(
        task,
        { type: "log", role: "도구", text: `⚠ 요청한 모델(${expected})과 실제 실행 모델(${actual})이 다릅니다.` },
        broadcast
      );
    }
  }

  if (message.type === "assistant") {
    if (message.message?.model && agentRun && !agentRun.actualModels.includes(message.message.model)) {
      agentRun.actualModels.push(message.message.model);
      agentRun.modelSource = "reported";
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
      // Windows에서 중단 직후에는 Claude 프로세스가 아직 폴더를 잡고 있어, git이 worktree 등록은
      // 지우고 폴더 삭제만 실패(Permission denied)할 수 있다. 그 뒤 재시도하면 "is not a working tree".
      // 폴더는 콘솔 전용 .runtime/worktrees 아래이므로 직접 지우고(잠금이 풀릴 때까지 재시도) 등록을 정리한다.
      try {
        fs.rmSync(task.worktreeDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 500 });
        await pruneWorktrees({ projectPath: task.projectPath });
      } catch (fallbackErr) {
        errors.push(`${String(err?.message ?? err)}\n${String(fallbackErr?.message ?? fallbackErr)}`);
      }
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

// 승인 시(수동이든, 변경사항 없어서 자동이든) 공통으로 하는 일: ff-merge + 임시 작업 정리 + 상태 전환.
async function finalizeApproved(task, broadcast, extraEvent = {}) {
  await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
  const mergedSha = await fastForwardMerge({
    projectPath: task.projectPath,
    targetSha: task.targetSha,
    expectedBaseBranch: task.baseBranch,
    expectedBaseSha: task.mergeBaseSha,
  });

  await cleanupArtifacts(task);

  task.status = "approved";
  task.approvedAt = new Date().toISOString();
  task.mergedSha = mergedSha;
  pendingReviewTaskId = null;
  emit(
    task,
    {
      type: "status",
      status: "approved",
      artifactsCleaned: task.artifactsCleaned,
      cleanupError: task.cleanupError,
      ...extraEvent,
    },
    broadcast
  );
  return mergedSha;
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

  // ABAP 반영은 수십 초 걸린다. 그 사이 다시 승인이 들어오면 같은 오브젝트를 두 번 생성하려다
  // 꼬이므로(2026-11-07 실제 발생) 진행 중인 승인이 있으면 거부한다.
  if (abapCheckingTaskIds.has(task.id)) {
    throw new Error("서버 검사가 진행 중입니다. 검사가 끝난 뒤 승인해주세요.");
  }
  if (approvingTaskIds.has(task.id)) {
    throw new Error("이 작업의 승인(서버 반영)이 이미 진행 중입니다. 완료될 때까지 기다려주세요.");
  }
  approvingTaskIds.add(task.id);
  try {
    assertExpectedSnapshot(task, expectedSnapshot);
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
    // 서버 반영 전에 git 병합 가능 여부부터 확인한다 — 반영 후에 병합이 막히면 되돌릴 수 없다.
    await assertFastForwardable({
      projectPath: task.projectPath,
      expectedBaseBranch: task.baseBranch,
      expectedBaseSha: task.mergeBaseSha,
    });

    let applyResult = null;
    if (task.abapMode) {
      applyResult = await applyAbapChanges({
        worktreeDir: task.worktreeDir,
        changedFiles: task.diff.changedFiles,
        packageName: ABAP_SYNC_PACKAGE,
      });
      task.applyResult = applyResult;
      if (applyResult.failed.length > 0) {
        // 실패하기 전까지 새로 만든 오브젝트는 검사(리허설)로 만든 것과 같이 취급해, 이 작업을 반려하면 지운다.
        const createdKeys = applyResult.applied
          .filter((a) => a.action === "create")
          .map((a) => rehearsalKey(classifyAbapFile(a.path)?.kind, a.name));
        task.abapRehearsalObjects = [...new Set([...(task.abapRehearsalObjects ?? []), ...createdKeys])];
        const summary = applyResult.failed.map((f) => `${f.name ?? f.path}: ${f.reason}`).join("; ");
        emit(
          task,
          { type: "status", status: "completed", applyFailed: true, applyResult },
          broadcast
        );
        throw new Error(`ABAP 반영 실패 (${applyResult.failed.length}건) — 머지하지 않았습니다: ${summary}`);
      }
    }

    // 검사 단계에서 미리 만든 오브젝트는 이제 승인된 정식 오브젝트다 — 반려 시 삭제 대상에서 뺀다.
    task.abapRehearsalObjects = [];
    await finalizeApproved(task, broadcast, { applyResult });
    return task;
  } finally {
    approvingTaskIds.delete(task.id);
  }
}

async function rollbackAbapRehearsal(task, broadcast) {
  const objects = task.abapRehearsalObjects ?? [];
  if (objects.length === 0) return;
  try {
    const { deleted, failed } = await deleteRehearsalObjects({ objects });
    task.abapRehearsalObjects = failed.map((f) => f.key);
    const text = failed.length
      ? `검사용으로 만든 오브젝트 ${deleted.length}개 삭제, ${failed.length}개 삭제 실패(Eclipse에서 직접 삭제 필요): ${failed.map((f) => f.key).join(", ")}`
      : `검사용으로 만든 오브젝트 ${deleted.length}개를 서버에서 삭제했습니다.`;
    emit(task, { type: "log", role: "도구", text }, broadcast);
  } catch (err) {
    emit(
      task,
      { type: "log", role: "도구", text: `검사용 오브젝트 삭제 실패(Eclipse에서 직접 삭제 필요): ${String(err?.message ?? err)}` },
      broadcast
    );
  }
}

export function checkAbapTask(id, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId || task.status !== "completed") {
    throw new Error("서버 검사 대상 작업이 아닙니다.");
  }
  if (!task.abapMode) throw new Error("ABAP 모드 작업에서만 서버 검사를 할 수 있습니다.");
  if (activeTaskId || task.review?.status === "running") {
    throw new Error("다른 작업 또는 리뷰가 진행 중입니다.");
  }
  if (abapCheckingTaskIds.has(task.id) || approvingTaskIds.has(task.id)) {
    throw new Error("서버 검사 또는 승인이 이미 진행 중입니다.");
  }

  abapCheckingTaskIds.add(task.id);
  task.abapCheck = { status: "running", targetSha: task.targetSha, startedAt: new Date().toISOString() };
  emit(task, { type: "abap_check", status: "running" }, broadcast);

  (async () => {
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
    return rehearseAbapChanges({
      worktreeDir: task.worktreeDir,
      changedFiles: task.diff.changedFiles,
      packageName: ABAP_SYNC_PACKAGE,
      rehearsalObjects: task.abapRehearsalObjects ?? [],
    });
  })()
    .then((result) => {
      task.abapRehearsalObjects = result.created;
      task.abapCheck = {
        status: "done",
        targetSha: task.targetSha,
        startedAt: task.abapCheck.startedAt,
        completedAt: new Date().toISOString(),
        ok: result.ok,
        counts: result.counts,
        results: result.results,
      };
      emit(task, { type: "abap_check", status: "done", ok: result.ok, counts: result.counts }, broadcast);
    })
    .catch((err) => {
      task.abapCheck = {
        status: "failed",
        targetSha: task.targetSha,
        startedAt: task.abapCheck.startedAt,
        completedAt: new Date().toISOString(),
        error: String(err?.message ?? err),
      };
      emit(task, { type: "abap_check", status: "failed", error: task.abapCheck.error }, broadcast);
    })
    .finally(() => {
      abapCheckingTaskIds.delete(task.id);
    });
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
  if (abapCheckingTaskIds.has(task.id)) {
    throw new Error("서버 검사가 진행 중입니다. 검사가 끝난 뒤 반려해주세요.");
  }
  await rollbackAbapRehearsal(task, broadcast);
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

function abapPreamble() {
  return [
    `이 작업은 ABAP 모드다. \`${ABAP_SYNC_PACKAGE}\` 패키지의 오브젝트 소스를 ` +
      "\`abap/<타입>/<이름>.abap\` 형태의 일반 파일로 미리 받아뒀다.",
    "이 폴더 안의 파일만 수정하거나, 같은 규칙으로 새 파일을 추가해 새 오브젝트를 만들어라" +
      " (예: 새 클래스는 abap/clas/<소문자이름>.clas.abap, 새 인터페이스는 abap/intf/<소문자이름>.intf.abap).",
    "파일 이름은 정확히 abap/<타입디렉토리>/<오브젝트이름>.<확장자> 형식만 써라:" +
      " 테이블 abap/tabl/*.tabl.abap, CDS 뷰 abap/ddls/*.ddls.abap," +
      " Behavior Definition abap/bdef/*.bdef.abap, 인터페이스 abap/intf/*.intf.abap," +
      " 클래스 abap/clas/*.clas.abap, 클래스 로컬 타입(CCIMP — RAP 핸들러 lhc_*·세이버 lsc_*) abap/clas/*.clas.locals_imp.abap," +
      " Metadata Extension abap/ddlx/*.ddlx.abap, Service Definition abap/srvd/*.srvd.abap." +
      " Behavior Pool(ZBP_*)은 메인 파일에 'CLASS zbp_x DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF <루트 엔터티>.'를," +
      " 핸들러 구현은 같은 이름의 .clas.locals_imp.abap 파일에 써라." +
      " Service Binding(SRVB)은 파일로 만들 수 없다 — 필요하면 작업 결과에 '수동 생성 필요'로 적어라." +
      " abapGit 스타일의 *.clas.testclasses.abap, *.clas.locals_def.abap, macros 파일 등" +
      " 이 목록에 없는 보조 파일은 절대 만들지 마라 — 적용 단계에서 실패한다.",
    "승인 시 테이블 → CDS → BDEF → 클래스 → Metadata Extension → Service Definition 순으로 저장한 뒤" +
      " 한 번에 활성화하므로, 서로 참조하는 오브젝트를 한 작업에서 함께 만들어도 된다.",
    "이 작업에서는 SAP 서버에 직접 접근하는 도구(MCP)를 쓸 수 없다. 서버 문법 검사·활성화는 사용자가 승인할 때" +
      " 수행되므로, 서버에서만 확인 가능한 부분은 최종 결과에 '승인 후 확인 필요'로 적어라.",
    "작업 지시에 유닛 테스트가 명시되지 않았으면 테스트 클래스를 만들지 마라 (리뷰 반영 수정 중에도 마찬가지)." +
      " 서버 문법 검사는 승인할 때에야 돌기 때문에, 요청하지 않은 코드는 승인 실패 원인만 늘린다." +
      " 테스트가 명시된 경우에만 별도 파일 없이 클래스 소스 안에 로컬 테스트 클래스(CLASS ltcl_... DEFINITION FOR TESTING)로 작성하라.",
    "ABAP 식별자(메서드·변수·클래스 이름)는 30자를 넘지 않게 하고, 존재하지 않는 타입(예: NUMC9)을 만들어 쓰지 말고" +
      " 내장 타입(TYPE n LENGTH 9 등)이나 테이블 필드 타입을 써라.",
    "이 폴더 밖의 파일은 건드리지 말고, abap/ 안의 기존 파일을 rename하지 마라" +
      " (rename은 지원하지 않아 적용 단계에서 실패한다).",
  ].join(" ");
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
    "리뷰 지적을 실제 코드와 대조한 뒤 타당한 문제를 수정해줘. 기존 테스트가 깨지면 함께 고치되," +
      " 원래 작업 요청에 테스트가 없었다면 새 테스트 클래스를 추가하지 마.",
    "현재 작업 범위를 벗어난 변경은 만들지 마.",
  ];
  if (extraInstruction) lines.push(`사용자 추가 지시: ${extraInstruction}`);
  return lines.join("\n\n");
}

// 승인 전 서버 검사나 승인(서버 반영)에서 나온 오류를 Claude가 고치도록 하는 수정 프롬프트.
// Codex 리뷰 없이도 요청할 수 있다.
export function collectAbapErrors(task) {
  const fromCheck = (task.abapCheck?.status === "done" ? task.abapCheck.results ?? [] : [])
    .filter((r) => r.status === "error")
    .map((r) => ({ file: r.path, object: r.name, source: "서버 검사", message: r.message }));
  const fromApply = (task.applyResult?.failed ?? []).map((f) => ({
    file: f.path,
    object: f.name,
    source: "승인(서버 반영)",
    message: f.reason,
  }));
  return [...fromCheck, ...fromApply];
}

function buildAbapFixPrompt(task, errors, extraInstruction) {
  const lines = [
    "SAP 서버 검사에서 아래 오류가 나왔다. 오류가 난 부분만 고쳐줘.",
    `원래 작업 요청: ${task.instruction}`,
    `서버 오류: ${JSON.stringify(errors, null, 2)}`,
    "오류 메시지를 실제 코드와 대조해 원인을 고치고, 관련 없는 코드는 바꾸지 마." +
      " 새 기능·새 테스트 클래스를 추가하지 마. 고친 내용을 결과 요약에 오류별로 적어라.",
  ];
  if (extraInstruction) lines.push(`사용자 추가 지시: ${extraInstruction}`);
  return lines.join("\n\n");
}

export async function requestRevision({ id, extraInstruction, reviewsRoot, fromAbapErrors = false }, broadcast) {
  const task = tasks.get(id);
  if (!task || task.id !== pendingReviewTaskId || task.status !== "completed") {
    throw new Error("수정 요청 대상 작업이 아닙니다.");
  }
  if (activeTaskId || task.review?.status === "running") {
    throw new Error("다른 작업 또는 리뷰가 진행 중입니다.");
  }
  if (abapCheckingTaskIds.has(task.id) || approvingTaskIds.has(task.id)) {
    throw new Error("서버 검사 또는 승인이 진행 중입니다. 끝난 뒤 다시 시도해주세요.");
  }
  let abapErrors = null;
  if (fromAbapErrors) {
    abapErrors = collectAbapErrors(task);
    if (abapErrors.length === 0) throw new Error("수정할 서버 오류가 없습니다.");
  } else if (task.review?.status !== "done") {
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

  runRevision(task, { previous, extraInstruction, abapErrors, reviewsRoot, broadcast }).catch(() => {});
  return task;
}

async function runRevision(task, { previous, extraInstruction, abapErrors = null, reviewsRoot, broadcast }) {
  const timeoutMs = taskTimeoutMs();
  let agentRun = null;
  try {
    const startText = abapErrors
      ? `서버 오류 ${abapErrors.length}건을 바탕으로 수정 작업을 시작합니다.`
      : "Codex 리뷰를 바탕으로 수정 작업을 시작합니다.";
    emit(task, { type: "log", role: "Claude", text: startText }, broadcast);
    task.timeoutMs = timeoutMs;
    task.timeoutHandle = setTimeout(() => {
      task.timedOut = true;
      task.abortController?.abort();
      task.queryHandle?.close?.();
    }, timeoutMs);

    // 지정한 모델을 이 환경에서 쓸 수 없으면 기본 모델로 바꾸지 않고 여기서 실패시킨다.
    const claudeConfig = await resolveAgentConfig("claude", getTaskAgentConfig(task, "claude"));
    agentRun = beginAgentRun(task, {
      agent: "claude",
      kind: `revision-${(task.revisionCount ?? 0) + 1}`,
      config: claudeConfig,
    });
    publishRun(task, agentRun, broadcast);

    const revisionPrompt = abapErrors
      ? buildAbapFixPrompt(task, abapErrors, extraInstruction)
      : buildRevisionPrompt(task, extraInstruction);
    const q = query({
      prompt: task.abapMode ? `${abapPreamble()}\n\n${revisionPrompt}` : revisionPrompt,
      options: {
        ...agentQueryOptions(task),
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
    if (previous.review) task.reviewHistory.push({
      ...previous.review,
      reviewedTargetSha: previous.targetSha,
      supersededAt: new Date().toISOString(),
    });
    task.targetSha = targetSha;
    task.diff = diffResult;
    task.review = null;
    // 코드가 바뀌었으니 이전 검사·반영 결과는 더 이상 유효하지 않다 (리허설 오브젝트 목록은 유지).
    task.abapCheck = null;
    task.applyResult = null;
    task.revisionCount = revisionNumber;
    task.finishedAt = new Date().toISOString();
    task.error = null;
    if (activeTaskId === task.id) activeTaskId = null;

    if (diffResult.changedFiles.length === 0) {
      emit(task, { type: "log", role: "도구", text: "변경 사항이 없어 자동 승인 처리합니다." }, broadcast);
      await finalizeApproved(task, broadcast, { autoApproved: true, revised: true });
    } else {
      task.status = "completed";
      emit(task, { type: "status", status: "completed", revised: true }, broadcast);
    }
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

  let resolvedCodex = codexConfig;
  (async () => {
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
    // 지정한 모델을 이 환경에서 쓸 수 없으면 리뷰를 시작하지 않는다 (조용히 다른 모델로 바꾸지 않음).
    resolvedCodex = await resolveAgentConfig("codex", codexConfig);
    agentRun.expectedModel = resolvedCodex.expectedModel ?? null;

    const result = await requestReview({
      worktreeDir: task.worktreeDir,
      reviewsRoot,
      taskId: task.id,
      instruction: task.instruction,
      extraInstruction,
      baseSha: task.baseSha,
      targetSha: task.targetSha,
      model: resolvedCodex.model,
      effort: resolvedCodex.effort,
    });
    await assertFrozenTarget({ worktreeDir: task.worktreeDir, targetSha: task.targetSha });
    return result;
  })()
    .then((result) => {
      agentRun.status = "done";
      agentRun.usage = result.usage ?? null;
      agentRun.threadId = result.threadId ?? null;
      // Codex CLI 출력에는 실행 모델이 없어서, 세션 기록의 turn_context에서 실제 값을 읽는다.
      // 읽지 못하면 예전처럼 설정값을 "적용 모델"로 표시한다.
      const reported = readCodexSessionModel(agentRun.threadId);
      if (reported) {
        agentRun.actualModels = [reported.model];
        agentRun.mainModel = reported.model;
        agentRun.modelSource = "reported";
        agentRun.actualEffort = reported.effort;
        agentRun.effortSource = reported.effort ? "reported" : null;
        agentRun.modelMismatch =
          agentRun.expectedModel && !sameModel(agentRun.expectedModel, reported.model)
            ? { expected: agentRun.expectedModel, actual: reported.model }
            : null;
      } else {
        agentRun.actualModels = resolvedCodex.model === "default" ? [] : [resolvedCodex.model];
        agentRun.actualEffort = resolvedCodex.effort ?? null;
        agentRun.modelSource = resolvedCodex.model === "default" ? null : "configured";
        agentRun.effortSource = resolvedCodex.effort ? "configured" : null;
      }
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
