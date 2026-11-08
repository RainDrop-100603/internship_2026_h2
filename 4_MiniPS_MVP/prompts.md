# Mini PS MVP 1차 — 단계별 콘솔 프롬프트

> 범위·결정 사항: [README.md](README.md) · 설계 기준: [mini-ps-mockup.md](../working/mini-ps-mockup.md), [program_specs.md](../working/program_specs.md), [test_scenarios.md](../working/test_scenarios.md)
> 작성: 2026-11-07

## 사용 방법

- **한 프롬프트 = 콘솔 작업 1건.** 입력창 아래 **ABAP 모드를 반드시 켜고** 실행한다.
- 순서대로 진행한다. 앞 단계를 **승인하고 서버 반영을 확인한 다음** 다음 단계를 시작한다 (뒤 단계가 앞 단계 오브젝트를 참조한다).
- 콘솔 작업이 진행되는 동안에는 저장소 브랜치(`work/4-mini-ps-mvp`)에 다른 커밋을 만들지 않는다. 승인은 작업 시작 시점 커밋에서 fast-forward로만 반영된다.
- 작업 중에는 Eclipse에서 같은 오브젝트를 수정하지 않는다 (승인 시 덮어써짐). Eclipse에서는 조회·F8·F9·Preview만.
- **승인 전에 `서버 검사`를 누른다.** 새 오브젝트는 서버에 미리 만들어 핸들러까지 문법·활성화를 확인한다 (반려하면 콘솔이 삭제). 오류가 있으면 `서버 오류로 수정 요청` → 다시 검사 → 승인.
- **SRVB(Service Binding)는 파일로 만들 수 없다.** 각 BO 단계를 승인한 뒤 Claude Code 세션에 "SRVB 만들어줘"라고 요청해 MCP로 생성·게시한다.

## 진행 현황

| 단계 | 내용 | 상태 |
|---|---|---|
| 1-A | 코드 테이블 10개 + 초기 데이터 클래스 | ✅ 승인 (2026-11-07) |
| 1-B | Value Help CDS 10개 | ✅ 승인 (2026-11-07) |
| 2 | 고객사 BO (파이프라인 검증) | ✅ 승인 (2026-11-07) — SRVB 생성·Preview 확인 남음 |
| 2-B | 사원 BO | |
| 2-C | 자재 BO | |
| 2-D | 작업장 BO | |
| 3 | 프로젝트 BO (PRJ-01·02·03 수정) | |
| 4 | WBS (프로젝트 BO 하위 엔터티) | |
| 5 | Activity (WBS 하위 엔터티) | |
| 6 | 테스트 데이터 + 시나리오 점검 | |

## 공통 규칙 (모든 단계)

| 항목 | 규칙 |
|---|---|
| 이름 | 테이블 `ZPS_<약어>_YJ`(16자 이내), 루트/기본 뷰 `ZR_PS_<X>_YJ`, 프로젝션 `ZC_PS_<X>_YJ`, VH `ZI_PS_<X>_VH_YJ`, Behavior Pool `ZBP_R_PS_<X>_YJ`, 서비스 `ZUI_PS_<X>_YJ`, 바인딩 `ZUI_PS_<X>_O4_YJ` |
| ID 채번 (BR-17) | 내부 키는 UUID(`numbering : managed`). 화면용 ID는 저장 시 determination으로 채번 — 기준정보는 영문 1자 + 숫자 9자리(C/E/M/W), 업무 데이터는 영문 3자 + 숫자 7자리(PRJ/WBS/ACT). **최대값은 같은 접두어로 시작하는 ID만 대상으로 구한다** (6단계 테스트 데이터의 `T` 접두어 ID와 섞이지 않도록) |
| 참조 필드 | 다른 BO는 화면용 ID(char10)로 참조하고 VH로 선택 (BR-16) |
| 메시지 | `new_message_with_text`, `%element`로 필드 표시, draft는 `%state_area` 사용. 문구는 program_specs.md의 메시지 ID 그대로 |
| 상태 | 직접 입력 불가(readonly), 초기값은 determination으로 설정 (BR-02) |
| 채번 구현 | `SELECT MAX`로 같은 접두어 최대값 + 1, `|C{ n WIDTH = 9 ALIGN = RIGHT PAD = '0' }|` 형식. **번호 범위 객체(`cl_numberrange_runtime`) 금지** — 서버에 없고 콘솔 파일로 만들 수 없음. 동시 생성 중복은 Mock-up 범위에서 허용 (2단계에서 실제로 문제 발생) |
| draft BO | 루트·하위 엔터티 모두 `internal delete;`를 넣는다 (draft 엔터티는 delete가 최소 internal로 필요 — 활성화 경고). 프로젝션에는 `use delete`를 넣지 않아 화면에 삭제 버튼이 생기지 않게 한다 |
| 권한 핸들러 | `get_global_authorizations`의 result에는 BDEF에 사용자 operation으로 정의된 것(create, update, Edit 등)만 쓴다 (`%delete` 대입 금지 — 2단계 문법 오류) |
| 필드 라벨 | 테이블이 데이터 엘리먼트 없이 내장 타입이라 라벨이 없다. **화면에 보이는 모든 필드는 DDLX에 `@EndUserText.label`(한글)을 단다** (빠뜨리면 Fiori 입력 칸에 이름이 안 보임 — 2단계에서 실제 발생). 코드 필드는 이름이 보이도록 `@ObjectModel.text.element` + `@UI.textArrangement: #TEXT_FIRST`를 권장 |
| 승인 전 점검 | Codex 리뷰는 서버 문법 검사를 하지 않는다. 존재하지 않는 타입(예: `NUMC9`) 등은 승인 시에야 드러나므로 diff에서 직접 한 번 더 본다 |

---

## 1-A. 코드 테이블 + 초기 데이터 ✅

