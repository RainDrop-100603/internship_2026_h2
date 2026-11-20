class ZCL_PS_SEED_TESTDATA_YJ definition
  public
  final
  create public .

  public section.
    interfaces if_oo_adt_classrun.

  protected section.
  private section.

    " 테스트 데이터는 모두 'T' 접두어 ID를 쓴다. 적재 전에 'T%'로 시작하는 행만
    " 지우므로, 사용자가 화면에서 만든 데이터(C/E/M/W, PRJ/WBS/ACT 접두어)는
    " 그대로 남는다. 각 BO의 채번 determination도 자기 접두어만 대상으로
    " 최대값을 구하기 때문에 'T' ID가 채번에 끼어들지 않는다.
    "
    " 재적재 시 프로젝트·WBS의 UUID는 새로 만들지 않고 같은 ID로 이미 들어가
    " 있던 UUID를 그대로 재사용한다. 사용자가 테스트 프로젝트/WBS 아래에
    " 직접 만든 WBS·Activity(WBS/ACT 접두어, 삭제 대상 아님)가 참조하는
    " project_uuid / wbs_uuid 가 재실행 후에도 계속 유효해야 하기 때문이다.

    types:
      begin of ty_id_uuid,
        id   type c length 10,
        uuid type sysuuid_x16,
      end of ty_id_uuid,
      ty_id_uuid_tab type sorted table of ty_id_uuid with unique key id.

    " 기준정보 ID (영문 1자 + 숫자 9자리)
    constants c_emp1 type zps_employee_yj-employee_id value 'T000000001'.
    constants c_emp2 type zps_employee_yj-employee_id value 'T000000002'.
    constants c_emp3 type zps_employee_yj-employee_id value 'T000000003'.
    constants c_cus1 type zps_customer_yj-customer_id value 'T000000001'.
    constants c_cus2 type zps_customer_yj-customer_id value 'T000000002'.
    constants c_wc1  type zps_wrkctr_yj-work_center_id value 'T000000001'.
    constants c_wc2  type zps_wrkctr_yj-work_center_id value 'T000000002'.
    constants c_wc3  type zps_wrkctr_yj-work_center_id value 'T000000003'.

    " 업무 데이터 ID (영문 1자 + 영문 3자 + 숫자 6자리)
    constants c_prj1 type zps_project_yj-project_id value 'TPRJ000001'.
    constants c_prj2 type zps_project_yj-project_id value 'TPRJ000002'.
    constants c_wbs1 type zps_wbs_yj-wbs_id value 'TWBS000001'.
    constants c_wbs2 type zps_wbs_yj-wbs_id value 'TWBS000002'.
    constants c_wbs3 type zps_wbs_yj-wbs_id value 'TWBS000003'.
    constants c_wbs4 type zps_wbs_yj-wbs_id value 'TWBS000004'.
    constants c_wbs5 type zps_wbs_yj-wbs_id value 'TWBS000005'.
    constants c_wbs6 type zps_wbs_yj-wbs_id value 'TWBS000006'.
    constants c_wbs7 type zps_wbs_yj-wbs_id value 'TWBS000007'.

    methods new_uuid
      returning value(rv_uuid) type sysuuid_x16.

    " 같은 ID로 이미 있던 UUID가 있으면 그것을, 없으면 새 UUID를 돌려준다.
    methods stable_uuid
      importing it_old        type ty_id_uuid_tab
                iv_id         type ty_id_uuid-id
      returning value(rv_uuid) type sysuuid_x16.

endclass.



