### 전체 프로세스 flow
![Architecture Diagram](flow/flows-00.drawio.svg)

### PS-01 기준정보 등록
![Architecture Diagram](flow/flows-01.drawio.svg)
- 01-03 검증: 필수값 입력, 코드값 Code Master 존재 여부
- 01-04: 고유 ID 자동 생성 후 저장

### PS-02 프로젝트 생성
![Architecture Diagram](flow/flows-02.drawio.svg)
- 02-03: WBS Template 적용 체크박스
- 02-04 검증: 필수값 입력, 선박 타입 필수(Vessel Type Required=Y), 발주처·PM 존재, 시작일 ≤ 종료일
- 02-06~02-07: Template 적용을 선택했으면 Template으로 WBS 생성, 프로젝트와 함께 저장

### PS-03 WBS 구성
![Architecture Diagram](flow/flows-03.drawio.svg)
- 시작점: PS-02에서 Template을 적용하지 않았으면 처음부터 수동 구성, 적용했으면 생성된 WBS를 보완
- 03-02: 최상위 등록은 노드 선택 없이 가능하며 부모 없음·Level=1로 생성한다. 하위 등록은 부모 WBS를 선택한다.
- 03-03 검증
    - 등록: 프로젝트와 모든 상위 WBS가 CRTD 또는 REL. 최상위 등록은 프로젝트만 검사
    - 수정: 프로젝트, 수정 대상 WBS, 모든 상위 WBS가 CRTD 또는 REL
    - 하위 등록 시 부모 WBS가 같은 프로젝트 내 존재. 최상위 등록은 부모 존재 검사 제외
    - 최상위 WBS Level=1, 하위 WBS Level=부모 Level+1
    - Tree 형태 유지(순환 금지)

### PS-04 Activity 계획
![Architecture Diagram](flow/flows-04.drawio.svg)
- 04-03 검증 
    - 프로젝트, 해당 WBS, 모든 상위 WBS가 CRTD 또는 REL
    - 작업장은 Work Center, 담당자는 Employee에 존재
    - 시작일 ≤ 종료일

### PS-05 프로젝트·WBS Release
![Architecture Diagram](flow/flows-05.drawio.svg)

- 05-01 
    - 프로젝트나 상위 WBS가 CRTD여도 먼저 착수할 하위 WBS만 골라 Release 가능(부분 Release)
- 05-02 검증
    - 대상이 CRTD
    - 프로젝트·상위 WBS가 TECO·CLSD인 범위는 차단
- 05-03 
    - 상태가 바뀔 하위 WBS가 없으면 팝업 없이 05-05 
- 05-05
    - 대상과 전파 가능한 하위 CRTD WBS가 함께 REL (Mini PS 전파 규칙: BR-03)
    - TECO·CLSD WBS를 만나면 해당 WBS와 그 아래 전체는 제외한다. 제외된 노드는 확인 팝업의 변경 건수에도 포함하지 않는다.
    - 상위 WBS·프로젝트와 Activity 상태는 바뀌지 않음

### PS-06 작업 실행
![Architecture Diagram](flow/flows-06.drawio.svg)

- 06-03 검증
    - Activity가 속한 직속 WBS 상태만 확인 (상위 WBS·프로젝트는 보지 않음)
    - 착수/보류/재개 -> REL 상태여야 함
    - 완료 -> REL 또는 TECO
    - CLSD면 모두 차단

- 06-04 검증
    - Activity Status Transition에 존재하는 전이만 허용
        - PLAN→PROC(착수), PROC→HOLD(보류), HOLD→PROC(재개), PROC→COMP(완료)

### PS-07 기술 완료
![Architecture Diagram](flow/flows-07.drawio.svg)

- 07-02 검증
    - 대상이 REL
- 07-03 
    - 상태가 바뀔 하위 WBS가 없으면 팝업 없이 07-05

- 07-05~07-07 
    - 이번에 TECO가 되는 WBS의 미완료 Activity와, 이번 완료로 CRTD에 남아 잠기는 WBS·Activity를 구분하여 건수·목록을 경고한다(BR-06).
    - TECO 대상의 PROC 작업은 완료 가능하지만 PLAN·HOLD는 착수·재개 불가함을 안내한다. CRTD로 잠기는 WBS의 작업은 상태 변경 불가함을 안내한다.
    - CRTD로 잠기는 WBS에 Activity가 없어도 해당 WBS를 경고에 표시한다. 확인하면 진행하고 취소하면 상태를 유지한다.

- 07-08 
    - 대상과 하위 REL WBS -> TECO
    - 이미 TECO·CLSD인 WBS와 그 아래 전체는 상태 전파에서 제외한다. CRTD 노드는 유지하되 그 아래 REL WBS도 전파 대상으로 검사한다.
    - 하위 CRTD WBS는 변경 X (잠김, 이후 Release 불가)
    - 상위 WBS·프로젝트 상태는 그대로
    - 남은 Activity는 상태 유지, 진행 중인 것만 완료 가능
    - Activity 완료만으로 자동 TECO 되지 않음

### PS-08 프로젝트 종료
![Architecture Diagram](flow/flows-08.drawio.svg)

- 08-02 검증 
    - 프로젝트 상태 TECO
    - 프로젝트 전체 PROC Activity가 0건이어야 한다. 남아 있으면 건수·목록과 함께 완료 후 재요청 안내 후 차단
    - 하위 REL WBS가 0건이어야 한다. 남아 있으면 상태 정합성 확인 안내 후 차단
- 08-03 
    - PLAN·HOLD Activity와 CRTD WBS의 목록·건수를 구분하여 표시. Activity가 없는 CRTD WBS도 포함
    - 하나라도 있으면 미수행 범위 마감 사유(공백 불가)와 명시적 마감 동의를 필수로 받음
    - 종료 후 조회만 가능함을 안내. 미수행 범위가 없으면 사유는 선택
- 08-04
    - 담당자 최종 확인. 필수 사유·동의가 없으면 입력 보완, 취소하면 상태·이력 변경 없음
- 08-05 
    - 최신 상태와 확인한 대상 목록 재검증. 조건 불충족은 차단하고 목록 변경은 재확인
    - 프로젝트와 TECO·CRTD WBS를 CLSD로 변경, 기존 CLSD WBS 유지. Activity는 기존 상태 보존(자동 COMP 처리 금지)
    - CRTD→CLSD는 프로젝트 일괄 종료에서만 허용하는 Mini PS 예외. 개별 WBS 요청은 불가
    - 실행 사용자·시각·사유·동의 여부·미수행 대상 ID/당시 상태·변경 WBS 전후 상태를 종료 이력으로 저장
    - 상태 변경과 이력은 전체 성공 또는 전체 취소. 동시 변경을 제어하며 종료 후 프로젝트·WBS·Activity 및 종료 이력은 조회만 가능

종료 관련 상세 메시지와 CLOSE-01~10 테스트 시나리오는 [기능정의서](program_specs.md)의 PRJ-03을 따른다. 위 단계 설명은 종료 조건을 보완한 최신 기준이며, SVG의 08-02에는 PROC·REL 잔여 검증, 08-03에는 사유 입력, 08-05에는 이력 저장이 추가로 필요하다.
