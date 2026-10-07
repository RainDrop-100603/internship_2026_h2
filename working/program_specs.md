# Mini PS 기능정의서

### 공통 처리 및 예외 처리

- 성공 메시지는 실제 저장 완료 후 표시한다.
- 조회 오류와 조회 결과 없음은 구분한다.
- 저장 실패 시 기존 저장 데이터와 입력값을 유지하고 실패 원인을 안내한다.
- 여러 데이터를 생성·변경하는 기능은 전체 성공 또는 전체 취소로 처리한다 (BR-11).
- 마스터·코드 선택 필드는 자유 텍스트 대신 목록에서 선택한다 (BR-16).
- 입력 중 취소 시 변경 내용이 있으면 확인 팝업을 띄운다.

### 공통 메시지

| ID | 유형 | 문구 |
|---|---|---|
| CM-01 | 오류 | 필수 항목을 입력해주세요. |
| CM-02 | 오류 | 이미 사용 중인 ID입니다. |
| CM-03 | 오류 | 유효한 참조 코드를 선택해주세요. |
| CM-04 | 오류 | 시작일은 종료일보다 늦을 수 없습니다. |
| CM-05 | 오류 | 허용되지 않는 상태 변경입니다. |
| CM-06 | 오류 | 저장하지 못했습니다. 입력값을 확인해주세요. |
| CM-07 | 확인 | 변경 내용이 저장되지 않았습니다. 취소하시겠습니까? \[제안\] |
| CM-08 | 확인 | 하위 WBS n건도 함께 {Release/기술 완료}됩니다. 계속하시겠습니까? [확인] [취소] (BR-03) |

---

## 1. 기능 목록

| 구분 | 주요 기능 | 상세 기능 | 설명 | 프로그램 | 규칙 |
|---|---|---|---|---|---|
| 프로젝트 관리 | 프로젝트 조회 | 목록 검색 | 프로젝트 ID, 프로젝트명, 상태로 검색 | PRJ-01 | BR-15 |
| 프로젝트 관리 | 프로젝트 조회 | 상세 조회 | 선택 프로젝트의 기본정보와 현재 상태 조회 | PRJ-03 | |
| 프로젝트 관리 | 프로젝트 등록 | 프로파일 선택 | 초기 상태, WBS Template, 선박 타입 필수 여부 적용 | PRJ-02 | BR-02, BR-14 |
| 프로젝트 관리 | 프로젝트 등록 | 신규 생성 | 기본 정보를 검증하고 저장 | PRJ-02 | BR-13~16 |
| 프로젝트 관리 | 프로젝트 수정 | 기본 정보 변경 | 프로젝트명, 담당자, 일정 등 변경 | PRJ-03 | BR-09 |
| 프로젝트 관리 | 상태 관리 | Release | 프로젝트 CRTD → REL, 하위 CRTD WBS 자동 Release | PRJ-03 | BR-01, BR-03 |
| 프로젝트 관리 | 상태 관리 | 기술 완료 | 프로젝트 REL → TECO, 하위 REL WBS 자동 TECO, 미완료 Activity는 경고 | PRJ-03 | BR-03, BR-05, BR-06 |
| 프로젝트 관리 | 상태 관리 | 종료 | 담당자 확인 후 프로젝트·하위 WBS CLSD | PRJ-03 | BR-08 |
| WBS 관리 | 표준 구조 생성 | Template 적용 | 프로젝트 생성 시 적용 여부를 선택하면 프로파일 템플릿을 복사해 표준 구조 생성 | PRJ-02 | BR-13 |
| WBS 관리 | 구조 조회 | Tree 조회 | 프로젝트 WBS를 계층으로 표시 | WBS-01 | |
| WBS 관리 | 구조 편집 | 등록·수정 | 허용 범위 안에서 WBS 추가·수정, 초기 상태 CRTD | WBS-01 | BR-02, BR-09, BR-12 |
| WBS 관리 | 상태 관리 | 상태 조회 | Tree·상세에서 WBS Status Code·명칭 표시 | WBS-01 | |
| WBS 관리 | 상태 관리 | Release | 상위가 CRTD여도 선택 WBS CRTD → REL, 하위 CRTD WBS 자동 Release | WBS-01 | BR-03, BR-04 |
| WBS 관리 | 상태 관리 | 기술 완료 | 선택 WBS REL → TECO, 하위 REL WBS 자동 TECO, 미완료 Activity는 경고 | WBS-01 | BR-03, BR-05, BR-06 |
| WBS 관리 | 상태 관리 | 종료 | 개별 버튼 없음, 프로젝트 종료 시 함께 CLSD | PRJ-03 | BR-08 |
| Activity 관리 | 작업 조회 | WBS별 조회 | 선택 WBS의 Activity 조회 | ACT-01 | |
| Activity 관리 | 작업 등록 | 수동 등록 | PLAN으로 수동 등록 | ACT-01 | BR-02, BR-09 |
| Activity 관리 | 상태 관리 | 착수·보류·재개·완료 | PLAN→PROC, PROC↔HOLD, PROC→COMP | ACT-01 | BR-01, BR-07, BR-10 |
| 기준정보 관리 | 사원 관리 | 조회·등록·수정 | 프로젝트 PM과 Activity 담당자에 사용 | EMP-01 | BR-16, BR-17 |
| 기준정보 관리 | 고객사 관리 | 조회·등록·수정 | 프로젝트 발주처로 사용 | CUS-01 | BR-16, BR-17 |
| 기준정보 관리 | 자재 관리 | 조회·등록·수정 | 자재명과 자재 분류 관리 | MAT-01 | BR-16, BR-17 |
| 기준정보 관리 | 작업장 관리 | 조회·등록·수정 | Activity 작업장과 공정분류 관리 | WC-01 | BR-16, BR-17 |

