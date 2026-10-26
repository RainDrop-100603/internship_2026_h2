import fs from "node:fs";
import path from "node:path";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { loadAbapMcpServers } from "./abapMcp.mjs";

export const ABAP_MIRROR_ROOT = "abap";

// 오브젝트 타입별 MCP 도구·인자 매핑 — 확장 시 이 테이블에 한 항목 추가.
// getField는 2026-10-26 트라이얼에서 실측 확인 (DDLS=ddl_data, TABL=table_data 등).
// 인자 이름이 도구마다 달라서(class_name / ddl_name / name …) 호출 인자는 함수로 만든다.
// 모든 저장은 activate=false로 하고, 마지막에 ActivateObjects로 한 번에 활성화한다
// (서로 참조하는 CDS·BDEF·Behavior Pool을 하나씩 활성화하면 순서에 따라 실패하므로).
const ADAPTERS = {
  TABL: {
    dir: "tabl",
    ext: "tabl.abap",
    getField: "table_data",
    get: (name) => ["GetTable", { table_name: name }],
    create: (name, pkg) => ["CreateTable", { table_name: name, package_name: pkg }],
    update: (name, source) => ["UpdateTable", { table_name: name, ddl_code: source, activate: false }],
    del: (name) => ["DeleteTable", { table_name: name }],
  },
  DDLS: {
    dir: "ddls",
    ext: "ddls.abap",
    getField: "ddl_data",
    get: (name) => ["GetDdl", { ddl_name: name }],
    create: (name, pkg) => ["CreateDdl", { ddl_name: name, package_name: pkg }],
    update: (name, source) => ["UpdateDdl", { ddl_name: name, ddl_source: source, activate: false }],
    del: (name) => ["DeleteDdl", { ddl_name: name }],
  },
  BDEF: {
    dir: "bdef",
    ext: "bdef.abap",
    getField: "behavior_definition_data",
    get: (name) => ["GetBehaviorDefinition", { behavior_definition_name: name }],
    // 생성 시 루트 엔터티·구현 타입이 필수라 소스 첫머리에서 읽어낸다.
    create: (name, pkg, source) => {
      const { implementationType, rootEntity } = parseBdefHeader(source);
      return [
        "CreateBehaviorDefinition",
        {
          name,
          package_name: pkg,
          root_entity: rootEntity,
          implementation_type: implementationType,
          activate: false,
        },
      ];
    },
    update: (name, source) => ["UpdateBehaviorDefinition", { name, source_code: source, activate: false }],
    del: (name) => ["DeleteBehaviorDefinition", { behavior_definition_name: name }],
  },
  INTF: {
    dir: "intf",
    ext: "intf.abap",
    getField: "source_code",
    get: (name) => ["GetInterface", { interface_name: name }],
    create: (name, pkg) => ["CreateInterface", { interface_name: name, package_name: pkg }],
    update: (name, source) => ["UpdateInterface", { interface_name: name, source_code: source, activate: false }],
    del: (name) => ["DeleteInterface", { interface_name: name }],
  },
  CLAS: {
    dir: "clas",
    ext: "clas.abap",
    getField: "source_code",
    get: (name) => ["GetClass", { class_name: name }],
    // Behavior Pool(FOR BEHAVIOR OF)은 일반 CreateClass로 만들면 BDEF와 연결되지 않는다.
    create: (name, pkg, source) => {
      const bdef = behaviorPoolTarget(source);
      if (bdef) {
        return [
          "CreateBehaviorImplementation",
          { class_name: name, behavior_definition: bdef, package_name: pkg },
        ];
      }
      return ["CreateClass", { class_name: name, package_name: pkg }];
    },
    update: (name, source) => ["UpdateClass", { class_name: name, source_code: source, activate: false }],
    del: (name) => ["DeleteClass", { class_name: name }],
  },
  // 클래스의 로컬 타입 인클루드(CCIMP) — RAP 핸들러(lhc_*)·세이버 코드가 여기에 들어간다.
  // 독립 오브젝트가 아니므로 생성·삭제가 없고, 활성화는 소속 클래스(CLAS) 단위로 한다.
  CLAS_LOCALS: {
    dir: "clas",
    ext: "clas.locals_imp.abap",
    activationType: "CLAS",
    getField: "local_types_code",
    get: (name) => ["GetLocalTypes", { class_name: name }],
    update: (name, source) => [
      "UpdateLocalTypes",
      { class_name: name, local_types_code: source, activate_on_update: false },
    ],
  },
  DDLX: {
    dir: "ddlx",
    ext: "ddlx.abap",
    getField: "metadata_extension_data",
    get: (name) => ["GetMetadataExtension", { metadata_extension_name: name }],
    create: (name, pkg) => ["CreateMetadataExtension", { name, package_name: pkg, activate: false }],
    update: (name, source) => ["UpdateMetadataExtension", { name, source_code: source, activate: false }],
    del: (name) => ["DeleteMetadataExtension", { metadata_extension_name: name }],
  },
  SRVD: {
    dir: "srvd",
    ext: "srvd.abap",
    getField: "service_definition_data",
    get: (name) => ["GetServiceDefinition", { service_definition_name: name }],
    create: (name, pkg) => [
      "CreateServiceDefinition",
      { service_definition_name: name, package_name: pkg, activate: false },
    ],
    update: (name, source) => [
      "UpdateServiceDefinition",
      { service_definition_name: name, source_code: source, activate: false },
    ],
    del: (name) => ["DeleteServiceDefinition", { service_definition_name: name }],
  },
};

