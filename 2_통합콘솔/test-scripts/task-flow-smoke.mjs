// 백엔드가 실행 중일 때(npm run backend 또는 npm start) 다음처럼 실행:
//   node test-scripts/task-flow-smoke.mjs .runtime/session.json
//
// Phase 2 전체 흐름(worktree 생성 → Claude 실행 → WebSocket 로그 스트리밍 →
// 완료)이 정상 동작하는지 확인하는 수동 스모크 테스트.
import fs from "node:fs";
import WebSocket from "ws";

const session = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const base = `http://127.0.0.1:${session.port}`;

const ws = new WebSocket(`ws://127.0.0.1:${session.port}/ws?token=${session.token}`, {
  headers: { origin: "http://localhost:5173" },
});

ws.on("open", async () => {
  console.log("[ws] connected");
  const headers = { "Content-Type": "application/json", "X-Console-Token": session.token };
  const { projects } = await fetch(`${base}/api/projects`, { headers }).then((r) => r.json());
  if (projects.length === 0) throw new Error("먼저 콘솔에서 테스트할 프로젝트를 등록해주세요.");
  const projectId = projects[0].id;

  const res = await fetch(`${base}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      projectId,
      instruction: "greet.js의 greet 함수가 이름이 비어있으면 'Hello, stranger'를 반환하도록 수정해줘",
    }),
  });
  const body = await res.json();
  console.log("[http] task created:", body);
});

ws.on("message", (data) => {
  const event = JSON.parse(data.toString());
  console.log("[ws event]", event.type, event.role ?? event.status ?? "", "-", event.text ?? event.error ?? "");
  if (event.type === "status" && ["completed", "failed", "aborted"].includes(event.status)) {
    setTimeout(() => process.exit(0), 500);
  }
});

ws.on("error", (err) => console.error("[ws error]", err));

setTimeout(() => {
  console.error("[timeout] no completion after 180s");
  process.exit(1);
}, 180000);