### 1.1 프로세스 연계

| 프로세스 (흐름도) | 단계 | 프로그램 |
|---|---|---|
| PS-01 기준정보 등록 | 01-01~01-04 | EMP-01, CUS-01, MAT-01, WC-01 |
| PS-02 프로젝트 생성 | 02-01~02-07 | PRJ-01 → PRJ-02 |
| PS-03 WBS 구성 | 03-01~03-05 | WBS-01 |
| PS-04 Activity 계획 | 04-01~04-05 | WBS-01 → ACT-01 |
| PS-05 프로젝트·WBS Release | 05-01~05-05 | PRJ-03 (프로젝트 대상) / WBS-01 (WBS 대상) |
| PS-06 작업 실행 | 06-01~06-05 | ACT-01 |
| PS-07 기술 완료 | 07-01~07-08 | PRJ-03 (프로젝트 대상) / WBS-01 (WBS 대상) |
| PS-08 프로젝트 종료 | 08-01~08-05 | PRJ-03 |

---

## 2. 업무 규칙

### 2.1 상태 정의

| 대상 | 상태 | 제어 방식 |
|---|---|---|
| Project | CRTD → REL → TECO → CLSD | 프로젝트 전체의 실행 허용과 최종 종료 |
| WBS | CRTD → REL → TECO → CLSD | 업무 범위별 Release 및 수동 기술 완료 |
| Activity | PLAN → PROC → COMP, PROC ↔ HOLD | 작업 진행 상태(SAP의 확정 상태 PCNF·CNF에 해당). CRTD/REL/TECO/CLSD 같은 시스템 상태는 따로 저장하지 않고 직속 WBS 상태로 대신한다(BR-10) |

### 2.2 상태 제어