// 반영 순서: 참조되는 쪽을 먼저 저장한다 (테이블 → CDS → BDEF → 클래스 → UI 주석 → 서비스).
// 삭제는 이 역순으로, 저장보다 먼저 처리한다.
const APPLY_ORDER = ["TABL", "DDLS", "BDEF", "INTF", "CLAS", "CLAS_LOCALS", "DDLX", "SRVD"];

// 활성화 단계 — 같은 단계는 한 번에 저장·활성화한다(서로 참조하는 CDS끼리도 OK).
// 단계를 나누는 이유: UpdateLocalTypes는 저장 전에 *활성* 버전 기준으로 문법 검사를 해서,
// CDS·BDEF가 아직 비활성이면 "not a root entity" 오류로 저장 자체가 거부된다 (2026-10-26 실측).
const ACTIVATION_PHASES = [["TABL", "DDLS", "BDEF"], ["INTF", "CLAS"], ["CLAS_LOCALS"], ["DDLX", "SRVD"]];

// SE80/ADT가 새 클래스에 넣어주는 로컬 타입 인클루드 기본 주석 — 이것뿐이면 pull하지 않는다.
const LOCALS_PLACEHOLDER = /^\s*(\*.*)?$/;

export function isPlaceholderLocals(source) {
  return String(source ?? "")
    .split(/\r?\n/)
    .every((line) => LOCALS_PLACEHOLDER.test(line));
}

export function parseBdefHeader(source) {
  const text = String(source ?? "").replace(/\/\/.*$/gm, "");
  const typeMatch = text.match(/^\s*(managed|unmanaged|projection|abstract)\b/i);
  const rootMatch = text.match(/define\s+(?:root\s+)?behavior\s+for\s+([\w/]+)/i);
  if (!typeMatch || !rootMatch) {
    throw new Error(
      "BDEF 소스 첫머리에서 구현 타입(managed/unmanaged/projection/abstract)과 " +
        "'define behavior for <루트 엔터티>'를 찾지 못했습니다."
    );
  }
  const raw = typeMatch[1].toLowerCase();
  return {
    implementationType: raw.charAt(0).toUpperCase() + raw.slice(1),
    rootEntity: rootMatch[1].toUpperCase(),
  };
}

export function behaviorPoolTarget(source) {
  const match = String(source ?? "").match(/\bFOR\s+BEHAVIOR\s+OF\s+([\w/]+)/i);
  return match ? match[1].toUpperCase() : null;
}

// 파일 경로 → { kind, objectName }. 확장자가 더 긴 것(locals_imp)부터 검사해야
// "x.clas.locals_imp.abap"이 일반 클래스 파일로 잘못 분류되지 않는다.
export function classifyAbapFile(filePath) {
  const parts = filePath.split(/[\\/]/);
  if (parts[0] !== ABAP_MIRROR_ROOT || parts.length !== 3) return null;
  const [, dir, base] = parts;
  const candidates = Object.entries(ADAPTERS)
    .filter(([, a]) => a.dir === dir)
    .sort(([, a], [, b]) => b.ext.length - a.ext.length);
  for (const [kind, adapter] of candidates) {
    const suffix = `.${adapter.ext}`;
    if (base.endsWith(suffix)) {
      return { kind, objectName: base.slice(0, -suffix.length).toUpperCase() };
    }
  }
  return { kind: null, objectName: base.toUpperCase(), dir };
}

function toFilePath(kind, objectName) {
  const adapter = ADAPTERS[kind];
  return path.join(ABAP_MIRROR_ROOT, adapter.dir, `${objectName.toLowerCase()}.${adapter.ext}`);
}

