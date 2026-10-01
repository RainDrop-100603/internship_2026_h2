import fs from "node:fs";
import path from "node:path";

const MODEL_OPTIONS = {
  claude: [
    { value: "default", label: "Claude 기본 모델" },
    { value: "fable", label: "Claude Fable" },
    { value: "sonnet", label: "Claude Sonnet" },
    { value: "opus", label: "Claude Opus" },
  ],
  codex: [
    { value: "default", label: "Codex 기본 모델" },
    { value: "gpt-6-astra", label: "GPT-6 Astra" },
    { value: "gpt-5.5", label: "GPT-5.5" },
  ],
};

const EFFORT_OPTIONS = {
  claude: ["low", "medium", "high", "xhigh", "max"],
  codex: ["low", "medium", "high", "xhigh"],
};

const DEFAULT_SETTINGS = {
  claude: { model: "default", effort: "medium" },
  codex: { model: "gpt-6-astra", effort: "medium" },
};

let settingsFile = null;
let settings = structuredClone(DEFAULT_SETTINGS);

function validateAgentSettings(agent, value) {
  if (!value || typeof value !== "object") {
    throw new Error(`${agent} 설정이 필요합니다.`);
  }
  const models = new Set(MODEL_OPTIONS[agent].map((option) => option.value));
  if (!models.has(value.model)) {
    throw new Error(`지원하지 않는 ${agent} 모델입니다: ${value.model}`);
  }
  if (!EFFORT_OPTIONS[agent].includes(value.effort)) {
    throw new Error(`지원하지 않는 ${agent} effort입니다: ${value.effort}`);
  }
  return { model: value.model, effort: value.effort };
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

  const stored = JSON.parse(fs.readFileSync(settingsFile, "utf8"));
  settings = {
    claude: validateAgentSettings("claude", stored.claude ?? DEFAULT_SETTINGS.claude),
    codex: validateAgentSettings("codex", stored.codex ?? DEFAULT_SETTINGS.codex),
  };
}

export function getSettings() {
  return structuredClone(settings);
}

export function getSettingsPayload() {
  return {
    settings: getSettings(),
    options: structuredClone({ models: MODEL_OPTIONS, efforts: EFFORT_OPTIONS }),
  };
}

export function updateSettings(nextSettings) {
  settings = {
    claude: validateAgentSettings("claude", nextSettings?.claude),
    codex: validateAgentSettings("codex", nextSettings?.codex),
  };
  persist();
  return getSettings();
}
