import fs from "node:fs";
import path from "node:path";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { loadAbapMcpServers } from "./abapMcp.mjs";

export const ABAP_MIRROR_ROOT = "abap";

// Get/Update 요청·응답 필드명이 타입마다 조금씩 다르다 — 확장 시 이 테이블에 한 줄 추가.
// CLAS/INTF/DDLS의 요청 필드명과 CLAS의 응답 필드명(source_code)은 실측 확인됨.
// DDLS/TABL의 Get 응답 필드명(getField)은 추정치 — pullAbapObjects가 흔한 후보로 폴백하지만,
// 실제 CDS/테이블을 한 번 pull해보고 비어있으면 이 테이블의 getField를 바로잡을 것.
const ADAPTERS = {
  CLAS: {
    dir: "clas",
    ext: "clas.abap",
    nameField: "class_name",
    getField: "source_code",
    updateField: "source_code",
    get: "GetClass",
    create: "CreateClass",
    update: "UpdateClass",
    del: "DeleteClass",
  },
  INTF: {
    dir: "intf",
    ext: "intf.abap",
    nameField: "interface_name",
    getField: "source_code",
    updateField: "source_code",
    get: "GetInterface",
    create: "CreateInterface",
    update: "UpdateInterface",
    del: "DeleteInterface",
  },
  DDLS: {
    dir: "ddls",
    ext: "ddls.abap",
    nameField: "ddl_name",
    getField: "ddl_source",
    updateField: "ddl_source",
    get: "GetDdl",
    create: "CreateDdl",
    update: "UpdateDdl",
    del: "DeleteDdl",
  },
  TABL: {
    dir: "tabl",
    ext: "tabl.abap",
    nameField: "table_name",
    getField: "ddl_source",
    updateField: "ddl_code",
    get: "GetTable",
    create: "CreateTable",
    update: "UpdateTable",
    del: "DeleteTable",
  },
};

function adapterForDir(dir) {
  return Object.values(ADAPTERS).find((a) => a.dir === dir) ?? null;
}

async function withAbapClient(fn) {
  const servers = loadAbapMcpServers();
  const serverConfig = servers?.["abap-trial"];
  if (!serverConfig) {
    throw new Error("abap-trial MCP 서버 설정을 찾을 수 없습니다 (.mcp.json 확인 필요).");
  }

  const transport = new StdioClientTransport({
    command: serverConfig.command,
    args: serverConfig.args ?? [],
  });
  const client = new Client({ name: "unified-console-abap-sync", version: "0.0.1" });
  await client.connect(transport);
  try {
    return await fn(client);
  } finally {
    await client.close();
  }
}

async function callAbapTool(client, name, args) {
  const result = await client.callTool({ name, arguments: args });
  const text = result.content?.find((block) => block.type === "text")?.text;
  if (!text) {
    if (result.isError) throw new Error(`${name} 호출 실패: 응답에 내용이 없습니다.`);
    return {};
  }
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { raw: text };
  }
  if (result.isError || parsed?.success === false) {
    throw new Error(`${name} 호출 실패: ${parsed?.message || parsed?.raw || text}`);
  }
  return parsed;
}

function toFilePath(adapter, objectName) {
  return path.join(ABAP_MIRROR_ROOT, adapter.dir, `${objectName.toLowerCase()}.${adapter.ext}`);
}

function toObjectName(adapter, filePath) {
  const base = path.basename(filePath);
  const suffix = `.${adapter.ext}`;
  const stem = base.endsWith(suffix) ? base.slice(0, -suffix.length) : base;
  return stem.toUpperCase();
}

// pull한 파일명(<이름>.<타입확장자>) 외의 패턴 — 예: abapGit 스타일 테스트 인클루드
// (*.clas.testclasses.abap), locals/macros 등 — 으로 생성된 파일은 아직 지원하지 않는다.
// 걸러내지 않으면 "ZCL_FOO.CLAS.TESTCLASSES.ABAP" 같은 깨진 이름으로 SAP에 호출이 나가
// 알아보기 힘든 500 에러만 돌아온다.
const VALID_OBJECT_NAME = /^[A-Z][A-Z0-9_]*$/;

