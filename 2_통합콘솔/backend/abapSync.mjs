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

// SearchObject 응답은 "name\ttype\tdescription\tpackage" 헤더가 붙은 TSV 텍스트 (실측).
export function parseSearchResult(raw) {
  const lines = String(raw ?? "").split(/\r?\n/).filter((line) => line.trim());
  if (lines.length === 0) return [];
  const header = lines[0].split("\t").map((h) => h.trim().toLowerCase());
  const col = (name) => header.indexOf(name);
  return lines.slice(1).map((line) => {
    const cells = line.split("\t");
    return {
      name: (cells[col("name")] ?? "").trim(),
      type: (cells[col("type")] ?? "").trim(),
      packageName: (cells[col("package")] ?? "").trim(),
    };
  });
}

// "added" 파일이라도 서버에 이미 있을 수 있다 — 이전 승인이 중간에 끊겨 일부만 만들어진 경우.
// 같은 패키지면 생성을 건너뛰고 수정으로 진행해 승인을 다시 눌러도 이어서 반영되게 한다.
// 다른 패키지(공유 트라이얼의 다른 사용자)에 같은 이름이 있으면 덮어쓰지 않고 중단한다.
async function existingObjectPackage(client, kind, name) {
  const adtType = kind === "CLAS_LOCALS" ? "CLAS" : kind;
  const result = await callAbapToolRaw(client, "SearchObject", {
    object_name: name,
    object_type: adtType,
    maxResults: 10,
  });
  const hit = parseSearchResult(result?.raw ?? "").find(
    (row) => row.name.toUpperCase() === name && row.type.split("/")[0] === adtType
  );
  return hit ? hit.packageName : null;
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

// 한 단계 분량의 오브젝트를 활성화하고 오류 메시지 목록을 돌려준다 (빈 배열 = 성공).
async function activateBatch(client, objects) {
  if (objects.length === 0) return [];
  const errors = [];
  // ActivateObjects는 BDEF에 대해 "Successfully activated"를 돌려주면서 실제로는
  // 활성화하지 않는다 (2026-10-26 실측). BDEF만 전용 도구로 활성화한다.
  // 프로젝션 BDEF는 기반 BDEF가 활성이어야 활성화된다 — 이름순(ZC_ < ZR_)으로 돌리면
  // "base entity contains errors"로 실패하므로 기반(비프로젝션)을 먼저 활성화한다 (2026-11-07 실측).
  const bdefs = objects
    .filter((o) => o.type === "BDEF")
    .sort((a, b) => Number(Boolean(a.projection)) - Number(Boolean(b.projection)));
  const others = objects.filter((o) => o.type !== "BDEF").map(({ name, type }) => ({ name, type }));
  // 활성화 도구 자체가 실패해도 예외로 전체를 끊지 않고, 오류 메시지로 모은다.
  const run = async (label, tool, args) => {
    try {
      const activation = await callAbapToolRaw(client, tool, args);
      errors.push(...(activation?.errors ?? []));
    } catch (err) {
      errors.push(`${label}: ${String(err?.message ?? err)}`);
    }
  };
  if (others.length > 0) await run("ActivateObjects", "ActivateObjects", { objects: others });
  for (const bdef of bdefs) {
    await run(`BDEF ${bdef.name}`, "ActivateBehaviorDefinition", { name: bdef.name });
    // 기반 BDEF가 실패하면 그 위의 프로젝션도 같은 이유로 실패하므로 원인 메시지만 남긴다.
    if (errors.length > 0) break;
  }
  // 활성화 응답만 믿지 않고, 서버의 비활성 목록에 남아 있는지 다시 확인한다.
  if (errors.length === 0) {
    const inactive = await callAbapToolRaw(client, "GetInactiveObjects", {});
    const stillInactive = objects.filter((o) =>
      (inactive?.objects ?? []).some((entry) => entry.name === o.name && String(entry.type).split("/")[0] === o.type)
    );
    if (stillInactive.length > 0) {
      errors.push(`활성화 응답은 성공이었지만 여전히 비활성: ${stillInactive.map((o) => `${o.type} ${o.name}`).join(", ")}`);
    }
  }
  return errors.map(describeActivationError);
}

// 파일 하나를 서버에 저장한다(필요하면 생성 후 소스 갱신, 활성화는 하지 않음).
async function saveItem(client, item, { worktreeDir, packageName }) {
  const adapter = ADAPTERS[item.kind];
  const source = fs.readFileSync(path.join(worktreeDir, item.path), "utf8");
  let action = "update";
  if (item.status === "added" && adapter.create) {
    const existingPackage = await existingObjectPackage(client, item.kind, item.objectName);
    if (existingPackage && existingPackage.toUpperCase() !== String(packageName).toUpperCase()) {
      throw new Error(
        `${item.objectName}은(는) 이미 다른 패키지(${existingPackage})에 있는 이름입니다. ` +
          "공유 트라이얼에서는 이름이 전역 유일해야 하니 다른 이름으로 바꿔주세요."
      );
    }
    if (!existingPackage) {
      await callAdapter(client, adapter.create(item.objectName, packageName, source));
      action = "create";
    } else {
      action = "update(이미 존재)";
    }
  }
  await callAdapter(client, adapter.update(item.objectName, source));
  const type = adapter.activationType ?? item.kind;
  return {
    action,
    activation: {
      name: item.objectName,
      type,
      ...(item.kind === "BDEF" ? { projection: /^\s*projection\b/i.test(source.replace(/\/\/.*$/gm, "")) } : {}),
    },
  };
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
      const objects = [...toActivate.values()];
      toActivate.clear();
      const errors = await activateBatch(client, objects);
      if (errors.length === 0) return true;
      failed.push({
        path: ABAP_MIRROR_ROOT,
        name: `활성화(${label})`,
        reason:
          `${objects.map((o) => o.name).join(", ")} — 소스는 서버에 비활성 버전으로 저장됐지만 ` +
          `활성화에 실패했습니다: ${errors.join(" / ")}`,
      });
      return false;
    };

    // 삭제 단계에서 비운 로컬 인클루드의 클래스 재활성화.
    if (!(await activate("삭제 후"))) return;

    for (const phase of ACTIVATION_PHASES) {
      for (const item of upserts.filter((p) => phase.includes(p.kind))) {
        try {
          const { action, activation } = await saveItem(client, item, { worktreeDir, packageName });
          toActivate.set(`${activation.type}:${activation.name}`, activation);
          applied.push({ path: item.path, name: item.objectName, action });
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

// ── 승인 전 서버 검사(리허설) ───────────────────────────────────────────────
// 소스만 보내 저장 없이 검사하는 MCP 도구는 기존 CDS 정도만 제대로 동작하고(2026-11-07 실측),
// 클래스 로컬 인클루드·BDEF·DDLX·SRVD는 저장해야만 검사된다. 그래서:
//  - 새 오브젝트: 승인과 같은 단계로 실제 생성·저장·활성화해 검사한다. 아직 아무도 쓰지 않는 오브젝트라
//    운영 동작에 영향이 없고, 반려하면 deleteRehearsalObjects로 지운다. 승인 시에는 "이미 존재"로 이어서 갱신된다.
//  - 기존 오브젝트 수정: 서버에 저장하지 않는다(비활성 버전도 남기지 않음). CDS만 저장 없이 검사하고
//    나머지는 "승인 시 검사"로 표시한다.
//  - 로컬 규칙 검사: 30자를 넘는 ABAP 식별자처럼 서버까지 가지 않아도 알 수 있는 오류.

export function rehearsalKey(kind, name) {
  return `${kind === "CLAS_LOCALS" ? "CLAS" : kind}:${name}`;
}

// 문자열·주석을 지운 뒤 30자를 넘는 식별자를 찾는다 (ABAP 이름 길이 제한).
export function findLongIdentifiers(source, limit = 30) {
  const stripped = String(source ?? "")
    .split(/\r?\n/)
    .map((line) => (/^\s*\*/.test(line) ? "" : line.replace(/"[^\n]*$/, "")))
    .join("\n")
    .replace(/'(?:[^'\n]|'')*'/g, "''")
    .replace(/`(?:[^`\n]|``)*`/g, "``")
    .replace(/\|(?:[^|\n\\]|\\.)*\|/g, "||");
  const found = new Map();
  stripped.split("\n").forEach((line, index) => {
    for (const match of line.matchAll(/[A-Za-z_%][A-Za-z0-9_]*/g)) {
      const word = match[0];
      // 인터페이스 접근(if_x~method)·구조 경로는 구성 요소별로 이미 분리된다. %로 시작하는 RAP 파생 이름은 제외.
      if (word.length > limit && !word.startsWith("%") && !found.has(word.toLowerCase())) {
        found.set(word.toLowerCase(), { name: word, line: index + 1 });
      }
    }
  });
  return [...found.values()];
}

const LINT_KINDS = new Set(["CLAS", "CLAS_LOCALS", "INTF"]);

export async function rehearseAbapChanges({ worktreeDir, changedFiles, packageName, rehearsalObjects = [] }) {
  const { deletes, upserts, failed } = planAbapChanges(changedFiles);
  const results = failed.map((f) => ({ path: f.path, name: f.name, kind: null, status: "error", message: f.reason }));
  const created = new Set(rehearsalObjects);
  const push = (item, status, message) =>
    results.push({ path: item.path, name: item.objectName, kind: item.kind, status, message });

  for (const item of deletes) push(item, "skipped", "삭제는 승인 시 반영됩니다.");

  // 로컬 규칙 검사 — 서버 검사와 별개로 항상 수행한다.
  const lintErrors = new Map();
  for (const item of upserts.filter((p) => LINT_KINDS.has(p.kind))) {
    const source = fs.readFileSync(path.join(worktreeDir, item.path), "utf8");
    const long = findLongIdentifiers(source);
    if (long.length > 0) {
      lintErrors.set(
        item.path,
        `30자를 넘는 이름: ${long.map((l) => `${l.name}(${l.name.length}자, ${l.line}행)`).join(", ")}`
      );
    }
  }

  await withAbapClient(async (client) => {
    // 어떤 파일이 "새 오브젝트"인지 판단한다. 이전 검사에서 만든 오브젝트도 새 오브젝트로 본다.
    const isNew = new Map();
    for (const item of upserts) {
      if (item.kind === "CLAS_LOCALS") continue;
      if (item.status !== "added" || !ADAPTERS[item.kind].create) {
        isNew.set(item.path, created.has(rehearsalKey(item.kind, item.objectName)));
        continue;
      }
      const existingPackage = await existingObjectPackage(client, item.kind, item.objectName);
      if (existingPackage && existingPackage.toUpperCase() !== String(packageName).toUpperCase()) {
        push(item, "error", `이미 다른 패키지(${existingPackage})에 있는 이름입니다. 공유 트라이얼에서는 다른 이름을 써야 합니다.`);
        isNew.set(item.path, false);
        continue;
      }
      isNew.set(item.path, !existingPackage || created.has(rehearsalKey(item.kind, item.objectName)));
    }
    for (const item of upserts.filter((p) => p.kind === "CLAS_LOCALS")) {
      const classItem = upserts.find((p) => p.kind === "CLAS" && p.objectName === item.objectName);
      isNew.set(item.path, classItem ? isNew.get(classItem.path) : created.has(rehearsalKey("CLAS", item.objectName)));
    }
    const handled = new Set(results.map((r) => r.path));

    // 기존 오브젝트 수정분: 저장하지 않는다.
    for (const item of upserts.filter((p) => !isNew.get(p.path) && !handled.has(p.path))) {
      if (item.kind === "DDLS") {
        try {
          const source = fs.readFileSync(path.join(worktreeDir, item.path), "utf8");
          const check = await callAbapToolRaw(client, "CheckDdl", { ddl_name: item.objectName, ddl_source: source });
          const errors = check?.check_result?.errors ?? [];
          if (errors.length > 0) push(item, "error", errors.map(describeActivationError).join(" / "));
          else if (check?.check_result?.status === "processed") push(item, "ok", "기존 CDS — 저장 없이 문법 검사 통과");
          else push(item, "skipped", "기존 CDS — 서버가 검사를 처리하지 못했습니다. 승인 시 검사됩니다.");
        } catch (err) {
          push(item, "error", String(err?.message ?? err).replace(/^CheckDdl 호출 실패: /, ""));
        }
      } else {
        push(item, "skipped", "기존 오브젝트 수정 — 서버에 저장하지 않으므로 승인 시 검사됩니다.");
      }
    }

    // 새 오브젝트: 승인과 같은 단계로 생성·저장·활성화한다.
    let stopped = null;
    for (const phase of ACTIVATION_PHASES) {
      const items = upserts.filter((p) => phase.includes(p.kind) && isNew.get(p.path) && !handled.has(p.path));
      if (items.length === 0) continue;
      if (stopped) {
        for (const item of items) push(item, "skipped", `앞 단계(${stopped}) 실패로 검사하지 못했습니다.`);
        continue;
      }
      const activations = new Map();
      const saved = [];
      for (const item of items) {
        try {
          const { action, activation } = await saveItem(client, item, { worktreeDir, packageName });
          if (action === "create") created.add(rehearsalKey(item.kind, item.objectName));
          activations.set(`${activation.type}:${activation.name}`, activation);
          saved.push(item);
        } catch (err) {
          push(item, "error", String(err?.message ?? err).replace(/^Update\w+ 호출 실패: /, ""));
          stopped = phase.join("·");
        }
      }
      const activationErrors = stopped ? [] : await activateBatch(client, [...activations.values()]);
      if (activationErrors.length > 0) stopped = phase.join("·");
      for (const item of saved) {
        if (activationErrors.length > 0) push(item, "error", `활성화 실패: ${activationErrors.join(" / ")}`);
        else if (stopped) push(item, "skipped", `같은 단계의 다른 오브젝트 저장 실패로 활성화하지 않았습니다.`);
        else push(item, "ok", "새 오브젝트 — 생성·활성화까지 통과");
      }
    }
  });

  // 로컬 규칙 오류는 서버 결과와 합친다 (서버가 통과해도 오류로 표시).
  for (const [itemPath, message] of lintErrors) {
    const result = results.find((r) => r.path === itemPath);
    if (result) {
      const serverMessage = result.status === "ok" ? "" : result.message;
      result.status = "error";
      result.message = serverMessage ? `${message} / ${serverMessage}` : message;
    }
  }

  return {
    results,
    created: [...created],
    ok: results.every((r) => r.status !== "error"),
    counts: {
      ok: results.filter((r) => r.status === "ok").length,
      error: results.filter((r) => r.status === "error").length,
      skipped: results.filter((r) => r.status === "skipped").length,
    },
  };
}

// 반려·정리 시 검사(리허설)에서 만든 새 오브젝트를 지운다. 의존 역순(서비스 → … → 테이블)으로 삭제한다.
export async function deleteRehearsalObjects({ objects }) {
  const items = objects
    .map((key) => {
      const [kind, ...rest] = key.split(":");
      return { kind, name: rest.join(":") };
    })
    .filter((item) => ADAPTERS[item.kind]?.del)
    .sort((a, b) => APPLY_ORDER.indexOf(b.kind) - APPLY_ORDER.indexOf(a.kind));
  const deleted = [];
  const failed = [];
  if (items.length === 0) return { deleted, failed };
  await withAbapClient(async (client) => {
    for (const item of items) {
      try {
        await callAdapter(client, ADAPTERS[item.kind].del(item.name));
        deleted.push(rehearsalKey(item.kind, item.name));
      } catch (err) {
        failed.push({ key: rehearsalKey(item.kind, item.name), reason: String(err?.message ?? err) });
      }
    }
  });
  return { deleted, failed };
}