```text
Mini PS Mock-up 1단계-A: 코드 마스터 테이블과 초기 데이터 적재 클래스를 만들어줘.
설계 기준은 working/mini-ps-mockup.md의 "Code Master", "Project Profile Master" 절이다.

[공통 규칙]
- 모든 테이블은 abap/tabl/<소문자이름>.tabl.abap 파일로 만든다.
- 테이블 주석: @AbapCatalog.tableCategory #TRANSPARENT, deliveryClass #A, dataMaintenance #RESTRICTED, enhancement.category #NOT_EXTENSIBLE.
- 필드 타입은 데이터 엘리먼트 없이 abap.char(n) 같은 내장 타입을 쓴다.
- 첫 키는 client : abap.clnt not null.

[코드 테이블 9개] 구조는 모두 같다:
  key client, key code : abap.char(4) not null, name : abap.char(40), remark : abap.char(60)
- ZPS_PRJSTAT_YJ  (프로젝트 상태)     CRTD Created / REL Released / TECO Technically Completed / CLSD Closed
- ZPS_WBSSTAT_YJ  (WBS 상태)          CRTD / REL / TECO / CLSD (이름은 위와 같음)
- ZPS_ACTSTAT_YJ  (Activity 상태)     PLAN Planned / PROC In Progress / COMP Completed / HOLD On Hold
- ZPS_COUNTRY_YJ  (국가)              KR Korea / US United States / JP Japan
- ZPS_VSLTYPE_YJ  (선박 타입)         LNG LNG 운반선 / CON 컨테이너선 / TNK 유조선 / CRU 크루즈선
- ZPS_DEPT_YJ     (부서)              DSG 설계부 / PUR 구매부 / PPC 생산관리부 / HUL 선체가공부 / OUT 의장부 / PNT 도장부 / QAA 품질보증부
- ZPS_POSITION_YJ (직급)              PRO 프로 / SEN 선임 / LEAD 책임
- ZPS_MATCAT_YJ   (자재 분류)         STL 강재 / EQP 기자재 / OUT 의장품
- ZPS_PROCCAT_YJ  (공정 분류)         DSG 설계 / MAT 자재/조달 / FAB 가공 / ASM 조립 / ERE 탑재 / OUT 의장 / PNT 도장 / TST 검사/시험
- remark에는 mockup 문서의 "비고" 열 값을 넣는다.

[프로젝트 프로파일 테이블] ZPS_PRJPROF_YJ
  key client, key profile_code : abap.char(4) not null, profile_name : abap.char(40),
  description : abap.char(60), initial_status : abap.char(4), wbs_template : abap.char(10),
  vessel_type_required : abap_boolean
- 데이터: SHIP 신규 선박 건조 / REPR 기존 선박 수리 / CNVT 기존 선박 개조 / RND 기술·공법 연구개발 / FAC 생산 설비 구축 및 개선
- initial_status는 모두 CRTD. vessel_type_required는 SHIP·REPR·CNVT만 abap_true.
- wbs_template은 1차 MVP에서 템플릿을 쓰지 않으므로 모두 빈 값으로 둔다(2차 확장용 컬럼).

[초기 데이터 적재 클래스] ZCL_PS_SEED_CODES_YJ (abap/clas/zcl_ps_seed_codes_yj.clas.abap)
- if_oo_adt_classrun을 구현한다. main에서 위 10개 테이블을 DELETE FROM 후 INSERT 해서 여러 번 실행해도 결과가 같게 만든다.
- 테이블별 적재 건수를 out->write로 출력한다.
- ABAP Cloud 문법만 사용한다 (released API만, MODIFY/INSERT ... FROM TABLE @...).

[하지 말 것]
- CDS 뷰, BDEF, 서비스는 이번 작업에서 만들지 않는다 (다음 작업에서 만든다).
- 업무 테이블(프로젝트·WBS·Activity·사원 등)은 만들지 않는다.
- 상태 전이 테이블과 WBS 템플릿 테이블은 1차 범위 밖이라 만들지 않는다.
```

**승인 후**: Eclipse에서 `ZCL_PS_SEED_CODES_YJ` 실행(F9) → 테이블 F8로 값 확인.

## 1-B. Value Help CDS ✅

```text
Mini PS Mock-up 1단계-B: 1단계-A에서 만든 코드 테이블 10개(ZPS_PRJSTAT_YJ ~ ZPS_PRJPROF_YJ)마다
Value Help용 CDS view entity를 하나씩 만들어줘. 파일은 abap/ddls/<소문자이름>.ddls.abap.

- 이름 규칙: ZI_PS_<대상>_VH_YJ (30자 이내). 예: ZI_PS_PRJSTAT_VH_YJ, ZI_PS_VSLTYPE_VH_YJ, ZI_PS_PRJPROF_VH_YJ
- @AccessControl.authorizationCheck: #NOT_REQUIRED, @ObjectModel.resultSet.sizeCategory: #XS,
  @Search.searchable: true, @EndUserText.label은 한글 대상명
- 키 필드는 CamelCase 별칭(Code / ProfileCode), 이름 필드에는 @Semantics.text: true와 @Search.defaultSearchElement: true,
  키 필드에는 @ObjectModel.text.element로 이름 필드를 연결한다.
- 프로파일 VH는 InitialStatus, WbsTemplate, VesselTypeRequired 컬럼도 노출한다.
- 이 뷰들은 이후 프로젝트·Activity 화면에서 @Consumption.valueHelpDefinition으로 참조할 예정이다.
- 테이블·클래스는 수정하지 않는다.
```

**승인 후**: VH 뷰 F8로 코드·이름 확인. (만들어진 요소명: 코드 VH는 `Code`·`Name`·`Remark`, 프로파일 VH는 `ProfileCode`·`ProfileName`·…)

---

## 2. 고객사 BO (CUS-01) — 파이프라인 검증

이후 모든 BO의 **기준 패턴**이 되는 단계. 승인 후 Fiori 미리보기까지 확인되면 2-B~2-D는 이 결과물을 참고해 만든다.