function isValidObjectName(name) {
  return VALID_OBJECT_NAME.test(name);
}

export async function pullAbapObjects({ packageName, worktreeDir }) {
  return withAbapClient(async (client) => {
    const contents = await callAbapTool(client, "GetPackageContents", {
      package_name: packageName,
      include_subpackages: true,
    });
    const list = Array.isArray(contents) ? contents : contents?.objects ?? [];

    const pulled = [];
    const skipped = [];

    for (const entry of list) {
      if (entry.isPackage) continue;
      const adtPrefix = String(entry.adtType ?? "").split("/")[0];
      const adapter = ADAPTERS[adtPrefix];
      if (!adapter) {
        skipped.push({ name: entry.name, adtType: entry.adtType });
        continue;
      }

      const getResult = await callAbapTool(client, adapter.get, { [adapter.nameField]: entry.name });
      // getField 추정이 틀렸을 경우(특히 DDLS/TABL — 실측 미확인) 흔한 후보 필드명을 순서대로 시도.
      const source =
        getResult[adapter.getField] ??
        getResult.source_code ??
        getResult.ddl_source ??
        getResult.ddl_code ??
        "";
      const relPath = toFilePath(adapter, entry.name);
      const absPath = path.join(worktreeDir, relPath);
      fs.mkdirSync(path.dirname(absPath), { recursive: true });
      fs.writeFileSync(absPath, source, "utf8");
      pulled.push({ path: relPath, type: adtPrefix, name: entry.name });
    }

    return { pulled, skipped };
  });
}

function classifyChangedFiles(changedFiles) {
  const mirrorPrefix = ABAP_MIRROR_ROOT + path.sep;
  const mirrorPrefixPosix = ABAP_MIRROR_ROOT + "/";
  return changedFiles.filter(
    (file) => file.path.startsWith(mirrorPrefix) || file.path.startsWith(mirrorPrefixPosix)
  );
}

export async function applyAbapChanges({ worktreeDir, changedFiles, packageName }) {
  const relevant = classifyChangedFiles(changedFiles);
  const applied = [];
  const failed = [];

  await withAbapClient(async (client) => {
    for (const file of relevant) {
      const parts = file.path.split(/[\\/]/);
      const dir = parts[1]; // abap/<dir>/<file>
      const adapter = adapterForDir(dir);
      if (!adapter) {
        failed.push({ path: file.path, reason: "알 수 없는 오브젝트 타입 폴더입니다." });
        continue;
      }
      if (file.status === "renamed" || file.status === "copied") {
        failed.push({ path: file.path, reason: "지원하지 않는 변경 유형입니다 (rename/copy)." });
        continue;
      }

      const objectName = toObjectName(adapter, file.path);
      if (!isValidObjectName(objectName)) {
        failed.push({
          path: file.path,
          name: objectName,
          reason:
            `파일명이 "<이름>.${adapter.ext}" 형식이 아닙니다 (지원하지 않는 보조 파일 — 예: 테스트 인클루드). ` +
            "테스트 클래스는 별도 파일로 만들지 말고 클래스 소스 안의 로컬 테스트 클래스로 작성해주세요.",
        });
        continue;
      }
      try {
        if (file.status === "deleted") {
          await callAbapTool(client, adapter.del, { [adapter.nameField]: objectName });
          applied.push({ path: file.path, name: objectName, action: "delete" });
          continue;
        }

        const absPath = path.join(worktreeDir, file.path);
        const source = fs.readFileSync(absPath, "utf8");

        if (file.status === "added") {
          await callAbapTool(client, adapter.create, {
            [adapter.nameField]: objectName,
            package_name: packageName,
          });
        }
        await callAbapTool(client, adapter.update, {
          [adapter.nameField]: objectName,
          [adapter.updateField]: source,
          activate: true,
        });
        applied.push({ path: file.path, name: objectName, action: file.status === "added" ? "create" : "update" });
      } catch (err) {
        failed.push({ path: file.path, name: objectName, reason: String(err?.message ?? err) });
      }
    }
  });

  return { applied, failed };
}
