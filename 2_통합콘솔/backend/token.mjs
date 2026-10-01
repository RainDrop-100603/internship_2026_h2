import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const runtimeDir = path.join(__dirname, "..", ".runtime");
export const sessionFile = path.join(runtimeDir, "session.json");

export function createSession({ port }) {
  const token = crypto.randomBytes(32).toString("hex");
  return { token, port, issuedAt: new Date().toISOString(), pid: process.pid };
}

// 서버가 실제로 listen에 성공한 뒤에만 호출한다. start.mjs는 이 파일의
// 존재를 "백엔드 준비 완료" 신호로 사용하므로, listen 실패 시에는 쓰지 않는다.
export function publishSession(session) {
  fs.mkdirSync(runtimeDir, { recursive: true });
  fs.writeFileSync(sessionFile, JSON.stringify(session, null, 2));
}