| BR | 규칙 |
|---|---|
| BR-01 | 상태 전이는 Transition 테이블에 정의된 것만 허용한다. Project·WBS는 CRTD→REL→TECO→CLSD, Activity는 PLAN→PROC, PROC→COMP, PROC→HOLD, HOLD→PROC. 역행·건너뛰기·COMP→PROC(완료 취소)는 없다. | 
| BR-02 | 초기 상태: Project는 프로파일의 Initial Status(현재 모두 CRTD), WBS는 수동·템플릿 생성 모두 CRTD, Activity는 PLAN. 상태는 직접 입력할 수 없다. | 
| BR-03 | 상태 전파: 프로젝트·WBS를 Release하거나 기술 완료하면 그 아래 WBS 중 전이 가능한 것(Release는 CRTD, 기술 완료는 REL)이 자동으로 함께 바뀐다. 하위 WBS가 있으면 변경 건수를 확인 팝업(CM-08)으로 보여준다. 상위 WBS·프로젝트 상태는 바꾸지 않고, Activity 상태도 바꾸지 않는다. | 
| BR-04 | Release는 대상(프로젝트 또는 WBS)이 CRTD이면 가능하다. 상위 WBS나 프로젝트가 아직 CRTD여도 먼저 착수할 하위 WBS만 개별 Release할 수 있다(부분 Release). 단, 프로젝트나 상위 WBS가 TECO·CLSD인 범위는 BR-09로 차단한다. WBS가 없어도 프로젝트를 Release할 수 있다. | 
| BR-05 | 기술 완료(TECO)는 담당자가 요청하며 대상이 REL일 때만 가능하다. 하위 REL WBS는 BR-03에 따라 함께 TECO가 되고, 하위 중 CRTD인 WBS는 그대로 두며 BR-09에 따라 잠긴다. 하위 WBS의 완료 순서 제약과 Activity 건수 조건은 없다. | 
| BR-06 | 기술 완료 대상 범위에 COMP가 아닌 Activity(PLAN·PROC·HOLD)가 있으면 차단하지 않고 경고 팝업으로 목록을 보여준다. 담당자가 확인하면 그대로 TECO 처리한다. 남은 Activity는 상태를 유지하며, TECO 이후에는 PROC Activity의 완료(PROC→COMP)만 허용하고 착수·보류·재개는 BR-10에 따라 차단한다. |
| BR-07 | Activity가 모두 완료되어도 WBS·프로젝트는 자동으로 TECO가 되지 않는다. Activity 완료는 해당 Activity만 COMP로 변경한다. | 
| BR-08 | 프로젝트 종료(CLSD)는 TECO 상태에서만 허용한다. 담당자 확인 후 프로젝트·모든 WBS를 함께 CLSD로 저장하며 전체 성공 또는 전체 취소로 처리한다. | 
| BR-09 | 프로젝트·해당 WBS·모든 상위 WBS가 CRTD 또는 REL인 범위에서만 WBS·Activity를 등록·수정한다. TECO/CLSD 범위는 WBS·Activity 등록·수정을 차단한다. Activity 상태 변경은 BR-10을 따른다(TECO 범위에서는 완료만 가능). 프로젝트 TECO 이후에는 조회, 진행 중 Activity 완료, 최종 종료만, CLSD 이후에는 조회만 허용한다. | 
| BR-10 | Activity 상태 변경은 직속(소속) WBS 상태만 검사한다. 착수(PLAN→PROC)·보류(PROC→HOLD)·재개(HOLD→PROC)는 직속 WBS가 REL일 때, 완료(PROC→COMP)는 직속 WBS가 REL 또는 TECO일 때 가능하고, CLSD이면 모두 차단한다. | 
| BR-11 | 저장 시 최신 상태와 하위 데이터를 재검증한다(오래된 화면의 잘못된 전이 방지). Release·기술 완료로 하위를 일괄 변경하는 동안 같은 범위의 WBS·Activity 등록·수정이 끼어들지 않도록 잠금 또는 동등한 동시성 제어로 보호한다. 여러 건 저장은 전체 성공 또는 전체 취소. | 

### 2.3 상태 전이 매트릭스
| 객체 | 전이 | 자기 상태 | 상위 조건 | 하위 조건 | 자동 전파 | 규칙 |
|---|---|---|---|---|---|---|
| Project | CRTD → REL | CRTD | - | 없음 (WBS 0건도 가능) | 하위 CRTD WBS → REL | BR-03, BR-04 |
| Project | REL → TECO | REL | - | 없음. 미완료 Activity는 경고 | 하위 REL WBS → TECO (CRTD WBS는 유지·잠금) | BR-03, BR-05, BR-06 |
| Project | TECO → CLSD | TECO | - | 없음 | 모든 WBS → CLSD | BR-08 |
| WBS | CRTD → REL | CRTD | 프로젝트·상위 WBS가 TECO·CLSD 아님 | 없음 | 하위 CRTD WBS → REL | BR-03, BR-04, BR-09 |
| WBS | REL → TECO | REL | 없음 | 없음. 미완료 Activity는 경고 | 하위 REL WBS → TECO | BR-03, BR-05, BR-06 |
| WBS | TECO → CLSD | - | - | - | 개별 종료 없음, 프로젝트 종료 시 함께 | BR-08 |
| Activity | PLAN → PROC | PLAN | 직속 WBS = REL | - | 없음 | BR-01, BR-10 |
| Activity | PROC → HOLD | PROC | 직속 WBS = REL | - | 없음 | BR-01, BR-10 |
| Activity | HOLD → PROC | HOLD | 직속 WBS = REL | - | 없음 | BR-01, BR-10 |
| Activity | PROC → COMP | PROC | 직속 WBS ∈ {REL, TECO} (CLSD 금지) | - | 없음 | BR-01, BR-06, BR-10 |

