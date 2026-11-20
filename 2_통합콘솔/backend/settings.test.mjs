import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { getSettings, initSettings, resolveAgentConfig, updateSettings } from "./settings.mjs";
import { normalizeCodexModels, sameModel } from "./modelCatalog.mjs";

const catalog = {
  claude: {
    source: "environment",
    models: [
      { value: "default", label: "Default", resolvedModel: "claude-sonnet-5", efforts: ["low", "medium", "high"] },
      { value: "opus", label: "Opus", resolvedModel: "claude-opus-5", efforts: ["low", "medium", "high", "max"] },
      { value: "haiku", label: "Haiku", resolvedModel: "claude-haiku-4-5-20251001", efforts: [] },
    ],
  },
  codex: {
    source: "environment",
    models: [
      { value: "default", label: "Codex 기본", resolvedModel: "gpt-6-astra", efforts: ["low", "medium"] },
      { value: "gpt-6-astra", label: "GPT-6-Astra", efforts: ["low", "medium", "high", "ultra"] },
    ],
  },
};

test("agent settings use defaults, validate against the environment catalog, and persist", async (t) => {
  const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-settings-test-"));
  t.after(() => fs.rmSync(runtimeRoot, { recursive: true, force: true }));

  initSettings(runtimeRoot);
  assert.deepEqual(getSettings(), {
    claude: { model: "default", effort: "medium" },
    codex: { model: "default", effort: "medium" },
  });

  await updateSettings(
    { claude: { model: "opus", effort: "max" }, codex: { model: "gpt-6-astra", effort: "ultra" } },
    { catalog }
  );
  initSettings(runtimeRoot);
  assert.deepEqual(getSettings(), {
    claude: { model: "opus", effort: "max" },
    codex: { model: "gpt-6-astra", effort: "ultra" },
  });

  await assert.rejects(
    updateSettings({ claude: { model: "fable", effort: "medium" }, codex: getSettings().codex }, { catalog }),
    /사용할 수 없는 claude 모델/
  );
  await assert.rejects(
    updateSettings({ claude: { model: "default", effort: "max" }, codex: getSettings().codex }, { catalog }),
    /effort max를 지원하지 않습니다/
  );
  // effort를 지원하지 않는 모델은 effort를 비워 저장한다.
  const saved = await updateSettings({ claude: { model: "haiku", effort: "high" }, codex: getSettings().codex }, { catalog });
  assert.equal(saved.claude.effort, null);
});

test("an unavailable model is rejected at task start instead of silently falling back", async () => {
  await assert.rejects(resolveAgentConfig("claude", { model: "gpt-5.5", effort: "medium" }, { catalog }), /사용할 수 없는/);
  const resolved = await resolveAgentConfig("claude", { model: "opus", effort: "high" }, { catalog });
  assert.equal(resolved.expectedModel, "claude-opus-5");
  // 환경 조회에 실패한 경우(fallback)에는 막지 않는다.
  const fallback = { ...catalog, claude: { ...catalog.claude, source: "fallback" } };
  const passed = await resolveAgentConfig("claude", { model: "custom-model", effort: "low" }, { catalog: fallback });
  assert.equal(passed.model, "custom-model");
});

test("codex catalog keeps listed models and maps the config.toml default", () => {
  const models = normalizeCodexModels(
    {
      models: [
        { slug: "gpt-6-astra", display_name: "GPT-6-Astra", visibility: "list", supported_reasoning_levels: [{ effort: "low" }, { effort: "ultra" }], default_reasoning_level: "low" },
        { slug: "gpt-reserve", display_name: "Hidden", visibility: "hide", supported_reasoning_levels: [] },
      ],
    },
    "gpt-6-astra"
  );
  assert.deepEqual(models.map((m) => m.value), ["default", "gpt-6-astra"]);
  assert.deepEqual(models[0].efforts, ["low", "ultra"]);
  assert.equal(models[0].resolvedModel, "gpt-6-astra");
});

test("sameModel ignores context and date suffixes", () => {
  assert.equal(sameModel("claude-fable-5-1", "claude-fable-5-1[1m]"), true);
  assert.equal(sameModel("claude-haiku-4-5", "claude-haiku-4-5-20251001"), true);
  assert.equal(sameModel("claude-opus-5", "claude-sonnet-5"), false);
});
