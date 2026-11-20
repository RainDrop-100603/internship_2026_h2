import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crossSpawn from "cross-spawn";
import { query } from "@anthropic-ai/claude-agent-sdk";

// 사용자 환경(로그인 계정·플랜·CLI 버전)에서 실제로 쓸 수 있는 모델 목록.
// 하드코딩된 목록은 계정마다 달라 틀리기 쉽다 (예: 카탈로그에 없는 gpt-5.5, 실제 값과 다른 "fable").
//  - Claude: Agent SDK의 supportedModels() — 메시지를 보내지 않는 control 요청이라 토큰을 쓰지 않는다.
//  - Codex:  `codex debug models` — 로그인 계정 기준 모델 카탈로그(JSON).
// 조회에 실패하면 아래 기본 목록으로 동작하되 source: "fallback"으로 표시한다.

const CACHE_TTL_MS = 10 * 60 * 1000;
const LOOKUP_TIMEOUT_MS = 60 * 1000;

const FALLBACK = {
  claude: [
    { value: "default", label: "Claude 기본 모델", description: "", efforts: ["low", "medium", "high", "xhigh", "max"] },
    { value: "sonnet", label: "Claude Sonnet", description: "", efforts: ["low", "medium", "high", "xhigh", "max"] },
    { value: "opus", label: "Claude Opus", description: "", efforts: ["low", "medium", "high", "xhigh", "max"] },
  ],
  codex: [
    { value: "default", label: "Codex 기본 모델 (config.toml)", description: "", efforts: ["low", "medium", "high", "xhigh"] },
  ],
};

let cache = null; // { at, catalog }
let inflight = null;

function withTimeout(promise, ms, label) {
  let timer;
  return Promise.race([
    promise.finally(() => clearTimeout(timer)),
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error(`${label} 조회 시간 초과`)), ms);
    }),
  ]);
}

export function normalizeClaudeModels(models) {
  return models.map((model) => ({
    value: model.value,
    label: model.displayName || model.value,
    description: model.description ?? "",
    resolvedModel: model.resolvedModel ?? null,
    efforts: model.supportsEffort ? model.supportedEffortLevels ?? [] : [],
  }));
}

async function loadClaudeModels() {
  // 프롬프트를 보내지 않는 세션을 열어 모델 목록만 묻고 닫는다.
  let release;
  const idle = new Promise((resolve) => {
    release = resolve;
  });
  async function* noPrompt() {
    await idle;
  }
  const q = query({
    prompt: noPrompt(),
    options: { cwd: os.tmpdir(), settingSources: ["user"], strictMcpConfig: true },
  });
  try {
    const models = await withTimeout(q.supportedModels(), LOOKUP_TIMEOUT_MS, "Claude 모델");
    return normalizeClaudeModels(models);
  } finally {
    release();
    q.close?.();
  }
}

function readCodexDefaultModel() {
  try {
    const config = fs.readFileSync(path.join(os.homedir(), ".codex", "config.toml"), "utf8");
    return config.match(/^\s*model\s*=\s*"([^"]+)"/m)?.[1] ?? null;
  } catch {
    return null;
  }
}

export function normalizeCodexModels(catalog, defaultModel) {
  const listed = (catalog?.models ?? [])
    .filter((model) => model.visibility === "list")
    .map((model) => ({
      value: model.slug,
      label: model.display_name || model.slug,
      description: model.description ?? "",
      efforts: (model.supported_reasoning_levels ?? []).map((level) => level.effort ?? level),
      defaultEffort: model.default_reasoning_level ?? null,
    }));
  const fallbackTarget = listed.find((model) => model.value === defaultModel);
  return [
    {
      value: "default",
      label: defaultModel ? `Codex 기본 (config.toml: ${defaultModel})` : "Codex 기본 (config.toml)",
      description: "",
      efforts: fallbackTarget?.efforts ?? FALLBACK.codex[0].efforts,
      defaultEffort: fallbackTarget?.defaultEffort ?? null,
      resolvedModel: defaultModel,
    },
    ...listed,
  ];
}

function loadCodexModels() {
  return new Promise((resolve, reject) => {
    const child = crossSpawn("codex", ["debug", "models"], { cwd: os.tmpdir(), stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error("Codex 모델 조회 시간 초과"));
    }, LOOKUP_TIMEOUT_MS);
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) return reject(new Error(`codex debug models 실패 (${code}): ${stderr.trim().slice(0, 200)}`));
      try {
        resolve(normalizeCodexModels(JSON.parse(stdout), readCodexDefaultModel()));
      } catch (err) {
        reject(new Error(`Codex 모델 목록을 해석하지 못했습니다: ${err.message}`));
      }
    });
  });
}

async function loadAgent(agent, loader) {
  try {
    const models = await loader();
    if (models.length === 0) throw new Error("모델 목록이 비어 있습니다.");
    return { models, source: "environment", error: null };
  } catch (err) {
    return { models: structuredClone(FALLBACK[agent]), source: "fallback", error: String(err?.message ?? err) };
  }
}

export async function getModelCatalog({ refresh = false } = {}) {
  if (!refresh && cache && Date.now() - cache.at < CACHE_TTL_MS) return cache.catalog;
  if (!inflight) {
    inflight = Promise.all([loadAgent("claude", loadClaudeModels), loadAgent("codex", loadCodexModels)])
      .then(([claude, codex]) => {
        const catalog = { claude, codex, loadedAt: new Date().toISOString() };
        cache = { at: Date.now(), catalog };
        return catalog;
      })
      .finally(() => {
        inflight = null;
      });
  }
  return inflight;
}

export function findModel(catalog, agent, value) {
  return catalog?.[agent]?.models.find((model) => model.value === value) ?? null;
}

// "claude-fable-5-1[1m]" / "claude-haiku-4-5-20251001" 처럼 접미사가 붙어도 같은 모델로 본다.
export function sameModel(expected, actual) {
  if (!expected || !actual) return true;
  const strip = (id) => String(id).toLowerCase().replace(/\[.*\]$/, "").replace(/-\d{8}$/, "");
  return strip(expected) === strip(actual);
}

// Codex 세션 기록(~/.codex/sessions/YYYY/MM/DD/rollout-*-<threadId>.jsonl)의 turn_context에서
// 실제 실행 모델과 effort를 읽는다. CLI 출력에는 이 정보가 없어서 설정값만 표시하던 것을 대체한다.
export function readCodexSessionModel(threadId, { sessionsRoot = path.join(os.homedir(), ".codex", "sessions") } = {}) {
  if (!threadId) return null;
  const now = new Date();
  for (let daysAgo = 0; daysAgo <= 1; daysAgo += 1) {
    const day = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
    const dir = path.join(
      sessionsRoot,
      String(day.getFullYear()),
      String(day.getMonth() + 1).padStart(2, "0"),
      String(day.getDate()).padStart(2, "0")
    );
    let files = [];
    try {
      files = fs.readdirSync(dir).filter((name) => name.endsWith(`${threadId}.jsonl`));
    } catch {
      continue;
    }
    for (const name of files) {
      const lines = fs.readFileSync(path.join(dir, name), "utf8").split("\n");
      for (const line of lines) {
        if (!line.includes('"turn_context"')) continue;
        try {
          const entry = JSON.parse(line);
          if (entry.type === "turn_context" && entry.payload?.model) {
            return { model: entry.payload.model, effort: entry.payload.effort ?? null };
          }
        } catch {
          // 손상된 줄은 건너뛴다.
        }
      }
    }
  }
  return null;
}
