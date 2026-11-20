import fs from "node:fs";
import path from "node:path";
import { findModel, getModelCatalog } from "./modelCatalog.mjs";

// 선택 가능한 모델·effort는 modelCatalog가 사용자 환경에서 조회한다. 여기서는 저장 형식만 검사하고,
// 실제로 쓸 수 있는 값인지는 저장할 때(updateSettings)와 작업을 시작할 때(resolveAgentConfig) 확인한다.
const KNOWN_EFFORTS = ["low", "medium", "high", "xhigh", "max", "ultra"];

const DEFAULT_SETTINGS = {
  claude: { model: "default", effort: "medium" },
  codex: { model: "default", effort: "medium" },
};

let settingsFile = null;
let settings = structuredClone(DEFAULT_SETTINGS);

function validateFormat(agent, value) {
  if (!value || typeof value !== "object") {
    throw new Error(`${agent} 설정이 필요합니다.`);
  }
  if (typeof value.model !== "string" || !value.model.trim()) {
    throw new Error(`${agent} 모델을 선택해주세요.`);
  }
  const effort = value.effort ?? null;
  if (effort !== null && !KNOWN_EFFORTS.includes(effort)) {
    throw new Error(`지원하지 않는 ${agent} effort입니다: ${effort}`);
  }
  return { model: value.model.trim(), effort };
}

export function validateAgainstCatalog(agent, value, catalog) {
  const entry = catalog?.[agent];
  // 환경 조회에 실패해 기본 목록으로 동작 중이면 사용자의 선택을 막지 않는다.
  if (!entry || entry.source !== "environment") return value;
  const model = findModel(catalog, agent, value.model);
  if (!model) {
    const available = entry.models.map((m) => m.value).join(", ");
    throw new Error(`현재 환경에서 사용할 수 없는 ${agent} 모델입니다: ${value.model} (사용 가능: ${available})`);
  }
  if (model.efforts.length === 0) return { ...value, effort: null };
  if (value.effort && !model.efforts.includes(value.effort)) {
    throw new Error(`${model.label}은(는) effort ${value.effort}를 지원하지 않습니다 (지원: ${model.efforts.join(", ")})`);
  }
  return value;
}

function persist() {
  fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
  const temporary = `${settingsFile}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(settings, null, 2));
  fs.renameSync(temporary, settingsFile);
}

export function initSettings(runtimeRoot) {
  settingsFile = path.join(runtimeRoot, "settings.json");
  settings = structuredClone(DEFAULT_SETTINGS);
  if (!fs.existsSync(settingsFile)) {
    persist();
    return;
  }

  // 예전 버전이 저장한 값(예: 카탈로그에서 사라진 모델)이어도 서버 시작은 막지 않는다.
  // 사용할 수 없는 모델이면 작업 시작 시 이유와 함께 거부된다.
  const stored = JSON.parse(fs.readFileSync(settingsFile, "utf8"));
  for (const agent of ["claude", "codex"]) {
    try {
      settings[agent] = validateFormat(agent, stored[agent] ?? DEFAULT_SETTINGS[agent]);
    } catch {
      settings[agent] = structuredClone(DEFAULT_SETTINGS[agent]);
    }
  }
}

export function getSettings() {
  return structuredClone(settings);
}

export async function getSettingsPayload({ refresh = false } = {}) {
  const catalog = await getModelCatalog({ refresh });
  return {
    settings: getSettings(),
    options: {
      models: { claude: catalog.claude.models, codex: catalog.codex.models },
      sources: {
        claude: { source: catalog.claude.source, error: catalog.claude.error },
        codex: { source: catalog.codex.source, error: catalog.codex.error },
      },
      loadedAt: catalog.loadedAt,
    },
  };
}

export async function updateSettings(nextSettings, { catalog: providedCatalog } = {}) {
  const catalog = providedCatalog ?? (await getModelCatalog());
  const next = {
    claude: validateAgainstCatalog("claude", validateFormat("claude", nextSettings?.claude), catalog),
    codex: validateAgainstCatalog("codex", validateFormat("codex", nextSettings?.codex), catalog),
  };
  settings = next;
  persist();
  return getSettings();
}

// 작업을 시작하기 직전, 작업에 고정된 설정이 지금 환경에서 실제로 쓸 수 있는지 확인한다.
// 지정한 모델을 쓸 수 없으면 조용히 기본 모델로 바꾸지 않고 작업을 거부한다 (사용자가 지정한 모델로만 실행).
export async function resolveAgentConfig(agent, config, { catalog: providedCatalog } = {}) {
  const catalog = providedCatalog ?? (await getModelCatalog());
  const value = validateFormat(agent, config ?? DEFAULT_SETTINGS[agent]);
  const checked = validateAgainstCatalog(agent, value, catalog);
  const model = findModel(catalog, agent, checked.model);
  return {
    ...checked,
    label: model?.label ?? checked.model,
    expectedModel: model?.resolvedModel ?? (checked.model === "default" ? null : checked.model),
    catalogSource: catalog[agent].source,
  };
}