```text
Mini PS Mock-up 2단계: 고객사(Customer) 기준정보 RAP BO를 테이블부터 Service Definition까지 만들어줘.
설계 기준: working/mini-ps-mockup.md "Customer Master", working/program_specs.md 3.6절(CUS-01), BR-16·BR-17.
1단계에서 만든 ZPS_COUNTRY_YJ와 ZI_PS_COUNTRY_VH_YJ를 참조한다(수정하지 않는다).

[1. 테이블]
- ZPS_CUSTOMER_YJ (abap/tabl/zps_customer_yj.tabl.abap)
  key client, key customer_uuid : sysuuid_x16 not null, customer_id : abap.char(10),
  customer_name : abap.char(80), country_code : abap.char(4), contact_person : abap.char(40), contact : abap.char(40),
  created_by : abp_creation_user, created_at : abp_creation_tstmpl,
  last_changed_by : abp_locinst_lastchange_user, local_last_changed_at : abp_locinst_lastchange_tstmpl,
  last_changed_at : abp_lastchange_tstmpl
- Draft 테이블 ZPS_CUST_D_YJ: 루트 뷰의 요소 별칭과 같은 필드 + "%admin" : include sych_bdl_draft_admin_inc

[2. CDS]
- ZR_PS_CUSTOMER_YJ: define root view entity, ZPS_CUSTOMER_YJ 기반, 필드는 CamelCase 별칭
  (CustomerUuid, CustomerId, CustomerName, CountryCode, ContactPerson, Contact, 관리 필드 5개).
  관리 필드에는 @Semantics.user.createdBy 등 표준 주석을 단다.
  association [0..1] to ZI_PS_COUNTRY_VH_YJ as _Country
- ZC_PS_CUSTOMER_YJ: provider contract transactional_query 프로젝션 뷰, @Metadata.allowExtensions: true,
  CountryCode에 @Consumption.valueHelpDefinition으로 ZI_PS_COUNTRY_VH_YJ 연결, _Country 노출

[3. Behavior]
- BDEF ZR_PS_CUSTOMER_YJ: managed implementation in class zbp_r_ps_customer_yj unique; strict ( 2 ); with draft;
  persistent table zps_customer_yj, draft table zps_cust_d_yj,
  etag master LocalLastChangedAt, lock master total etag LastChangedAt, authorization master ( global )
  - field ( numbering : managed, readonly ) CustomerUuid;
  - field ( readonly ) CustomerId 및 관리 필드 5개;  field ( mandatory ) CustomerName;
  - create; update;  (삭제는 기능정의서에 없으므로 만들지 않는다)
  - draft action Edit; draft action Activate optimized; draft action Discard; draft action Resume;
    draft determine action Prepare { validation validateName; validation validateCountry; }
  - determination setCustomerId on save { create; } — 기존 최대 CustomerId+1로 'C000000001' 형식 채번 (BR-17)
  - validation validateName on save { create; field CustomerName; } — 공백이면 CM-01 "필수 항목을 입력해주세요."
  - validation validateCountry on save { create; field CountryCode; } — 값이 있는데 ZPS_COUNTRY_YJ에 없으면 CM-02 "유효한 참조 코드를 선택해주세요."
  - 메시지는 new_message_with_text로 만들고 %element로 해당 필드를 표시, %state_area를 쓴다
  - mapping for zps_customer_yj corresponding { ... } 로 별칭↔컬럼을 모두 매핑
- Behavior Pool ZBP_R_PS_CUSTOMER_YJ: 메인 파일은 FOR BEHAVIOR OF zr_ps_customer_yj,
  핸들러(lhc_customer: get_global_authorizations, setCustomerId, validateName, validateCountry)는
  abap/clas/zbp_r_ps_customer_yj.clas.locals_imp.abap 에 작성
- 프로젝션 BDEF ZC_PS_CUSTOMER_YJ: projection; strict ( 2 ); use draft;
  use create; use update; use action Edit; use action Activate; use action Discard; use action Resume; use action Prepare;

[4. UI·서비스]
- Metadata Extension ZC_PS_CUSTOMER_YJ (@Metadata.layer: #CUSTOMER):
  headerInfo(고객사/고객사 목록, 제목 CustomerName), 목록 컬럼 CustomerId·CustomerName·CountryCode·ContactPerson·Contact,
  selectionField는 CustomerId·CustomerName (ID·이름 검색), Object Page facet 1개(기본 정보), UUID는 화면에서 숨김
- Service Definition ZUI_PS_CUSTOMER_YJ: expose ZC_PS_CUSTOMER_YJ as Customer; expose ZI_PS_COUNTRY_VH_YJ as Country;

[주의]
- Service Binding은 파일로 만들 수 없으니 만들지 말고, 결과 요약에 "SRVB ZUI_PS_CUSTOMER_O4_YJ (OData V4 - UI) 수동 생성 필요"라고 적어라.
- 사원·자재·작업장은 이번에 만들지 않는다.
```

**승인 후**
1. Claude Code에 "SRVB `ZUI_PS_CUSTOMER_O4_YJ` 만들어줘" → 생성·게시
2. Eclipse에서 SRVB 열기 → `Customer` 선택 → **Preview**
3. **TS-01**: 등록 → ID `C000000001` 자동 생성 → 이름 수정 → ID·이름으로 검색
4. **TS-02**: 이름 공백 / 없는 국가 코드로 저장 → 오류 표시·저장 안 됨
5. 문제가 있으면 다음 단계로 넘어가지 말고 고객사 BO부터 고친다 (2-B~2-D가 이 패턴을 복제하므로)

---

## 2-B. 사원 BO (EMP-01)

