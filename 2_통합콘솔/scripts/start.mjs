import path from "node:path";
import fs from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import open from "open";
import crossSpawn from "cross-spawn";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const sessionFile = path.join(root, ".runtime", "session.json");

function waitForSessionFile(timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const timer = setInterval(() => {
      if (fs.existsSync(sessionFile)) {
        clearInterval(timer);
        resolve(JSON.parse(fs.readFileSync(sessionFile, "utf8")));
      } else if (Date.now() - start > timeoutMs) {
        clearInterval(timer);
        reject(new Error("backend session file did not appear in time"));
      }
    }, 200);
  });
}

// 이전 실행에서 남은 session.json이 있으면 "새로 생성됨"으로 착각해
// stale 토큰을 읽는 경쟁 상태가 생기므로 시작 전에 지운다.
fs.rmSync(sessionFile, { force: true });

console.log("[start] backend 실행 중...");
const backend = crossSpawn("node", ["backend/server.mjs"], {
  cwd: root,
  stdio: "inherit",
});

const session = await waitForSessionFile();
console.log(`[start] backend ready on port ${session.port}`);

const envLocal = [
  `VITE_API_BASE_URL=http://127.0.0.1:${session.port}`,
  `VITE_WS_URL=ws://127.0.0.1:${session.port}/ws`,
  `VITE_API_TOKEN=${session.token}`,
  "",
].join("\n");
fs.writeFileSync(path.join(root, "frontend", ".env.local"), envLocal);

console.log("[start] frontend 실행 중...");
const frontend = crossSpawn("npm", ["run", "dev"], {
  cwd: path.join(root, "frontend"),
  stdio: "inherit",
});

if (process.env.COGENT_NO_OPEN !== "1") {
  setTimeout(() => {
    open("http://localhost:5173").catch(() => {});
  }, 2500);
}

let shuttingDown = false;

function stopProcessTree(child) {
  if (!child.pid) return;
  if (process.platform === "win32") {
    try {
      execFileSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" });
    } catch {
      // Process may already have exited.
    }
  } else {
    child.kill("SIGTERM");
  }
}

function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  stopProcessTree(frontend);
  stopProcessTree(backend);
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
