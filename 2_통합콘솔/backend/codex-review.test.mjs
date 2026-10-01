import test from "node:test";
import assert from "node:assert/strict";
import { parseCodexUsageEvent } from "./codexReview.mjs";

test("Codex turn completion usage is normalized", () => {
  const result = parseCodexUsageEvent({
    type: "turn.completed",
    usage: {
      input_tokens: 24763,
      cached_input_tokens: 24448,
      output_tokens: 122,
      reasoning_output_tokens: 31,
    },
  });

  assert.deepEqual(result.usage, {
    inputTokens: 24763,
    cachedInputTokens: 24448,
    cacheCreationInputTokens: 0,
    outputTokens: 122,
    reasoningTokens: 31,
  });
});
