import crossSpawn from "cross-spawn";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const schemaPath = path.join(__dirname, "review-schema.json");

function buildPrompt({ instruction, extraInstruction, baseSha, targetSha }) {
  const lines = [
    "역할: 코드 리뷰어. 아래는 Claude가 작성한 변경사항이다.",
    `작업 요청: "${instruction}"`,
    `리뷰 대상은 고정된 커밋 범위 '${baseSha}..${targetSha}'이다. HEAD나 워킹트리 상태를 리뷰 범위로 사용하지 않는다.`,
  ];
  if (extraInstruction) {
    lines.push(`추가 리뷰 지시: "${extraInstruction}"`);
  }
  lines.push(
    "",
    "요구:",
    "- 워킹트리를 수정하지 말고 리뷰만 수행한다.",
    "- 버그/정확성, 예외·에러 처리 누락, 테스트 부족, 명명/가독성 위주로 본다.",
    "- 중요도 높은 문제를 우선 보고한다.",
    "- 지정된 JSON 스키마 형식으로만 응답한다.",
    "- findings[].file은 반드시 저장소 루트 기준 상대 경로로 쓴다 (예: 'src/foo.js'). 절대 경로를 쓰지 않는다."
  );
  return lines.join("\n");
}

// Codex가 지시를 무시하고 절대 경로를 반환하는 경우를 대비해 worktree 기준
// 상대 경로로 한 번 더 정규화한다.
function toRelativePath(filePath, worktreeDir) {
  if (!filePath) return filePath;
  const absoluteWorktree = path.resolve(worktreeDir);
  const absoluteFile = path.resolve(worktreeDir, filePath);
  if (absoluteFile.toLowerCase().startsWith(absoluteWorktree.toLowerCase())) {
    const rel = path.relative(absoluteWorktree, absoluteFile);
    return rel.split(path.sep).join("/");
  }
  return filePath;
}

function parseJsonLoose(raw) {
  const trimmed = raw.trim();
  const fenced = trimmed.match(/^```(?:json)?\n([\s\S]*?)\n```$/);
  return JSON.parse(fenced ? fenced[1] : trimmed);
}

// Node의 child_process는 Windows에서 npm이 만드는 codex.cmd 셸 스크립트를
// shell:true 없이는 찾지 못하고(ENOENT), 반대로 shell:true를 직접 쓰면
// 인자 이스케이프가 불완전해 명령 주입 위험이 있다(CVE-2024-27980).
// cross-spawn이 두 문제를 모두 안전하게 처리한다.
//
// --json의 stdout을 계속 소비하면서 turn.completed 사용량을 수집한다. 파이프로
// 열어둔 stdout을 소비하지 않으면 OS 버퍼가 가득 차 Codex가 멈출 수 있다.
// 스키마가 적용된 최종 리뷰 본문은 기존처럼 -o 결과 파일에서 읽는다.
function applyCodexEvent(state, event) {
  if (event?.type === "thread.started" && typeof event.thread_id === "string") {
    state.threadId = event.thread_id;
  }
  if (event?.type === "turn.completed" && event.usage) {
    state.usage = {
      inputTokens: Number(event.usage.input_tokens) || 0,
      cachedInputTokens: Number(event.usage.cached_input_tokens) || 0,
      cacheCreationInputTokens: 0,
      outputTokens: Number(event.usage.output_tokens) || 0,
      reasoningTokens: Number(event.usage.reasoning_output_tokens) || 0,
    };
  }
}

function runCodex(args, { cwd, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const child = crossSpawn("codex", args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    let stdoutBuffer = "";
    let settled = false;
    const state = { threadId: null, usage: null };

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill();
      reject(new Error("codex review 시간 초과"));
    }, timeoutMs);

    child.stderr?.on("data", (chunk) => {
      stderr += chunk;
    });
    child.stdout?.on("data", (chunk) => {
      stdoutBuffer += chunk.toString();
      const lines = stdoutBuffer.split(/\r?\n/);
      stdoutBuffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          applyCodexEvent(state, JSON.parse(line));
        } catch {
          // Codex의 비 JSON 진단 출력은 stderr와 종료 코드로 처리한다.
        }
      }
    });
    child.on("error", (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (code !== 0) {
        reject(new Error(`codex가 코드 ${code}로 종료됨: ${stderr.slice(-2000)}`));
      } else {
        if (stdoutBuffer.trim()) {
          try {
            applyCodexEvent(state, JSON.parse(stdoutBuffer));
          } catch {
            // 마지막 줄이 JSON이 아니어도 결과 파일이 유효하면 리뷰는 성공이다.
          }
        }
        resolve(state);
      }
    });
  });
}

// worktree의 변경사항을 리뷰 요청한다. `codex exec review` 서브커맨드는
// --output-schema를 무시하고 항상 자체 자연어 포맷으로만 응답하므로(관찰됨),
// 대신 일반 `codex exec`에 리뷰 프롬프트를 직접 주고 --output-schema로
// 우리 JSON 스키마를 강제한다. 스코프 플래그(--uncommitted 등)는 커스텀
// PROMPT와 함께 쓸 수 없어(CLI가 거부), base 커밋 sha를 프롬프트에 명시해
// Codex가 직접 `<baseSha>..<targetSha>`로 diff를 확인하게 한다. 두 끝점을
// 커밋 SHA로 고정해 브랜치나 worktree가 움직여도 리뷰 범위가 바뀌지 않는다.
//
// -s read-only로 샌드박스를 강제한다: 사용자의 codex 기본 설정이
// workspace-write이면, diff에 없던 수정(프롬프트 인젝션 등으로 유도된 것
// 포함)이 워크트리에 남을 수 있고, 리뷰 전에 이미 커밋해두므로 승인 시
// commitAll이 그 숨은 변경까지 그대로 병합해버릴 위험이 있다.
export function requestReview({
  worktreeDir,
  reviewsRoot,
  taskId,
  instruction,
  extraInstruction,
  baseSha,
  targetSha,
  model,
  effort,
}) {
  const resultPath = path.join(reviewsRoot, taskId, `review-${Date.now()}.json`);
  fs.mkdirSync(path.dirname(resultPath), { recursive: true });
  const prompt = buildPrompt({ instruction, extraInstruction, baseSha, targetSha });

  const modelArgs = model && model !== "default" ? ["--model", model] : [];
  const effortArgs = effort ? ["--config", `model_reasoning_effort="${effort}"`] : [];

  return runCodex(
    [
      "exec",
      "-s",
      "read-only",
      "--json",
      ...modelArgs,
      ...effortArgs,
      "--skip-git-repo-check",
      "--output-schema",
      schemaPath,
      "-o",
      resultPath,
      prompt,
    ],
    { cwd: worktreeDir, timeoutMs: 15 * 60 * 1000 }
  ).then(({ usage, threadId }) => {
    const raw = fs.readFileSync(resultPath, "utf8");
    const result = parseJsonLoose(raw);
    return {
      ...result,
      findings: (result.findings ?? []).map((f) => ({ ...f, file: toRelativePath(f.file, worktreeDir) })),
      usage,
      threadId,
    };
  });
}

export function parseCodexUsageEvent(event) {
  const state = { threadId: null, usage: null };
  applyCodexEvent(state, event);
  return state;
}
