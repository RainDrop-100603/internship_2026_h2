import test from "node:test";
import assert from "node:assert/strict";
import { applyClaudeRuntimeMetadata } from "./taskManager.mjs";

test("Claude init metadata records the effective model and effort", () => {
  const run = { actualModels: [], actualEffort: null, modelSource: null, effortSource: null };

  const changed = applyClaudeRuntimeMetadata(run, {
    type: "system",
    subtype: "init",
    model: "claude-sonnet-4-6",
    effort: "medium",
  });

  assert.equal(changed, true);
  assert.deepEqual(run.actualModels, ["claude-sonnet-4-6"]);
  assert.equal(run.actualEffort, "medium");
  assert.equal(run.modelSource, "reported");
  assert.equal(run.effortSource, "reported");
});

test("Claude runtime metadata ignores unrelated messages", () => {
  const run = { actualModels: [], actualEffort: null, modelSource: null, effortSource: null };

  const changed = applyClaudeRuntimeMetadata(run, {
    type: "assistant",
    message: { model: "claude-sonnet-4-6" },
  });

  assert.equal(changed, false);
  assert.deepEqual(run.actualModels, []);
  assert.equal(run.actualEffort, null);
});