### 2.4 구조·템플릿

| BR | 규칙 |
|---|---|
| BR-12 | WBS 계층은 Parent WBS ID 자기참조로 표현한다(sort_order 제외). 루트 WBS는 Parent WBS ID를 비우고 Level=1, 자식은 부모 Level+1로 자동 계산한다. 부모는 같은 프로젝트의 WBS여야 하며 자기 자신이나 하위 WBS를 부모로 지정할 수 없다(순환 금지). 부모 변경을 제공할 경우 기존·대상 계층 모두 BR-09를 검사한다. |
| BR-13 | 템플릿 적용은 프로젝트 생성(PRJ-02) 시 사용자가 적용 여부를 선택하며, 프로파일에 Template이 있으면 기본 선택, 없으면 선택 불가다. 적용 시 프로파일의 WBS Template을 복사하고 프로젝트 저장과 한 번에 처리한다. 항목별 새 WBS ID를 만들고 부모 ID를 새 ID로 매핑하며 프로젝트 ID를 설정한다. WBS만 생성하고 Activity는 생성하지 않는다. 이후 템플릿 변경은 기존 WBS에 반영하지 않는다.  |

### 2.5 입력 검증

| BR | 규칙 |
|---|---|
| BR-14 | Vessel Type Required=Y인 프로파일(SHIP/REPR/CNVT)은 선박 타입 필수, RND/FAC는 선택. |
| BR-15 | 시작일 ≤ 종료일 (프로젝트 일정, Activity 일정, 목록 날짜 검색 범위). |
| BR-16 | 참조 필드(PM, 발주처, 선박 타입, 작업장, 담당자, 각종 코드)는 해당 마스터·코드 목록에서 선택하고 존재 여부를 검증한다. | 
| BR-17 | 기준정보 ID는 유일해야 하고 이름은 필수다. | 

---

## 3. 화면별 정의

| 프로그램 ID | 이름 |
|---|---|
| PRJ-01 | 프로젝트 목록 |
| PRJ-02 | 프로젝트 생성 |
| PRJ-03 | 프로젝트 상세 및 상태 변경 |
| WBS-01 | WBS Tree 관리 |
| ACT-01 | Activity 관리 |
| EMP-01 / CUS-01 / MAT-01 / WC-01 | 기준정보 관리 (공통 패턴) | 6

### 3.1 PRJ-01 프로젝트 목록

| 속성 | 내용 |
|---|---|
| 목적 | 프로젝트를 검색하고 생성·상세 화면으로 이동한다 |
| 관련 프로세스 | PS-02 시작점, 상세 화면 진입 |
| 관련 데이터 | PROJECT, PROJECT_PROFILE, EMPLOYEE, PROJECT_STATUS |
| 적용 규칙 | BR-15, BR-16 |

**항목**

| 항목 | 용도 | 처리 |
|---|---|---|
| 프로젝트 ID·명 | 검색 조건 | 부분 검색 |
| 프로파일·상태 | 검색 조건 | 각 마스터에서 선택 |
| 프로젝트 ID·명, 프로파일, PM, 시작·종료일, 상태 | 목록 컬럼 |  |

**버튼 및 팝업**

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 조회 | 항상 | 검색 조건에 맞는 목록 조회 | - | 결과 없음 PRJ01-M01 / 오류 PRJ01-M02, PRJ01-M03 |
| 초기화 | 항상 | 검색 조건을 기본값으로 복원 | - | - |
| 생성 | 항상 | PRJ-02 이동 | - | - |
| 상세 | 목록에서 1건 선택 | PRJ-03 이동 | - | - |

**메시지**: PRJ01-M01 조회 결과가 없습니다. / PRJ01-M02 날짜 검색 범위를 확인해주세요. / PRJ01-M03 조회하지 못했습니다. 다시 시도해주세요.

### 3.2 PRJ-02 프로젝트 생성

