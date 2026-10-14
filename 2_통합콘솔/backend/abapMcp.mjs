import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
// 저장소 루트의 .mcp.json (abap-trial 서버 설정). 등록된 프로젝트가 어디든
// 동일한 ABAP MCP 설정을 쓸 수 있도록 특정 레포 경로에 의존하지 않고 고정 상수/환경변수로 둔다.
// abapSync.mjs가 이 설정으로 백엔드 전용 MCP 클라이언트(pull/apply)를 띄운다.
const DEFAULT_CONFIG_PATH = path.resolve(here, "..", "..", ".mcp.json");

let cachedServers;
let cachedPath;

export function loadAbapMcpServers() {
  const configPath = process.env.ABAP_MCP_CONFIG_PATH || DEFAULT_CONFIG_PATH;
  if (cachedServers !== undefined && cachedPath === configPath) {
    return cachedServers;
  }
  cachedPath = configPath;
  try {
    const raw = fs.readFileSync(configPath, "utf8");
    const parsed = JSON.parse(raw);
    cachedServers = parsed.mcpServers ?? null;
    if (!cachedServers) {
      console.warn(`[abapMcp] ${configPath}에 mcpServers 설정이 없습니다.`);
    }
  } catch (error) {
    console.warn(`[abapMcp] MCP 설정을 읽지 못했습니다 (${configPath}): ${error.message}`);
    cachedServers = null;
  }
  return cachedServers;
}