```text
Mini PS Mock-up 2-B단계: 사원(Employee) 기준정보 RAP BO를 만들어줘.
2단계 고객사 BO(abap/ 아래 zps_customer_yj, zps_cust_d_yj, zr_ps_customer_yj, zc_ps_customer_yj,
zbp_r_ps_customer_yj, zui_ps_customer_yj 파일)와 완전히 같은 구조·주석·draft 설정으로 만든다. 고객사 파일은 수정하지 않는다.
설계 기준: working/mini-ps-mockup.md "Employee Master", working/program_specs.md 3.6절(EMP-01), BR-16·BR-17.

[고객사와 다른 부분만]
- 테이블 ZPS_EMPLOYEE_YJ: employee_uuid(key), employee_id char(10), employee_name char(80),
  department_code char(4), position_code char(4), contact char(40) + 관리 필드 5개
- Draft 테이블 ZPS_EMP_D_YJ
- CDS ZR_PS_EMPLOYEE_YJ / ZC_PS_EMPLOYEE_YJ, 요소: EmployeeUuid, EmployeeId, EmployeeName, DepartmentCode, PositionCode, Contact
  - association [0..1] to ZI_PS_DEPT_VH_YJ as _Department, [0..1] to ZI_PS_POSITION_VH_YJ as _Position
  - 프로젝션에서 DepartmentCode·PositionCode에 각 VH 연결
- BDEF·Behavior Pool ZBP_R_PS_EMPLOYEE_YJ (draft 테이블 zps_emp_d_yj)
  - setEmployeeId: 'E000000001' 형식 채번 ('E'로 시작하는 ID 중 최대값+1)
  - validateName(CM-01), validateDepartment·validatePosition(값이 있는데 코드 테이블에 없으면 CM-02)
  - Prepare에 validation 3개 모두 등록
- Metadata Extension: 목록 EmployeeId·EmployeeName·DepartmentCode·PositionCode·Contact, 검색 EmployeeId·EmployeeName
- Service Definition ZUI_PS_EMPLOYEE_YJ: Employee + ZI_PS_DEPT_VH_YJ as Department + ZI_PS_POSITION_VH_YJ as Position

[추가: 다른 BO가 쓸 Value Help 뷰]
- ZI_PS_EMPLOYEE_VH_YJ: ZPS_EMPLOYEE_YJ 기반 view entity, key EmployeeId, EmployeeName(@Semantics.text, 검색), DepartmentCode, PositionCode.
  1-B의 VH 뷰들과 같은 주석 패턴. 프로젝트 PM·Activity 담당자 선택에 쓴다.
- ZI_PS_CUSTOMER_VH_YJ: ZPS_CUSTOMER_YJ 기반, key CustomerId, CustomerName(@Semantics.text, 검색), CountryCode. 프로젝트 발주처 선택에 쓴다.

[주의] SRVB는 만들지 말고 결과 요약에 "SRVB ZUI_PS_EMPLOYEE_O4_YJ 수동 생성 필요"라고 적어라.
```

**승인 후**: SRVB `ZUI_PS_EMPLOYEE_O4_YJ` 생성 요청 → Preview → TS-01·02(사원).

## 2-C. 자재 BO (MAT-01)

```text
Mini PS Mock-up 2-C단계: 자재(Material) 기준정보 RAP BO를 만들어줘.
2단계 고객사 BO와 완전히 같은 구조·주석·draft 설정으로 만든다. 기존 파일은 수정하지 않는다.
설계 기준: working/mini-ps-mockup.md "Material Master", working/program_specs.md 3.6절(MAT-01), BR-16·BR-17.

[고객사와 다른 부분만]
- 테이블 ZPS_MATERIAL_YJ: material_uuid(key), material_id char(10), material_name char(80), material_category_code char(4) + 관리 필드 5개
- Draft 테이블 ZPS_MAT_D_YJ
- CDS ZR_PS_MATERIAL_YJ / ZC_PS_MATERIAL_YJ, 요소: MaterialUuid, MaterialId, MaterialName, MaterialCategoryCode
  - association [0..1] to ZI_PS_MATCAT_VH_YJ as _Category, 프로젝션에서 VH 연결
- BDEF·Behavior Pool ZBP_R_PS_MATERIAL_YJ (draft 테이블 zps_mat_d_yj)
  - setMaterialId: 'M000000001' 형식 채번 ('M'로 시작하는 ID 중 최대값+1)
  - validateName(CM-01), validateCategory(값이 있는데 ZPS_MATCAT_YJ에 없으면 CM-02)
- Metadata Extension: 목록 MaterialId·MaterialName·MaterialCategoryCode, 검색 MaterialId·MaterialName
- Service Definition ZUI_PS_MATERIAL_YJ: Material + ZI_PS_MATCAT_VH_YJ as MaterialCategory
- 자재는 1차 범위에서 프로젝트·Activity와 연결하지 않으므로 VH 뷰는 만들지 않는다.

[주의] SRVB는 만들지 말고 결과 요약에 "SRVB ZUI_PS_MATERIAL_O4_YJ 수동 생성 필요"라고 적어라.
```

**승인 후**: SRVB `ZUI_PS_MATERIAL_O4_YJ` 생성 요청 → Preview → TS-01·02(자재).

## 2-D. 작업장 BO (WC-01)