| 속성 | 내용 |
|---|---|
| 목적 | 프로파일과 기본정보를 입력해 프로젝트를 생성한다 |
| 관련 프로세스 | PS-02 (02-01~02-07) |
| 관련 데이터 | PROJECT, PROJECT_PROFILE, VESSEL_TYPE, EMPLOYEE, CUSTOMER, WBS_TEMPLATE, WBS_TEMPLATE_ITEM, WBS |
| 적용 규칙 | BR-02, BR-11, BR-13, BR-14, BR-15, BR-16 |

**항목**

| 항목 | 형식 | 필수·처리 |
|---|---|---|
| 프로젝트 ID | 고유 식별자 | 자동 생성 |
| 프로젝트명·프로파일 | 입력·선택 | 필수 |
| 선박 타입 | VESSEL_TYPE 선택 | Vessel Type Required=Y인 경우 필수 |
| PM·발주처 | EMPLOYEE·CUSTOMER 선택 | 필수 |
| 시작일·종료일 | 날짜 | 필수, BR-15 |
| 초기 상태·기본 템플릿 | 읽기 전용 | 선택 프로파일에서 가져옴 |
| WBS Template 적용 | 체크박스 |  |

**버튼 및 팝업**

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 프로파일 선택 | 항상 | 선박 타입 필수 여부·초기 상태·템플릿 표시와 Template 적용 체크박스 상태 갱신 | 프로파일 선택 목록 | - |
| 기준정보 선택 | 항상 | PM·고객사·선박 타입 선택 | 마스터 선택 목록(Value Help) | - |
| 저장 | 입력 중 | 검증 후 프로젝트 생성. Template 적용을 선택했으면 WBS를 함께 생성하고 한 단위로 저장 | - | PRJ02-M01 / PRJ02-M02, CM-04, PRJ02-M03, CM-06 |
| 취소 | 항상 | PRJ-01 복귀 | 변경 입력이 있으면 CM-07 확인 | - |

**메시지**: PRJ02-M01 프로젝트가 생성되었습니다. / PRJ02-M02 선박 타입을 선택해주세요. / PRJ02-M03 기본 WBS 템플릿이 준비되지 않았습니다.

### 3.3 PRJ-03 프로젝트 상세 및 상태 변경

| 속성 | 내용 |
|---|---|
| 목적 | 프로젝트 기본정보를 조회·수정하고 허용된 상태로 변경한다 |
| 관련 프로세스 | PS-05 (05-01~05-05, 프로젝트 대상), PS-07 (07-01~07-08, 프로젝트 대상), PS-08 (08-01~08-05) |
| 관련 데이터 | PROJECT, PROJECT_PROFILE, PROJECT_STATUS, PROJECT_STATUS_TRANSITION, WBS, ACTIVITY |
| 적용 규칙 | BR-01, BR-03, BR-05, BR-06, BR-08, BR-09, BR-11 |

**항목**

| 항목 | 형식 | 처리 |
|---|---|---|
| 프로젝트 기본정보 | 조회·수정 | PRJ-02 항목과 동일. \[미정\] CRTD·REL에서 수정 가능한 항목 |
| 현재 상태 | 읽기 전용 | 직접 입력 금지 |

**버튼 및 팝업**

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 수정 | 상태 CRTD·REL (BR-09) | 편집 모드 전환 | - | - |
| 저장 | 편집 모드 | 입력 검증 후 기본정보 저장 | - | PRJ03-M01 / CM-01, CM-04, CM-06 |
| Release | 상태 CRTD | 프로젝트와 하위 CRTD WBS → REL (BR-03, BR-04) | 하위 WBS가 있으면 확인 팝업(CM-08) | PRJ03-M02 / CM-05, PRJ03-M03 |
| 기술 완료 | 상태 REL | 프로젝트와 하위 REL WBS → TECO (BR-03, BR-05) | 하위 WBS가 있으면 확인 팝업(CM-08) → 미완료 Activity가 있으면 경고 팝업(계속/취소) (BR-06) | PRJ03-M02 / CM-05 |
| 종료 | 상태 TECO | BR-08: 프로젝트·하위 WBS 함께 CLSD | 확인: 종료 후 조회만 가능함을 안내 | PRJ03-M02 / CM-05, PRJ03-M03 |
| WBS 관리 | 항상 | 해당 프로젝트의 WBS-01 이동 | - | - |
| 목록 | 항상 | PRJ-01 복귀 | - | - |

**처리**
- 상태 버튼은 저장 시점에 최신 상태를 다시 검증한다(BR-11). 다른 사용자가 먼저 바꾼 경우 PRJ03-M03.
- 프로젝트 TECO 이후 등록·수정은 차단하고 진행 중 Activity 완료만 허용, CLSD 이후 조회만(BR-09, BR-10).