class ZCL_PS_SEED_TESTDATA_YJ implementation.

  method new_uuid.

    try.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      catch cx_uuid_error.
        clear rv_uuid.
    endtry.

  endmethod.


  method stable_uuid.

    try.
        rv_uuid = it_old[ id = iv_id ]-uuid.
      catch cx_sy_itab_line_not_found.
        clear rv_uuid.
    endtry.

    if rv_uuid is initial.
      rv_uuid = new_uuid( ).
    endif.

  endmethod.


  method if_oo_adt_classrun~main.

    data:
      lt_emp type standard table of zps_employee_yj with empty key,
      lt_cus type standard table of zps_customer_yj with empty key,
      lt_wc  type standard table of zps_wrkctr_yj with empty key,
      lt_mat type standard table of zps_material_yj with empty key,
      lt_prj type standard table of zps_project_yj with empty key,
      lt_wbs type standard table of zps_wbs_yj with empty key,
      lt_act type standard table of zps_activity_yj with empty key.

    data lv_now type timestampl.
    get time stamp field lv_now.

    data(lv_user) = sy-uname.

    "--------------------------------------------------------------
    " 이미 들어가 있는 테스트 프로젝트·WBS의 UUID 조회 (재사용용)
    "--------------------------------------------------------------
    data lt_old_prj type ty_id_uuid_tab.
    data lt_old_wbs type ty_id_uuid_tab.

    select project_id as id, project_uuid as uuid
      from zps_project_yj
      where project_id like 'T%'
      into table @lt_old_prj.

    select wbs_id as id, wbs_uuid as uuid
      from zps_wbs_yj
      where wbs_id like 'T%'
      into table @lt_old_wbs.

    "--------------------------------------------------------------
    " 기준정보 — 사원 3명 (부서·직급 코드는 1단계 코드 테이블 값만 사용)
    "--------------------------------------------------------------
    lt_emp = value #(
      ( client = sy-mandt employee_uuid = new_uuid( )
        employee_id = c_emp1 employee_name = '테스트 설계담당 김선임'
        department_code = 'DSG' position_code = 'SEN' contact = '010-1000-0001'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt employee_uuid = new_uuid( )
        employee_id = c_emp2 employee_name = '테스트 생산관리 이책임'
        department_code = 'PPC' position_code = 'LEAD' contact = '010-1000-0002'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt employee_uuid = new_uuid( )
        employee_id = c_emp3 employee_name = '테스트 선체가공 박프로'
        department_code = 'HUL' position_code = 'PRO' contact = '010-1000-0003'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " 기준정보 — 고객사 2개
    "--------------------------------------------------------------
    lt_cus = value #(
      ( client = sy-mandt customer_uuid = new_uuid( )
        customer_id = c_cus1 customer_name = '테스트 해운 주식회사'
        country_code = 'KR' contact_person = '최담당' contact = '02-100-0001'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt customer_uuid = new_uuid( )
        customer_id = c_cus2 customer_name = '테스트 글로벌 라인'
        country_code = 'JP' contact_person = '사토담당' contact = '03-100-0002'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " 기준정보 — 작업장 3개
    "--------------------------------------------------------------
    lt_wc = value #(
      ( client = sy-mandt work_center_uuid = new_uuid( )
        work_center_id = c_wc1 work_center_name = '테스트 설계작업장'
        process_category_code = 'DSG'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt work_center_uuid = new_uuid( )
        work_center_id = c_wc2 work_center_name = '테스트 조립작업장'
        process_category_code = 'ASM'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt work_center_uuid = new_uuid( )
        work_center_id = c_wc3 work_center_name = '테스트 도장작업장'
        process_category_code = 'PNT'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " 기준정보 — 자재 2개
    "--------------------------------------------------------------
    lt_mat = value #(
      ( client = sy-mandt material_uuid = new_uuid( )
        material_id = 'T000000001' material_name = '테스트 후판 20T'
        material_category_code = 'STL'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt material_uuid = new_uuid( )
        material_id = 'T000000002' material_name = '테스트 주기관 유닛'
        material_category_code = 'EQP'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " 프로젝트 2개 (모두 CRTD)
    "   TPRJ000001 : SHIP — 선박 타입 필수 프로파일, 선박 타입 LNG
    "   TPRJ000002 : RND  — 선박 타입 선택 프로파일, 선박 타입 없음 (TS-05 대조군)
    "--------------------------------------------------------------
    data(lv_prj1_uuid) = stable_uuid( it_old = lt_old_prj iv_id = c_prj1 ).
    data(lv_prj2_uuid) = stable_uuid( it_old = lt_old_prj iv_id = c_prj2 ).

    lt_prj = value #(
      ( client = sy-mandt project_uuid = lv_prj1_uuid
        project_id = c_prj1 project_name = '테스트 LNG 운반선 1호선 건조'
        profile_code = 'SHIP' vessel_type = 'LNG'
        pm_employee_id = c_emp2 customer_id = c_cus1
        contract_amount = '1200000.00'
        start_date = '20260101' end_date = '20261231' status = 'CRTD'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
      ( client = sy-mandt project_uuid = lv_prj2_uuid
        project_id = c_prj2 project_name = '테스트 용접 공법 연구개발'
        profile_code = 'RND' vessel_type = ''
        pm_employee_id = c_emp1 customer_id = c_cus2
        contract_amount = '150000.00'
        start_date = '20260301' end_date = '20260930' status = 'CRTD'
        created_by = lv_user created_at = lv_now
        last_changed_by = lv_user local_last_changed_at = lv_now last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " WBS — TPRJ000001 아래 7건
    "   TWBS000001 (L1, CRTD) ── TWBS000003 (L2, CRTD) ── TWBS000007 (L3, CRTD)
    "                         └─ TWBS000004 (L2, CRTD)
    "   TWBS000002 (L1, TECO) ── TWBS000005 (L2, CRTD)   <- TS-09 확인용
    "                         └─ TWBS000006 (L2, CRTD)
    " 상태 변경 기능이 1차 MVP에 없으므로 TECO 범위는 데이터로 직접 만든다.
    "--------------------------------------------------------------
    data(lv_wbs1_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs1 ).
    data(lv_wbs2_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs2 ).
    data(lv_wbs3_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs3 ).
    data(lv_wbs4_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs4 ).
    data(lv_wbs5_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs5 ).
    data(lv_wbs6_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs6 ).
    data(lv_wbs7_uuid) = stable_uuid( it_old = lt_old_wbs iv_id = c_wbs7 ).

    lt_wbs = value #(
      ( client = sy-mandt wbs_uuid = lv_wbs1_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs1 wbs_name = '테스트 선체 공사'
        parent_wbs_id = '' wbs_level = 1 status = 'CRTD'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs2_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs2 wbs_name = '테스트 기본 설계 (TECO)'
        parent_wbs_id = '' wbs_level = 1 status = 'TECO'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs3_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs3 wbs_name = '테스트 블록 가공'
        parent_wbs_id = c_wbs1 wbs_level = 2 status = 'CRTD'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs4_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs4 wbs_name = '테스트 블록 조립'
        parent_wbs_id = c_wbs1 wbs_level = 2 status = 'CRTD'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs5_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs5 wbs_name = '테스트 선형 설계'
        parent_wbs_id = c_wbs2 wbs_level = 2 status = 'CRTD'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs6_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs6 wbs_name = '테스트 구조 설계'
        parent_wbs_id = c_wbs2 wbs_level = 2 status = 'CRTD'
        local_last_changed_at = lv_now )
      ( client = sy-mandt wbs_uuid = lv_wbs7_uuid project_uuid = lv_prj1_uuid
        wbs_id = c_wbs7 wbs_name = '테스트 소조립 가공'
        parent_wbs_id = c_wbs3 wbs_level = 3 status = 'CRTD'
        local_last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " Activity — 모두 PLAN
    "   TACT000001 : TWBS000004 (말단 WBS)
    "   TACT000002 : TWBS000007 (Level 3 말단 WBS)
    "   TACT000003 : TWBS000003 (하위 WBS가 있는 WBS — TS-10 말단 제한 없음)
    "   TACT000004 : TWBS000005 (TECO 상위 아래 — TS-09 수정 차단 확인용)
    "--------------------------------------------------------------
    lt_act = value #(
      ( client = sy-mandt activity_uuid = new_uuid( )
        wbs_uuid = lv_wbs4_uuid project_uuid = lv_prj1_uuid
        activity_id = 'TACT000001' activity_name = '테스트 블록 조립 작업'
        work_center_id = c_wc2 employee_id = c_emp3
        start_date = '20260401' end_date = '20260630' status = 'PLAN'
        local_last_changed_at = lv_now )
      ( client = sy-mandt activity_uuid = new_uuid( )
        wbs_uuid = lv_wbs7_uuid project_uuid = lv_prj1_uuid
        activity_id = 'TACT000002' activity_name = '테스트 소조립 절단'
        work_center_id = c_wc2 employee_id = c_emp3
        start_date = '20260301' end_date = '20260430' status = 'PLAN'
        local_last_changed_at = lv_now )
      ( client = sy-mandt activity_uuid = new_uuid( )
        wbs_uuid = lv_wbs3_uuid project_uuid = lv_prj1_uuid
        activity_id = 'TACT000003' activity_name = '테스트 가공 공정 검토'
        work_center_id = c_wc1 employee_id = c_emp1
        start_date = '20260201' end_date = '20260331' status = 'PLAN'
        local_last_changed_at = lv_now )
      ( client = sy-mandt activity_uuid = new_uuid( )
        wbs_uuid = lv_wbs5_uuid project_uuid = lv_prj1_uuid
        activity_id = 'TACT000004' activity_name = '테스트 선형 계산 (TECO 범위)'
        work_center_id = c_wc1 employee_id = c_emp1
        start_date = '20260110' end_date = '20260228' status = 'PLAN'
        local_last_changed_at = lv_now )
    ).

    "--------------------------------------------------------------
    " 'T' 접두어 행만 삭제한 뒤 다시 적재 — 여러 번 실행해도 결과가 같다.
    " 하위부터 지워 참조가 끊긴 행이 남지 않게 한다.
    " 프로젝트·WBS는 기존 UUID를 그대로 다시 넣으므로, 테스트 프로젝트/WBS
    " 아래에 사용자가 만든 WBS·Activity의 부모 참조도 그대로 유지된다.
    "--------------------------------------------------------------
    delete from zps_activity_yj where activity_id like 'T%'.
    delete from zps_wbs_yj      where wbs_id like 'T%'.
    delete from zps_project_yj  where project_id like 'T%'.
    delete from zps_employee_yj where employee_id like 'T%'.
    delete from zps_customer_yj where customer_id like 'T%'.
    delete from zps_wrkctr_yj   where work_center_id like 'T%'.
    delete from zps_material_yj where material_id like 'T%'.

    insert zps_employee_yj from table @lt_emp.
    insert zps_customer_yj from table @lt_cus.
    insert zps_wrkctr_yj   from table @lt_wc.
    insert zps_material_yj from table @lt_mat.
    insert zps_project_yj  from table @lt_prj.
    insert zps_wbs_yj      from table @lt_wbs.
    insert zps_activity_yj from table @lt_act.

    "--------------------------------------------------------------
    " 적재 결과
    "--------------------------------------------------------------
    out->write( |ZPS_EMPLOYEE_YJ : { lines( lt_emp ) } rows| ).
    out->write( |ZPS_CUSTOMER_YJ : { lines( lt_cus ) } rows| ).
    out->write( |ZPS_WRKCTR_YJ   : { lines( lt_wc )  } rows| ).
    out->write( |ZPS_MATERIAL_YJ : { lines( lt_mat ) } rows| ).
    out->write( |ZPS_PROJECT_YJ  : { lines( lt_prj ) } rows| ).
    out->write( |ZPS_WBS_YJ      : { lines( lt_wbs ) } rows| ).
    out->write( |ZPS_ACTIVITY_YJ : { lines( lt_act ) } rows| ).
    out->write( |----------------------------------------| ).
    out->write( |TS-09 확인용: TECO WBS { c_wbs2 } 아래 { c_wbs5 }에서 등록·수정이 막혀야 함| ).
    out->write( |  - { c_wbs5 } 이름 수정 → WBS-M05| ).
    out->write( |  - { c_wbs5 } 에 Activity 등록 / TACT000004 수정 → ACT-M04| ).
    out->write( |  - 같은 프로젝트의 { c_wbs1 } 범위(하위 { c_wbs3 }·{ c_wbs4 })는 정상 동작해야 함| ).

  endmethod.

endclass.
