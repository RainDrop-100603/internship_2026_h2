import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { getSettings, initSettings, updateSettings } from "./settings.mjs";

test("agent settings use defaults, validate values, and persist", (t) => {
  const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-settings-test-"));
  t.after(() => fs.rmSync(runtimeRoot, { recursive: true, force: true }));

  initSettings(runtimeRoot);
  assert.deepEqual(getSettings(), {
    claude: { model: "default", effort: "medium" },
    codex: { model: "gpt-6-astra", effort: "medium" },
  });

  updateSettings({
    claude: { model: "fable", effort: "high" },
    codex: { model: "gpt-5.5", effort: "xhigh" },
  });
  initSettings(runtimeRoot);
  assert.deepEqual(getSettings(), {
    claude: { model: "fable", effort: "high" },
    codex: { model: "gpt-5.5", effort: "xhigh" },
  });
  assert.throws(
    () => updateSettings({ claude: { model: "unknown", effort: "medium" }, codex: getSettings().codex }),
    /지원하지 않는 claude 모델/
  );
  assert.throws(
    () => updateSettings({ claude: getSettings().claude, codex: { model: "gpt-5.5", effort: "max" } }),
    /지원하지 않는 codex effort/
  );
});