**메시지**: PRJ03-M01 프로젝트 정보가 저장되었습니다. / PRJ03-M02 상태가 변경되었습니다. / PRJ03-M03 프로젝트 상태가 변경되었습니다. 새로 조회해주세요. / PRJ03-M04 완료되지 않은 Activity가 n건 있습니다. 기술 완료하면 진행 중인 작업의 완료만 가능하고 착수·재개는 할 수 없습니다. 계속하시겠습니까? (경고)

### 3.4 WBS-01 WBS Tree 관리

| 속성 | 내용 |
|---|---|
| 목적 | 프로젝트 업무 범위를 계층 구조로 조회·등록·수정하고 WBS 상태를 수동 변경한다 |
| 관련 프로세스 | PS-03 (03-01~03-05), PS-05 (05-01~05-05, WBS 대상), PS-07 (07-01~07-08, WBS 대상) |
| 관련 데이터 | PROJECT, WBS, WBS_STATUS, WBS_STATUS_TRANSITION, WBS_TEMPLATE, WBS_TEMPLATE_ITEM, ACTIVITY |
| 적용 규칙 | BR-01, BR-02, BR-04, BR-05, BR-06, BR-07, BR-09, BR-11, BR-12, BR-13 |

**항목**

| 항목 | 형식 | 처리 |
|---|---|---|
| 프로젝트 | 컨텍스트 | 선택 프로젝트 고정 |
| WBS ID·이름 | 표시·입력 | 이름 필수,  고유 ID 생성 |
| 부모 WBS | 선택·표시 | 같은 프로젝트 노드에서 선택 (BR-12) |
| WBS Level | 읽기 전용 | 부모 Level+1 자동 계산 (BR-12) |
| WBS Status Code | 읽기 전용 | 코드와 명칭 표시, 생성 시 CRTD (BR-02) |

**버튼 및 팝업**

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 조회 | 항상 | 프로젝트 WBS 트리 조회 | - | - |
| 하위 등록 | 선택 노드가 BR-09 범위 | 선택 WBS 아래 새 노드 입력 | 입력 팝업 | WBS-M01 / WBS-M06, WBS-M07, WBS-M08 |
| 수정·저장 | 선택 노드가 BR-09 범위 | 이름 등 허용 항목 저장 | - | WBS-M01 / WBS-M06 |
| WBS Release | 선택 WBS CRTD | 선택 WBS와 하위 CRTD WBS → REL. 상위가 CRTD여도 가능 (BR-03, BR-04) | 하위 WBS가 있으면 확인 팝업(CM-08) | WBS-M02 / WBS-M03 |
| WBS 기술 완료 | 선택 WBS REL | 선택 WBS와 하위 REL WBS → TECO (BR-03, BR-05) | 하위 WBS가 있으면 확인 팝업(CM-08) → 미완료 Activity가 있으면 경고 팝업(계속/취소) (BR-06) | WBS-M02 / CM-05 |
| Activity 관리 | 노드 선택 | 선택 WBS의 ACT-01 이동 | - | - |

**메시지**: WBS-M01 WBS가 저장되었습니다. / WBS-M02 WBS 상태가 변경되었습니다. / WBS-M03 완료 또는 종료된 범위의 WBS는 Release할 수 없습니다. / WBS-M04 완료되지 않은 Activity가 n건 있습니다. 기술 완료하면 진행 중인 작업의 완료만 가능하고 착수·재개는 할 수 없습니다. 계속하시겠습니까? (경고) / WBS-M06 완료 또는 종료된 범위는 변경할 수 없습니다. / WBS-M07 같은 프로젝트의 상위 WBS를 선택해주세요. / WBS-M08 자기 자신이나 하위 WBS를 부모로 선택할 수 없습니다.

### 3.5 ACT-01 Activity 관리

| 속성 | 내용 |
|---|---|
| 목적 | WBS의 실제 작업을 수동 등록하고 일정·담당자·상태를 관리한다 |
| 관련 프로세스 | PS-04 (04-01~04-05), PS-06 (06-01~06-05) |
| 관련 데이터 | WBS, ACTIVITY, WORK_CENTER, EMPLOYEE, ACTIVITY_STATUS, ACTIVITY_STATUS_TRANSITION, PROJECT |
| 적용 규칙 | BR-01, BR-02, BR-07, BR-09, BR-10, BR-11, BR-15, BR-16 |