```text
Mini PS Mock-up 2-D단계: 작업장(Work Center) 기준정보 RAP BO를 만들어줘.
2단계 고객사 BO와 완전히 같은 구조·주석·draft 설정으로 만든다. 기존 파일은 수정하지 않는다.
설계 기준: working/mini-ps-mockup.md "Work Center Master", working/program_specs.md 3.6절(WC-01), BR-16·BR-17.

[고객사와 다른 부분만]
- 테이블 ZPS_WRKCTR_YJ: work_center_uuid(key), work_center_id char(10), work_center_name char(80), process_category_code char(4) + 관리 필드 5개
- Draft 테이블 ZPS_WC_D_YJ
- CDS ZR_PS_WORKCENTER_YJ / ZC_PS_WORKCENTER_YJ, 요소: WorkCenterUuid, WorkCenterId, WorkCenterName, ProcessCategoryCode
  - association [0..1] to ZI_PS_PROCCAT_VH_YJ as _ProcessCategory, 프로젝션에서 VH 연결
- BDEF·Behavior Pool ZBP_R_PS_WORKCENTER_YJ (draft 테이블 zps_wc_d_yj)
  - setWorkCenterId: 'W000000001' 형식 채번 ('W'로 시작하는 ID 중 최대값+1)
  - validateName(CM-01), validateProcessCategory(값이 있는데 ZPS_PROCCAT_YJ에 없으면 CM-02)
- Metadata Extension: 목록 WorkCenterId·WorkCenterName·ProcessCategoryCode, 검색 WorkCenterId·WorkCenterName
- Service Definition ZUI_PS_WORKCENTER_YJ: WorkCenter + ZI_PS_PROCCAT_VH_YJ as ProcessCategory

[추가] ZI_PS_WRKCTR_VH_YJ: ZPS_WRKCTR_YJ 기반 VH 뷰, key WorkCenterId, WorkCenterName(@Semantics.text, 검색), ProcessCategoryCode.
1-B VH 패턴과 같게. Activity 작업장 선택에 쓴다.

[주의] SRVB는 만들지 말고 결과 요약에 "SRVB ZUI_PS_WORKCENTER_O4_YJ 수동 생성 필요"라고 적어라.
```

**승인 후**: SRVB `ZUI_PS_WORKCENTER_O4_YJ` 생성 요청 → Preview → TS-01·02(작업장). **여기까지가 PS-01 완료.**

---

## 3. 프로젝트 BO (PRJ-01·02·03 수정) — PS-02

WBS·Activity는 4·5단계에서 **이 BO의 하위 엔터티로 추가**한다 (같은 draft·lock 단위). 이번 단계는 루트만.

```text
Mini PS Mock-up 3단계: 프로젝트(Project) RAP BO의 루트 엔터티를 만들어줘. (WBS·Activity는 다음 단계에서 이 BO에 추가한다)
2단계 고객사 BO의 구조·주석·draft 패턴을 따른다. 기존 파일은 수정하지 않는다.
설계 기준: working/mini-ps-mockup.md "Project 속성정보", working/program_specs.md 3.1~3.3절(PRJ-01·02·03),
BR-02·BR-09·BR-14·BR-15·BR-16. 1차 MVP는 WBS 템플릿과 상태 변경(Release/TECO/종료)을 만들지 않는다.

[1. 테이블]
- ZPS_PROJECT_YJ: project_uuid(key, sysuuid_x16), project_id char(10), project_name char(80),
  profile_code char(4), vessel_type char(4), pm_employee_id char(10), customer_id char(10),
  contract_amount abap.dec(15,2), start_date abap.dats, end_date abap.dats, status char(4) + 관리 필드 5개
- Draft 테이블 ZPS_PRJ_D_YJ

[2. CDS]
- ZR_PS_PROJECT_YJ: define root view entity. 요소 ProjectUuid, ProjectId, ProjectName, ProfileCode, VesselType,
  PmEmployeeId, CustomerId, ContractAmount, StartDate, EndDate, Status + 관리 필드
  association [0..1] to ZI_PS_PRJPROF_VH_YJ as _Profile, ZI_PS_VSLTYPE_VH_YJ as _VesselType,
  ZI_PS_EMPLOYEE_VH_YJ as _Pm, ZI_PS_CUSTOMER_VH_YJ as _Customer, ZI_PS_PRJSTAT_VH_YJ as _Status
- ZC_PS_PROJECT_YJ: transactional_query 프로젝션. ProfileName·VesselTypeName·PmName·CustomerName·StatusName을
  association에서 꺼내 텍스트로 노출(@ObjectModel.text.element 연결). 각 코드 필드에 VH 연결.

[3. Behavior] ZR_PS_PROJECT_YJ (managed, strict(2), with draft, draft table zps_prj_d_yj, 고객사와 같은 etag/lock/authorization)
- field ( numbering : managed, readonly ) ProjectUuid;  field ( readonly ) ProjectId, Status, 관리 필드;
- field ( mandatory : create, readonly : update ) ProfileCode;   — 프로파일은 생성 후 수정 불가 (PRJ-03)
- field ( readonly : update ) VesselType;                         — 선박 타입도 생성 후 수정 불가
- field ( mandatory ) ProjectName, PmEmployeeId, CustomerId, StartDate, EndDate;
- create; update ( features : instance );  draft action ( features : instance ) Edit; 나머지 draft action은 고객사와 같게. 삭제 없음.
- determination setInitialStatus on modify { create; } — 선택한 프로파일의 initial_status로 Status 설정 (BR-02)
- determination setProjectId on save { create; } — 'PRJ0000001' 형식 채번 ('PRJ'로 시작하는 ID 중 최대값+1)
- validations (모두 on save, Prepare에 등록):
  - validateRequired: ProjectName·ProfileCode·PmEmployeeId·CustomerId·StartDate·EndDate 중 비면 CM-01, 비어 있는 필드마다 %element 표시
  - validateProfile: ZPS_PRJPROF_YJ에 없으면 CM-02
  - validateVesselType: 프로파일 vessel_type_required = abap_true인데 비어 있으면 PRJ02-M02 "선박 타입을 선택해주세요.",
    값이 있는데 ZPS_VSLTYPE_YJ에 없으면 CM-02 (BR-14 — RND·FAC는 비어도 통과)
  - validatePm / validateCustomer: ZPS_EMPLOYEE_YJ / ZPS_CUSTOMER_YJ에 없으면 CM-02
  - validateDates: StartDate > EndDate이면 CM-03 "시작일은 종료일보다 늦을 수 없습니다." (BR-15)
- get_instance_features: Status가 TECO·CLSD이면 update·Edit 비활성 (BR-09 — CRTD·REL만 수정 가능)
- Behavior Pool ZBP_R_PS_PROJECT_YJ (핸들러는 .clas.locals_imp.abap)
- 프로젝션 BDEF ZC_PS_PROJECT_YJ: use create; use update; use draft action 전부

[4. UI·서비스]
- Metadata Extension ZC_PS_PROJECT_YJ:
  - 목록(PRJ-01) 컬럼: ProjectId, ProjectName, ProfileCode(이름 표시), PmEmployeeId(이름 표시), StartDate, EndDate, Status(이름 표시)
  - selectionField: ProjectId, ProjectName, ProfileCode, Status, StartDate, EndDate (기간 검색)
  - Object Page: facet "기본 정보"(ProjectName, ProfileCode, VesselType, PmEmployeeId, CustomerId, ContractAmount, StartDate, EndDate),
    facet "상태"(Status, 관리 필드). UUID 숨김. 다음 단계에서 "WBS" facet을 추가할 자리를 남겨둔다.
- Service Definition ZUI_PS_PROJECT_YJ: Project + 참조 VH 5개(Profile, VesselType, Employee, Customer, ProjectStatus) expose

[하지 말 것]
- WBS·Activity 엔터티, composition, WBS 템플릿 적용 체크박스, Release/기술 완료/종료 액션은 만들지 않는다.
- SRVB는 만들지 말고 결과 요약에 "SRVB ZUI_PS_PROJECT_O4_YJ 수동 생성 필요"라고 적어라.
```