// 지원 패턴 외의 파일 — 예: abapGit 스타일 테스트 인클루드(*.clas.testclasses.abap) —
// 을 걸러내지 않으면 "ZCL_FOO.CLAS.TESTCLASSES" 같은 깨진 이름으로 SAP에 호출이 나가
// 알아보기 힘든 500 에러만 돌아온다.
const VALID_OBJECT_NAME = /^[A-Z][A-Z0-9_]*$/;

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

async function callAbapToolRaw(client, name, args) {
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
  if (result.isError) {
    throw new Error(`${name} 호출 실패: ${parsed?.message || parsed?.raw || text}`);
  }
  return parsed;
}

async function callAbapTool(client, name, args) {
  const parsed = await callAbapToolRaw(client, name, args);
  if (parsed?.success === false) {
    throw new Error(`${name} 호출 실패: ${parsed?.message || parsed?.raw || JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function callAdapter(client, [tool, args]) {
  return callAbapTool(client, tool, args);
}

function sourceFrom(getResult, adapter) {
  if (typeof getResult[adapter.getField] === "string") return getResult[adapter.getField];
  // 실측과 다른 응답이 오면 소스로 보이는 문자열 필드를 찾는다 (빈 파일로 덮어쓰지 않도록).
  const fallbackKey = Object.keys(getResult).find(
    (key) => typeof getResult[key] === "string" && /(_data|_code|_source)$/.test(key)
  );
  if (fallbackKey) return getResult[fallbackKey];
  throw new Error(`${adapter.dir} 응답에서 소스 필드(${adapter.getField})를 찾지 못했습니다.`);
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

    const writeSource = (kind, name, source) => {
      const relPath = toFilePath(kind, name);
      const absPath = path.join(worktreeDir, relPath);
      fs.mkdirSync(path.dirname(absPath), { recursive: true });
      fs.writeFileSync(absPath, source, "utf8");
      pulled.push({ path: relPath, type: kind, name });
    };

    for (const entry of list) {
      if (entry.isPackage) continue;
      const kind = String(entry.adtType ?? "").split("/")[0];
      const adapter = ADAPTERS[kind];
      if (!adapter) {
        skipped.push({ name: entry.name, adtType: entry.adtType });
        continue;
      }

      writeSource(kind, entry.name, sourceFrom(await callAdapter(client, adapter.get(entry.name)), adapter));

      if (kind === "CLAS") {
        const locals = ADAPTERS.CLAS_LOCALS;
        const localsSource = sourceFrom(await callAdapter(client, locals.get(entry.name)), locals);
        if (!isPlaceholderLocals(localsSource)) writeSource("CLAS_LOCALS", entry.name, localsSource);
      }
    }

    return { pulled, skipped };
  });
}

// ActivateObjects의 errors 항목은 { type, text, line } (실측). 다른 형태도 대비해 폴백.
function describeActivationError(error) {
  if (typeof error === "string") return error;
  const text = error?.text ?? error?.shortText ?? error?.message ?? JSON.stringify(error);
  const where = error?.objDescr ?? error?.object ?? error?.name;
  const line = error?.line ? ` (line ${error.line})` : "";
  return `${where ? `${where}: ` : ""}${text}${line}`;
}

export function planAbapChanges(changedFiles) {
  const plan = [];
  const failed = [];
  for (const file of changedFiles) {
    const classified = classifyAbapFile(file.path);
    if (!classified) continue; // abap/ 밖의 파일은 반영 대상이 아니다.
    const { kind, objectName } = classified;
    if (!kind) {
      failed.push({
        path: file.path,
        name: objectName,
        reason:
          "지원하지 않는 파일 형식입니다. 허용: " +
          Object.values(ADAPTERS)
            .map((a) => `abap/${a.dir}/<이름>.${a.ext}`)
            .join(", "),
      });
      continue;
    }
    if (!VALID_OBJECT_NAME.test(objectName)) {
      failed.push({ path: file.path, name: objectName, reason: "오브젝트 이름 형식이 올바르지 않습니다." });
      continue;
    }
    if (file.status === "renamed" || file.status === "copied") {
      failed.push({ path: file.path, name: objectName, reason: "지원하지 않는 변경 유형입니다 (rename/copy)." });
      continue;
    }
    plan.push({ ...file, kind, objectName });
  }

  // 클래스 자체를 지우면 로컬 인클루드도 함께 사라지므로 따로 처리하지 않는다.
  const deletedClasses = new Set(
    plan.filter((p) => p.kind === "CLAS" && p.status === "deleted").map((p) => p.objectName)
  );
  const effective = plan.filter(
    (p) => !(p.kind === "CLAS_LOCALS" && deletedClasses.has(p.objectName))
  );

  const rank = (p) => APPLY_ORDER.indexOf(p.kind);
  const deletes = effective.filter((p) => p.status === "deleted").sort((a, b) => rank(b) - rank(a));
  const upserts = effective.filter((p) => p.status !== "deleted").sort((a, b) => rank(a) - rank(b));
  return { deletes, upserts, failed };
}

export async function applyAbapChanges({ worktreeDir, changedFiles, packageName }) {
  const { deletes, upserts, failed } = planAbapChanges(changedFiles);
  const applied = [];
  if (failed.length > 0) return { applied, failed };

  await withAbapClient(async (client) => {
    const toActivate = new Map();
    for (const item of deletes) {
      const adapter = ADAPTERS[item.kind];
      try {
        if (item.kind === "CLAS_LOCALS") {
          // 로컬 인클루드는 지울 수 없으므로 비우고, 소속 클래스를 다시 활성화한다.
          await callAdapter(client, adapter.update(item.objectName, "\r\n"));
          toActivate.set(`CLAS:${item.objectName}`, { name: item.objectName, type: "CLAS" });
        } else {
          await callAdapter(client, adapter.del(item.objectName));
        }
        applied.push({ path: item.path, name: item.objectName, action: "delete" });
      } catch (err) {
        failed.push({ path: item.path, name: item.objectName, reason: String(err?.message ?? err) });
      }
    }
    if (failed.length > 0) return;

    const activate = async (label) => {
      if (toActivate.size === 0) return true;
      const objects = [...toActivate.values()];
      toActivate.clear();
      const errors = [];
      // ActivateObjects는 BDEF에 대해 "Successfully activated"를 돌려주면서 실제로는
      // 활성화하지 않는다 (2026-10-26 실측). BDEF만 전용 도구로 활성화한다.
      const bdefs = objects.filter((o) => o.type === "BDEF");
      const others = objects.filter((o) => o.type !== "BDEF");
      if (others.length > 0) {
        const activation = await callAbapToolRaw(client, "ActivateObjects", { objects: others });
        errors.push(...(activation?.errors ?? []));
      }
      for (const bdef of bdefs) {
        const activation = await callAbapToolRaw(client, "ActivateBehaviorDefinition", { name: bdef.name });
        errors.push(...(activation?.errors ?? []));
      }
      // 활성화 응답만 믿지 않고, 서버의 비활성 목록에 남아 있는지 다시 확인한다.
      if (errors.length === 0) {
        const inactive = await callAbapToolRaw(client, "GetInactiveObjects", {});
        const stillInactive = objects.filter((o) =>
          (inactive?.objects ?? []).some(
            (entry) => entry.name === o.name && String(entry.type).split("/")[0] === o.type
          )
        );
        if (stillInactive.length > 0) {
          errors.push(
            `활성화 응답은 성공이었지만 여전히 비활성: ${stillInactive.map((o) => `${o.type} ${o.name}`).join(", ")}`
          );
        }
      }
      if (errors.length === 0) return true;
      failed.push({
        path: ABAP_MIRROR_ROOT,
        name: `활성화(${label})`,
        reason:
          `${objects.map((o) => o.name).join(", ")} — 소스는 서버에 비활성 버전으로 저장됐지만 ` +
          `활성화에 실패했습니다: ${errors.map(describeActivationError).join(" / ")}`,
      });
      return false;
    };

    // 삭제 단계에서 비운 로컬 인클루드의 클래스 재활성화.
    if (!(await activate("삭제 후"))) return;

    for (const phase of ACTIVATION_PHASES) {
      for (const item of upserts.filter((p) => phase.includes(p.kind))) {
        const adapter = ADAPTERS[item.kind];
        try {
          const source = fs.readFileSync(path.join(worktreeDir, item.path), "utf8");
          if (item.status === "added" && adapter.create) {
            await callAdapter(client, adapter.create(item.objectName, packageName, source));
          }
          await callAdapter(client, adapter.update(item.objectName, source));
          const type = adapter.activationType ?? item.kind;
          toActivate.set(`${type}:${item.objectName}`, { name: item.objectName, type });
          applied.push({
            path: item.path,
            name: item.objectName,
            action: item.status === "added" && adapter.create ? "create" : "update",
          });
        } catch (err) {
          failed.push({ path: item.path, name: item.objectName, reason: String(err?.message ?? err) });
          // 앞 단계(예: 테이블)가 실패하면 뒤 단계는 거의 확실히 연쇄 실패하므로 중단한다.
          return;
        }
      }
      if (!(await activate(phase.join("·")))) return;
    }
  });

  return { applied, failed };
}