**항목**

| 항목 | 형식 | 처리 |
|---|---|---|
| WBS ID | 컨텍스트 |  |
| Activity ID·명 | 입력·표시 | 이름 필수, 고유 ID 생성 |
| 작업장·담당자 | 마스터 선택 | 필수 |
| 시작일·종료일 | 날짜 | BR-15 |
| 현재 상태 | 읽기 전용 | 신규 등록 시 PLAN (BR-02) |
| WBS 상태 | 읽기 전용 (표시만) | 직속 WBS의 상태(CRTD/REL/TECO/CLSD)를 함께 표시. 예: `PROC · WBS TECO`. Activity 테이블에 저장하지 않고 조회 시 WBS에서 가져옴 (BR-10) |

**버튼 및 팝업**

상태 변경은 상태별 버튼으로 분리한다 \[제안\]. (원본은 "상태 변경" 버튼 하나)

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 등록 | WBS가 BR-09 범위 | 작업 입력 화면 표시 | - | - |
| 저장 | 입력 중, BR-09 범위 | 검증 후 등록·수정 | - | ACT-M01 / CM-01, CM-03, CM-04 |
| 작업장·담당자 선택 | 입력 중 | 마스터 선택 목록 표시 | Value Help | - |
| 착수 | 상태 PLAN | BR-10 검증 후 PLAN → PROC | - | ACT-M02 / ACT-M03, CM-05 |
| 보류 | 상태 PROC | BR-10 검증 후 PROC → HOLD | - | ACT-M02 / ACT-M03 |
| 재개 | 상태 HOLD | BR-10 검증 후 HOLD → PROC | - | ACT-M02 / ACT-M03 |
| 완료 | 상태 PROC, 직속 WBS REL·TECO | BR-10 검증 후 PROC → COMP. 완료 후 취소 불가(BR-01) | 확인 팝업 | ACT-M02 / ACT-M03 |

**메시지**: ACT-M01 Activity가 저장되었습니다. / ACT-M02 Activity 상태가 변경되었습니다. / ACT-M03 소속 WBS 상태({상태})에서는 이 작업 상태로 변경할 수 없습니다.


### 3.6 기준정보 관리 (EMP-01 / CUS-01 / MAT-01 / WC-01)

네 화면은 같은 패턴(검색 → 목록 → 등록·수정)이므로 공통으로 정의하고, 화면별로 다른 부분만 표로 적는다.

| 속성 | 내용 |
|---|---|
| 목적 | 기준정보를 ID·이름으로 조회하고 등록·수정한다 |
| 관련 프로세스 | PS-01 (01-01~01-04) |
| 적용 규칙 | BR-16, BR-17 |

**화면별 차이**

| 프로그램 | 대상 | 관련 데이터 | 항목 (ID·이름 외) | 사용처 |
|---|---|---|---|---|
| EMP-01 | 사원 | EMPLOYEE, DEPARTMENT, POSITION | Department Code·Position Code(코드 선택), Contact | 프로젝트 PM, Activity 담당자 |
| CUS-01 | 고객사 | CUSTOMER, COUNTRY | Country Code(코드 선택), Contact Person·Contact | 프로젝트 발주처 |
| MAT-01 | 자재 | MATERIAL, MATERIAL_CATEGORY | Material Category Code(코드 선택) | 현재 프로젝트·Activity 연결 없음 |
| WC-01 | 작업장 | WORK_CENTER, PROCESS_CATEGORY | Process Category Code(코드 선택) | Activity 작업장 |

공통 항목: ID, 이름

**버튼 및 팝업 (공통)**

| 버튼 | 활성 조건 | 동작 | 팝업 | 메시지 |
|---|---|---|---|---|
| 조회 | 항상 | ID·이름 조건 검색 | - | - |
| 등록 | 항상 | 신규 입력 | - | - |
| 수정·저장 | 목록에서 선택 또는 신규 입력 중 | 검증 후 저장 | 코드 선택 Value Help | MD-M01 / CM-01, CM-02, CM-03 |
| 취소 | 입력 중 | 목록 복귀 | 변경 있으면 CM-07 확인 | - |

**메시지**: MD-M01 {사원/고객사/자재/작업장} 정보가 저장되었습니다.