**승인 후**: SRVB `ZUI_PS_PROJECT_O4_YJ` 생성 요청 → Preview
- **TS-04**: 템플릿 없이 프로젝트 생성 → 상태 CRTD, ID `PRJ0000001`
- **TS-05**: 필수값 누락 / 없는 PM·발주처 / 시작일>종료일 → 차단. SHIP에서 선박 타입 비우면 차단, RND에서는 통과
- **TS-06**: ID·명·상태로 검색 → 상세 → 기본정보 수정 저장. 프로파일·선박 타입은 수정 불가

---

## 4. WBS (프로젝트 BO 하위 엔터티) — PS-03

```text
Mini PS Mock-up 4단계: 프로젝트 BO(ZR_PS_PROJECT_YJ)에 WBS 하위 엔터티를 추가해줘.
설계 기준: working/program_specs.md 3.4절(WBS-01), working/process_flows.md PS-03, BR-02·BR-09·BR-12.
기존 프로젝트 BO 파일(테이블·CDS·BDEF·Behavior Pool·DDLX·SRVD)을 수정해 composition으로 붙인다. 상태 변경(Release/TECO) 액션은 만들지 않는다.

[1. 테이블]
- ZPS_WBS_YJ: wbs_uuid(key), project_uuid sysuuid_x16, wbs_id char(10), wbs_name char(80),
  parent_wbs_id char(10), wbs_level abap.int2, status char(4), local_last_changed_at abp_locinst_lastchange_tstmpl
- Draft 테이블 ZPS_WBS_D_YJ

[2. CDS]
- ZR_PS_WBS_YJ: define view entity, association to parent ZR_PS_PROJECT_YJ as _Project on 프로젝트 UUID.
  요소 WbsUuid, ProjectUuid, WbsId, WbsName, ParentWbsId, WbsLevel, Status, LocalLastChangedAt.
  association [0..1] to ZI_PS_WBSSTAT_VH_YJ as _Status
- ZR_PS_PROJECT_YJ에 composition [0..*] of ZR_PS_WBS_YJ as _Wbs 추가
- ZC_PS_WBS_YJ: 프로젝션(redirected to parent ZC_PS_PROJECT_YJ), StatusName 텍스트, ParentWbsId에 아래 VH 연결
  (additionalBinding으로 같은 ProjectUuid의 WBS만 보이게)
- ZC_PS_PROJECT_YJ에 _Wbs : redirected to composition child ZC_PS_WBS_YJ 추가
- VH 뷰 ZI_PS_WBS_VH_YJ: ZPS_WBS_YJ 기반, key WbsUuid는 숨기고 WbsId, WbsName, WbsLevel, ProjectUuid 노출

[3. Behavior] (ZR_PS_PROJECT_YJ BDEF에 엔터티 추가)
- define behavior for ZR_PS_WBS_YJ alias Wbs, persistent table zps_wbs_yj, draft table zps_wbs_d_yj,
  lock dependent by _Project, authorization dependent by _Project, etag master LocalLastChangedAt
- 프로젝트 쪽: association _Wbs { create ( features : instance ); with draft; }
- field ( numbering : managed, readonly ) WbsUuid;  field ( readonly ) ProjectUuid, WbsId, WbsLevel, Status;
- field ( readonly : update ) ParentWbsId;   — 부모는 등록할 때만 지정, 이후 변경 불가 (BR-12, TS-08)
- field ( mandatory ) WbsName;  update ( features : instance );  삭제 없음
- determination setWbsDefaults on modify { create; field ParentWbsId; }:
  Status = 'CRTD'(BR-02), ParentWbsId가 비면 WbsLevel = 1, 있으면 같은 프로젝트 부모 WBS의 WbsLevel + 1
- determination setWbsId on save { create; } — 'WBS0000001' 형식 채번 ('WBS'로 시작하는 ID 중 최대값+1)
- validations (on save, 프로젝트 Prepare에도 등록):
  - validateWbsName: 공백이면 CM-01
  - validateParent: ParentWbsId가 있으면 같은 프로젝트의 WBS여야 함 → 아니면 WBS-M06 "같은 프로젝트의 상위 WBS를 선택해주세요."
    자기 자신이나 자손을 부모로 지정하면 WBS-M07 "자기 자신이나 하위 WBS를 부모로 선택할 수 없습니다."
  - validateWbsScope (BR-09): 프로젝트와 모든 상위 WBS(부모를 따라 루트까지)가 CRTD 또는 REL이어야 함.
    수정 시에는 대상 WBS 자신도 포함. 위반 시 WBS-M05 "완료 또는 종료된 범위는 변경할 수 없습니다."
- get_instance_features:
  - 프로젝트: Status가 TECO·CLSD면 _Wbs create 비활성
  - WBS: 자신·상위·프로젝트 중 TECO·CLSD가 있으면 update 비활성
- 핸들러는 ZBP_R_PS_PROJECT_YJ의 .clas.locals_imp.abap에 lhc_wbs로 추가
- 프로젝션 BDEF: define behavior for ZC_PS_WBS_YJ alias Wbs { use update; } 와 프로젝트의 use association _Wbs { create; with draft; }

[4. UI·서비스]
- ZC_PS_WBS_YJ Metadata Extension: 목록 WbsId, WbsName, WbsLevel, ParentWbsId, Status(이름) — 기본 정렬 WbsId.
  Object Page facet "WBS 정보". (다음 단계에서 "Activity" facet 추가)
- ZC_PS_PROJECT_YJ Metadata Extension에 "WBS" facet(#LINEITEM_REFERENCE, targetElement '_Wbs') 추가
- ZUI_PS_PROJECT_YJ에 ZC_PS_WBS_YJ as Wbs, ZI_PS_WBS_VH_YJ, ZI_PS_WBSSTAT_VH_YJ expose 추가

[제약 — 결과 요약에 적어라]
- Fiori Elements 하위 테이블은 트리가 아닌 평평한 목록이다. 계층은 WbsLevel·ParentWbsId로 표현한다.
- 부모 선택 VH는 저장된(active) WBS만 보여준다 → 하위 WBS는 부모를 먼저 저장한 뒤 등록한다.
- 새 엔터티가 생겼으므로 SRVB ZUI_PS_PROJECT_O4_YJ를 다시 게시(Publish)해야 할 수 있다.
```

