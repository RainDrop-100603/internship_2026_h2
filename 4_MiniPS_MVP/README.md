# 4. Mini PS Mock-up MVP — 1차 (PS-01~04, 템플릿 없음)

> 브랜치: `work/4-mini-ps-mvp` · 시작: 2026-10-26
> 설계 기준 문서: [Mock-up 구체화](../working/mini-ps-mockup.md), [기능정의서](../working/program_specs.md), [프로세스 흐름도](../working/process_flows.md), [테스트 시나리오](../working/test_scenarios.md)

## 1. 목표

**WBS 템플릿 없이, 프로젝트 계획 단계(PS-04)까지 화면에서 동작하는 PS 모듈 Mock-up.**

- `process_flows.md`의 PS-01~08 중 **PS-01~PS-04만** 1차 범위로 한다.
- WBS Template은 쓰지 않는다. 템플릿 없는 상태로 정상 동작을 확인한 뒤 2차에서 템플릿을 적용한다.

## 2. 결정 사항 (2026-10-26)

| 항목 | 결정 | 이유 |
|---|---|---|
| UI | **RAP + Fiori Elements** | ABAP Cloud는 SAP GUI(Dynpro/ALV) 불가. 테이블 → CDS → Behavior → Service Binding으로 목록·생성·상세 화면 자동 생성 |
| 개발 경로 | **통합 콘솔 경유** (pull → 편집 → diff·Codex 리뷰 → 승인/apply) | 콘솔의 실사용 검증을 겸함. 단, 콘솔 어댑터 확장이 선행되어야 함 (4장 0단계) |
| 자재 마스터 | **포함** | PS-01 기준정보 등록 흐름을 문서 그대로 완성. 프로젝트·Activity와의 연결은 없음 |

## 3. 범위

### 3.1 기능 범위

| 프로세스 | 포함 | 제외 (2차 이후) |
|---|---|---|
| PS-01 기준정보 | 사원·고객사·자재·작업장 조회·등록·수정 (EMP-01, CUS-01, MAT-01, WC-01) | — |
| PS-02 프로젝트 | 목록 검색(PRJ-01), 생성(PRJ-02, 템플릿 체크박스 없음), 상세·기본정보 수정(PRJ-03 중 수정만) | Release·기술 완료·종료 버튼, 템플릿 적용(BR-13) |
| PS-03 WBS | 최상위·하위 등록, 이름 수정, Level 자동 계산, 다른 프로젝트 부모·순환·부모 변경 차단 (BR-12) | WBS Release·기술 완료 |
| PS-04 Activity | 수동 등록·수정 (초기 상태 PLAN 고정), 작업장·담당자 검증, 시작일 ≤ 종료일 | 착수·보류·재개·완료 |

**설계 원칙**
- **BR-09(TECO/CLSD 범위 변경 차단)는 1차에 구현한다.** 1차에는 상태 변경 기능이 없어 데이터가 CRTD뿐이지만, 2차에서 Release를 붙일 때 다시 고치지 않도록 미리 넣는다. TS-09는 테스트 데이터의 상태를 직접 TECO로 넣어 확인한다.
- **템플릿 확장 대비**: PROJECT_PROFILE에 WBS Template 컬럼은 만들어 두고 값은 비워 둔다 (2차에서 테이블 구조 변경 불필요).
- 상태 컬럼은 모두 만들되 직접 입력은 막는다 (BR-02).

### 3.2 테이블 (22개 중 17개)

이름 규칙: `ZPS_<약어>_YJ` (공유 시스템 전역 유일 제약 → 접미사 `_YJ`, 테이블명 16자 이내). 패키지 `ZPKG_YJ_1014`.

| 구분 | 원래 이름 | 오브젝트 이름(안) |
|---|---|---|
| 업무 | PROJECT / WBS / ACTIVITY | `ZPS_PROJECT_YJ` / `ZPS_WBS_YJ` / `ZPS_ACTIVITY_YJ` |
| 설정 | PROJECT_PROFILE | `ZPS_PRJPROF_YJ` |
| 마스터 | EMPLOYEE / CUSTOMER / MATERIAL / WORK_CENTER | `ZPS_EMPLOYEE_YJ` / `ZPS_CUSTOMER_YJ` / `ZPS_MATERIAL_YJ` / `ZPS_WRKCTR_YJ` |
| 코드 | PROJECT_STATUS / WBS_STATUS / ACTIVITY_STATUS | `ZPS_PRJSTAT_YJ` / `ZPS_WBSSTAT_YJ` / `ZPS_ACTSTAT_YJ` |
| 코드 | COUNTRY / VESSEL_TYPE / DEPARTMENT / POSITION / MATERIAL_CATEGORY / PROCESS_CATEGORY | `ZPS_COUNTRY_YJ` / `ZPS_VSLTYPE_YJ` / `ZPS_DEPT_YJ` / `ZPS_POSITION_YJ` / `ZPS_MATCAT_YJ` / `ZPS_PROCCAT_YJ` |

