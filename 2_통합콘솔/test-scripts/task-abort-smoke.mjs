// 백엔드가 실행 중일 때(npm run backend 또는 npm start) 다음처럼 실행:
//   node test-scripts/task-abort-smoke.mjs .runtime/session.json
//
// 작업 도중 중단(abort) 요청이 worktree 정리까지 포함해 정상 동작하는지
// 확인하는 수동 스모크 테스트.
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
      instruction:
        "README.md 파일 끝에 라이선스 섹션을 추가하고, 그 다음 CONTRIBUTING.md 파일도 새로 만들어서 기여 가이드를 5문단으로 작성해줘",
    }),
  });
  const body = await res.json();
  taskId = body.taskId;
  console.log("[http] task created:", body);

  setTimeout(async () => {
    console.log("[http] aborting...");
    const abortRes = await fetch(`${base}/api/tasks/${taskId}/abort`, {
      method: "POST",
      headers,
      body: JSON.stringify({ confirm: true, taskId }),
    });
    console.log("[http] abort response:", await abortRes.json());
  }, 3000);
});

ws.on("message", (data) => {
  const event = JSON.parse(data.toString());
  console.log("[ws event]", event.type, event.role ?? event.status ?? "", "-", (event.text ?? event.error ?? "").slice(0, 80));
  if (event.type === "status" && ["completed", "failed", "aborted"].includes(event.status)) {
    setTimeout(() => process.exit(0), 500);
  }
});

setTimeout(() => {
  console.error("[timeout]");
  process.exit(1);
}, 60000);
