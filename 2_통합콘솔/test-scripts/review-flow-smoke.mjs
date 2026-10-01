// 백엔드가 실행 중일 때(npm run backend 또는 npm start) 다음처럼 실행:
//   node test-scripts/review-flow-smoke.mjs .runtime/session.json
//
// Phase 4 전체 흐름(작업 완료 → diff 준비 → Codex 리뷰 요청 → 결과 수신)이
// 정상 동작하는지 확인하는 수동 스모크 테스트.
import fs from "node:fs";
import WebSocket from "ws";

const session = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const base = `http://127.0.0.1:${session.port}`;
const headers = { "Content-Type": "application/json", "X-Console-Token": session.token };

const ws = new WebSocket(`ws://127.0.0.1:${session.port}/ws?token=${session.token}`, {
  headers: { origin: "http://localhost:5173" },
});

let taskId;
ws.on("open", async () => {
  const { projects } = await fetch(`${base}/api/projects`, { headers }).then((r) => r.json());
  if (projects.length === 0) throw new Error("먼저 콘솔에서 테스트할 프로젝트를 등록해주세요.");
  const projectId = projects[0].id;

  const res = await fetch(`${base}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      projectId,
      instruction: "greet.js에 이름을 대문자로 바꿔서 반환하는 shout 함수를 추가해줘",
    }),
  });
  const body = await res.json();
  taskId = body.taskId;
  console.log("[http] task created:", body);
});

ws.on("message", async (data) => {
  const event = JSON.parse(data.toString());
  console.log("[ws event]", event.type, event.role ?? event.status ?? "", "-", (event.text ?? event.error ?? "").slice(0, 100));

  if (event.type === "status" && event.status === "completed") {
    console.log("[http] requesting codex review...");
    const res = await fetch(`${base}/api/tasks/${taskId}/review`, {
      method: "POST",
      headers,
      body: JSON.stringify({ instruction: "" }),
    });
    console.log("[http] review request response:", await res.json());
  }

  if (event.type === "review_status" && ["done", "failed"].includes(event.status)) {
    const reviewRes = await fetch(`${base}/api/tasks/${taskId}/review`, { headers });
    console.log("[http] final review:", JSON.stringify(await reviewRes.json(), null, 2));
    process.exit(0);
  }
});

ws.on("error", (err) => console.error("[ws error]", err));

setTimeout(() => {
  console.error("[timeout] no review completion after 20min");
  process.exit(1);
}, 20 * 60 * 1000);
