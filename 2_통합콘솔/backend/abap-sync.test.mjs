import test from "node:test";
import assert from "node:assert/strict";
import {
  behaviorPoolTarget,
  classifyAbapFile,
  isPlaceholderLocals,
  parseBdefHeader,
  planAbapChanges,
} from "./abapSync.mjs";

test("classifyAbapFile: 로컬 인클루드를 일반 클래스 파일보다 먼저 인식한다", () => {
  assert.deepEqual(classifyAbapFile("abap/clas/zbp_ps_project_yj.clas.locals_imp.abap"), {
    kind: "CLAS_LOCALS",
    objectName: "ZBP_PS_PROJECT_YJ",
  });
  assert.deepEqual(classifyAbapFile("abap/clas/zcl_hello_yj.clas.abap"), {
    kind: "CLAS",
    objectName: "ZCL_HELLO_YJ",
  });
  assert.deepEqual(classifyAbapFile("abap\\bdef\\zr_ps_project_yj.bdef.abap"), {
    kind: "BDEF",
    objectName: "ZR_PS_PROJECT_YJ",
  });
});

test("classifyAbapFile: 미지원 보조 파일은 kind=null, abap/ 밖은 null", () => {
  assert.equal(classifyAbapFile("abap/clas/zcl_x.clas.testclasses.abap").kind, null);
  assert.equal(classifyAbapFile("abap/srvb/zui_x.srvb.abap").kind, null);
  assert.equal(classifyAbapFile("README.md"), null);
  assert.equal(classifyAbapFile("abap/clas/nested/zcl_x.clas.abap"), null);
});

test("parseBdefHeader: 구현 타입과 루트 엔터티를 읽는다", () => {
  const source = [
    "// comment: managed",
    "managed implementation in class zbp_r_ps_project_yj unique;",
    "strict ( 2 );",
    "with draft;",
    "define behavior for ZR_PS_Project_YJ alias Project",
  ].join("\n");
  assert.deepEqual(parseBdefHeader(source), {
    implementationType: "Managed",
    rootEntity: "ZR_PS_PROJECT_YJ",
  });
  assert.equal(parseBdefHeader("projection;\ndefine behavior for ZC_X alias X").implementationType, "Projection");
  assert.throws(() => parseBdefHeader("strict ( 2 );"));
});

test("behaviorPoolTarget: FOR BEHAVIOR OF 대상만 추출한다", () => {
  assert.equal(
    behaviorPoolTarget("CLASS zbp_x DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_x."),
    "ZR_X"
  );
  assert.equal(behaviorPoolTarget("CLASS zcl_x DEFINITION PUBLIC FINAL CREATE PUBLIC."), null);
});

test("isPlaceholderLocals: 기본 주석만 있으면 true", () => {
  assert.equal(
    isPlaceholderLocals('*"* use this source file for the definition and implementation of\r\n*"* local helper classes\r\n'),
    true
  );
  assert.equal(isPlaceholderLocals("CLASS lhc_x DEFINITION INHERITING FROM cl_abap_behavior_handler."), false);
});

test("planAbapChanges: 의존 순서로 정렬하고 삭제는 역순으로 먼저", () => {
  const { deletes, upserts, failed } = planAbapChanges([
    { path: "abap/srvd/zui_x.srvd.abap", status: "added" },
    { path: "abap/clas/zbp_x.clas.locals_imp.abap", status: "added" },
    { path: "abap/clas/zbp_x.clas.abap", status: "added" },
    { path: "abap/bdef/zr_x.bdef.abap", status: "added" },
    { path: "abap/ddls/zr_x.ddls.abap", status: "added" },
    { path: "abap/tabl/zps_x.tabl.abap", status: "modified" },
    { path: "abap/ddlx/zc_old.ddlx.abap", status: "deleted" },
    { path: "abap/ddls/zc_old.ddls.abap", status: "deleted" },
    { path: "docs/notes.md", status: "modified" },
  ]);
  assert.deepEqual(failed, []);
  assert.deepEqual(
    upserts.map((p) => p.kind),
    ["TABL", "DDLS", "BDEF", "CLAS", "CLAS_LOCALS", "SRVD"]
  );
  assert.deepEqual(deletes.map((p) => p.kind), ["DDLX", "DDLS"]);
});

test("planAbapChanges: 클래스 삭제 시 로컬 인클루드 삭제는 생략", () => {
  const { deletes } = planAbapChanges([
    { path: "abap/clas/zbp_x.clas.abap", status: "deleted" },
    { path: "abap/clas/zbp_x.clas.locals_imp.abap", status: "deleted" },
  ]);
  assert.deepEqual(deletes.map((p) => p.kind), ["CLAS"]);
});

test("planAbapChanges: 미지원 파일·rename은 실패로 모은다", () => {
  const { failed } = planAbapChanges([
    { path: "abap/clas/zcl_x.clas.testclasses.abap", status: "added" },
    { path: "abap/clas/zcl_y.clas.abap", status: "renamed" },
  ]);
  assert.equal(failed.length, 2);
});
