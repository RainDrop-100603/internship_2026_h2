import { query } from "@anthropic-ai/claude-agent-sdk";

async function main() {
  const result = query({
    prompt: "Say 'hello from claude agent sdk' and nothing else.",
    options: {
      maxTurns: 1,
    },
  });

  for await (const message of result) {
    if (message.type === "assistant") {
      const text = message.message.content
        .filter((block) => block.type === "text")
        .map((block) => block.text)
        .join("");
      console.log("[assistant]", text);
    } else if (message.type === "result") {
      console.log("[result]", message.subtype, message.is_error ? "ERROR" : "OK");
      if (message.is_error) {
        console.error(message);
      }
    }
  }
}

main().catch((err) => {
  console.error("[smoke test failed]", err);
  process.exit(1);
});