**승인 후**: SRVB 재게시 확인 요청 → Preview
- **TS-07**: 빈 프로젝트에 최상위 WBS(Level 1) → 저장 → 편집 → 하위 WBS(Level 2) → 이름 수정
- **TS-08**: 다른 프로젝트 WBS를 부모로 / 저장된 WBS의 부모 변경 시도 → 차단 (부모 필드 수정 불가)
- **TS-09**: 6단계 테스트 데이터로 확인 (TECO 범위는 상태 변경 기능이 없어 데이터로 만든다)

---

## 5. Activity (WBS 하위 엔터티) — PS-04

```text
Mini PS Mock-up 5단계: 프로젝트 BO의 WBS 아래에 Activity 엔터티를 추가해줘.
설계 기준: working/program_specs.md 3.5절(ACT-01), working/process_flows.md PS-04, BR-02·BR-09·BR-10·BR-15·BR-16.
기존 프로젝트 BO 파일을 수정해 WBS의 composition 하위로 붙인다. 착수·보류·재개·완료 액션은 만들지 않는다.

[1. 테이블]
- ZPS_ACTIVITY_YJ: activity_uuid(key), wbs_uuid sysuuid_x16, project_uuid sysuuid_x16, activity_id char(10),
  activity_name char(80), work_center_id char(10), employee_id char(10), start_date abap.dats, end_date abap.dats,
  status char(4), local_last_changed_at abp_locinst_lastchange_tstmpl
- Draft 테이블 ZPS_ACT_D_YJ

[2. CDS]
- ZR_PS_ACTIVITY_YJ: association to parent ZR_PS_WBS_YJ as _Wbs, association [1..1] to ZR_PS_PROJECT_YJ as _Project.
  요소 ActivityUuid, WbsUuid, ProjectUuid, ActivityId, ActivityName, WorkCenterId, EmployeeId, StartDate, EndDate, Status, LocalLastChangedAt
  association [0..1] to ZI_PS_WRKCTR_VH_YJ as _WorkCenter, ZI_PS_EMPLOYEE_VH_YJ as _Employee, ZI_PS_ACTSTAT_VH_YJ as _Status
- ZR_PS_WBS_YJ에 composition [0..*] of ZR_PS_ACTIVITY_YJ as _Activity 추가
- ZC_PS_ACTIVITY_YJ: 프로젝션(redirected to parent ZC_PS_WBS_YJ, _Project는 redirected to ZC_PS_PROJECT_YJ).
  WorkCenterName·EmployeeName·StatusName 텍스트, 그리고 직속 WBS 상태를 _Wbs.Status as WbsStatus로 읽기 전용 노출 (BR-10, 저장하지 않음)
- ZC_PS_WBS_YJ에 _Activity : redirected to composition child ZC_PS_ACTIVITY_YJ 추가

[3. Behavior]
- define behavior for ZR_PS_ACTIVITY_YJ alias Activity, persistent table zps_activity_yj, draft table zps_act_d_yj,
  lock dependent by _Project, authorization dependent by _Project, etag master LocalLastChangedAt
- WBS 쪽: association _Activity { create ( features : instance ); with draft; },  Activity 쪽: association _Wbs { with draft; }, association _Project { with draft; }
- field ( numbering : managed, readonly ) ActivityUuid;  field ( readonly ) WbsUuid, ProjectUuid, ActivityId, Status;
- field ( mandatory ) ActivityName, WorkCenterId, EmployeeId;  update ( features : instance );  삭제 없음
- determination setActivityDefaults on modify { create; }: Status = 'PLAN'(BR-02), ProjectUuid = 소속 WBS의 ProjectUuid
- determination setActivityId on save { create; } — 'ACT0000001' 형식 채번 ('ACT'로 시작하는 ID 중 최대값+1)
- validations (on save, 프로젝트 Prepare에도 등록):
  - validateActivityRequired: ActivityName·WorkCenterId·EmployeeId 중 비면 CM-01
  - validateWorkCenter / validateEmployee: ZPS_WRKCTR_YJ / ZPS_EMPLOYEE_YJ에 없으면 CM-02
  - validateActivityDates: StartDate > EndDate이면 CM-03. 프로젝트 기간 밖 일정은 허용 (TS-11)
  - validateActivityScope (BR-09): 프로젝트, 직속 WBS, 그 WBS의 모든 상위 WBS가 CRTD 또는 REL이어야 함.
    위반 시 ACT-M04 "완료 또는 종료된 범위에는 Activity를 등록·수정할 수 없습니다."
- 하위 WBS가 있는 WBS에도 Activity를 등록할 수 있다 (말단 제한 없음, TS-10)
- get_instance_features: WBS 범위가 BR-09 위반이면 WBS의 _Activity create, Activity의 update 비활성
- 핸들러는 ZBP_R_PS_PROJECT_YJ의 .clas.locals_imp.abap에 lhc_activity로 추가
- 프로젝션 BDEF: ZC_PS_ACTIVITY_YJ { use update; use association _Wbs; use association _Project; },
  ZC_PS_WBS_YJ에 use association _Activity { create; with draft; }

[4. UI·서비스]
- ZC_PS_ACTIVITY_YJ Metadata Extension: 목록 ActivityId, ActivityName, WorkCenterId(이름), EmployeeId(이름), StartDate, EndDate,
  Status(이름), WbsStatus — 화면에 "PLAN · WBS CRTD"처럼 Activity 상태와 WBS 상태가 같이 보이게
- ZC_PS_WBS_YJ Metadata Extension에 "Activity" facet(#LINEITEM_REFERENCE, '_Activity') 추가
- ZUI_PS_PROJECT_YJ에 ZC_PS_ACTIVITY_YJ as Activity, ZI_PS_WRKCTR_VH_YJ, ZI_PS_ACTSTAT_VH_YJ expose 추가

[제약 — 결과 요약에 적어라]
- 새 엔터티가 생겼으므로 SRVB ZUI_PS_PROJECT_O4_YJ를 다시 게시해야 할 수 있다.
```