**1차 제외**: WBS_TEMPLATE, WBS_TEMPLATE_ITEM (템플릿), PROJECT/WBS/ACTIVITY_STATUS_TRANSITION (상태 전이 기능 없음). 이 밖에 RAP draft를 쓰면 draft 테이블이 BO별로 추가된다.

### 3.3 테스트 범위 (`test_scenarios.md` 기준)

| 포함 | 제외 |
|---|---|
| TS-01, 02 (기준정보) · TS-04(템플릿 미적용 생성만), 05, 06 (프로젝트) · TS-07, 08, 09 (WBS) · TS-10, 11 (Activity) · TS-27 일부 (결과 없음/오류 구분, 입력 취소) | TS-03 (템플릿), TS-12~26 (상태 변경·종료), TS-28·29 (일괄 변경 롤백·동시성) |

## 4. 진행 단계

각 단계는 통합 콘솔에서 `ABAP 모드 → Claude 구현 → diff·Codex 리뷰 → 승인(apply) → 서버 재조회·Fiori 미리보기로 확인` 순서로 처리한다.

| 단계 | 내용 | 완료 기준 |
|---|---|---|
| **0. 콘솔 확장** | RAP용 pull/apply 어댑터 추가: BDEF(Behavior Definition), SRVD(Service Definition), DDLX(Metadata Extension), 클래스 로컬 인클루드(Behavior 핸들러 코드가 들어가는 곳). DDLS/TABL Get 응답 필드명 실측 | 각 타입 오브젝트를 콘솔로 pull → 수정 → apply → 재조회로 확인 |
| **1. 코드 마스터** | 코드 테이블 9개 + 프로젝트 프로파일 + 초기 데이터 적재 클래스 + Value Help용 CDS | 적재 후 `GetTableContents`로 값 확인 |
| **2. 기준정보 (PS-01)** | 사원·고객사·자재·작업장 RAP BO 4개. **고객사 1개로 파이프라인(테이블 → CDS → BDEF → SRVD → SRVB → Fiori 미리보기)을 먼저 끝까지 검증**한 뒤 나머지 3개에 적용 | TS-01, TS-02 |
| **3. 프로젝트 (PS-02)** | 프로젝트 BO 루트: 목록·생성·상세 수정, 검증(필수값, 참조 존재, 선박 타입 조건부 필수, 시작일 ≤ 종료일) | TS-04, 05, 06 |
| **4. WBS (PS-03)** | 프로젝트의 하위 엔터티(composition). Level 자동 계산, 부모 검증, BR-09 | TS-07, 08, 09 |
| **5. Activity (PS-04)** | WBS의 하위 엔터티. PLAN 고정, 작업장·담당자 검증, 시작일 ≤ 종료일, BR-09 | TS-10, 11 |
| **6. 시나리오 테스트** | 3.3 범위 전체 실행, 결과·제한사항 기록 | 범위 내 시나리오 통과 |

## 5. 정해야 할 것 / 미리 알아둘 제약

- **ID 자동 생성(BR-17)**: 내부 키는 UUID, 화면용 ID(예: `P000001`)는 저장 시 determination으로 채번하는 방식을 제안 (1단계에서 확정).
- **Draft 사용 여부**: Fiori Elements 생성 화면은 managed + draft가 표준. draft 테이블이 추가로 생긴다 (2단계에서 확정).
- **WBS 트리 표시**: Fiori Elements의 하위 테이블은 기본적으로 평평한 목록. 1차는 Level·부모 WBS 컬럼으로 계층을 표현하고, 트리 화면은 제한사항으로 기록.
- **SRVB(Service Binding)**: 소스 기반이 아니라 콘솔 pull/apply 대상으로 맞지 않음. BO마다 1회 MCP로 직접 생성·게시하는 것을 예외로 둔다.
- **메시지(CM-01 등)**: 메시지 클래스(MSAG)로 관리. 콘솔 어댑터 미지원 → 0단계에 포함하거나 MCP로 직접 생성.