**승인 후**: SRVB 재게시 확인 요청 → Preview → 프로젝트 → WBS → Activity
- **TS-10**: CRTD WBS에 Activity 등록(상태 PLAN). 하위 WBS가 있는 WBS에도 등록 가능
- **TS-11**: 이름·작업장·담당자 누락, 없는 작업장·담당자, 시작일>종료일 → 차단. 프로젝트 기간 밖 일정은 저장됨

**여기까지가 1차 MVP 목표(PS-01~04, 템플릿 없음) 완료.**

---

## 6. 테스트 데이터 + 시나리오 점검

```text
Mini PS Mock-up 6단계: 1차 MVP 시나리오 테스트용 데이터 적재 클래스를 만들어줘.
기준: working/test_scenarios.md의 TS-01·02·04~11, 4_MiniPS_MVP/README.md 3.3절. 업무 BO 파일은 수정하지 않는다.

- ZCL_PS_SEED_TESTDATA_YJ (if_oo_adt_classrun): 여러 번 실행해도 결과가 같도록 'T'로 시작하는 테스트 데이터만 지우고 다시 넣는다.
  기존 사용자가 화면에서 만든 데이터(C/E/M/W, PRJ/WBS/ACT 접두어)는 건드리지 않는다.
  - ID는 모두 'T' 접두어: 기준정보 'T000000001'~, 프로젝트 'TPRJ000001'~, WBS 'TWBS000001'~, Activity 'TACT000001'~
  - 기준정보: 사원 3명, 고객사 2개, 작업장 3개, 자재 2개 (코드 값은 1단계 코드 테이블에 있는 값만)
  - 프로젝트 2개(TPRJ000001: SHIP·선박 타입 LNG, TPRJ000002: RND·선박 타입 없음), 모두 CRTD
  - TPRJ00001의 WBS: 최상위 2개(Level 1), 그 아래 하위 각 2개(Level 2), Level 3 1개
  - TS-09용: 최상위 WBS 하나를 status = 'TECO'로 직접 넣고 그 아래 CRTD 하위 WBS를 둔다 (상태 변경 기능이 없어 데이터로 준비)
  - Activity 몇 건(PLAN), 하위 WBS가 있는 WBS에도 1건
  - UUID는 cl_system_uuid로 생성, 관리 필드는 채운다
- 실행 결과로 테이블별 건수와 "TS-09 확인용: TECO WBS <ID> 아래 <ID>에서 등록·수정이 막혀야 함"을 out->write로 출력
- 각 BO의 채번 determination이 같은 접두어 ID만으로 최대값을 구하는지 확인하고, 아니라면(예: 'T' ID가 최대값으로 잡힘) 결과 요약에 '채번 수정 필요: <BO>'로 적어라 (이번 작업에서는 BO를 고치지 않는다)
```

**승인 후**: F9 실행 → Preview에서 아래 표를 차례로 확인하고 결과를 README에 기록.

| 시나리오 | 확인 방법 | 기대 결과 |
|---|---|---|
| TS-01 | 각 기준정보 화면 등록·수정·검색 | ID 자동 생성, 수정 저장, 검색 일치 |
| TS-02 | 이름 공백·잘못된 코드 | 오류, 저장 안 됨 |
| TS-04 | 프로젝트 생성 (템플릿 없음) | WBS 없이 CRTD 프로젝트 생성 |
| TS-05 | 필수값·참조·날짜·선박 타입 | 잘못된 입력 차단, RND는 선박 타입 없이 통과 |
| TS-06 | 검색 → 상세 → 수정 | 수정 저장, 프로파일·선박 타입 수정 불가 |
| TS-07 | 최상위·하위 WBS 등록 | Level 1 / 부모+1, CRTD |
| TS-08 | 잘못된 부모·부모 변경 | 차단 |
| TS-09 | TECO WBS 아래 등록·수정 | 차단 (WBS-M05 / ACT-M04), 다른 범위는 정상 |
| TS-10 | Activity 등록 | PLAN, 말단 제한 없음 |
| TS-11 | Activity 입력 오류 | 차단, 기간 밖 일정은 허용 |
| TS-27 일부 | 결과 0건 검색, 편집 중 취소 | "결과 없음" 표시, 취소 시 확인 |
