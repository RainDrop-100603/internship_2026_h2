CLASS lhc_project DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR Project
      RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Project RESULT result.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Project~setInitialStatus.

    METHODS setProjectId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Project~setProjectId.

    METHODS validateRequired FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validateRequired.

    METHODS validateProfile FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validateProfile.

    METHODS validateVesselType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validateVesselType.

    METHODS validatePm FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validatePm.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Project~validateDates.

ENDCLASS.

CLASS lhc_project IMPLEMENTATION.

  METHOD get_global_authorizations.

    result-%create = COND #( WHEN requested_authorizations-%create = if_abap_behv=>mk-on
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

    result-%update = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

    result-%action-Edit = COND #( WHEN requested_authorizations-%action-Edit = if_abap_behv=>mk-on
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

  ENDMETHOD.

  METHOD get_instance_features.

    " BR-09: CRTD·REL 상태에서만 프로젝트 기본정보를 수정할 수 있다.
    " TECO·CLSD 프로젝트는 수정(update)과 편집 전환(Edit)을 비활성화한다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    " PRJ-03: 프로파일·선박 타입은 생성 후 수정 불가.
    " draft 시나리오에서는 생성 직후 필드 입력도 UPDATE로 전달되므로,
    " 아직 활성 데이터가 없는 신규 draft에서는 입력을 허용하고
    " 활성화된 프로젝트(활성 테이블에 행이 있는 경우)에서만 읽기 전용으로 만든다.
    DATA uuids        TYPE SORTED TABLE OF zps_project_yj-project_uuid WITH UNIQUE KEY table_line.
    DATA active_uuids TYPE SORTED TABLE OF zps_project_yj-project_uuid WITH NON-UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_key).
      INSERT ls_key-%tky-ProjectUuid INTO TABLE uuids.
    ENDLOOP.

    IF uuids IS NOT INITIAL.
      SELECT project_uuid FROM zps_project_yj
        FOR ALL ENTRIES IN @uuids
        WHERE project_uuid = @uuids-table_line
        INTO TABLE @active_uuids.
    ENDIF.

    LOOP AT projects INTO DATA(project).

      DATA(lv_feature) = COND #( WHEN project-Status = 'TECO' OR project-Status = 'CLSD'
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled ).

      DATA(lv_create_only) = COND #( WHEN line_exists( active_uuids[ table_line = project-%tky-ProjectUuid ] )
                                      THEN if_abap_behv=>fc-f-read_only
                                      ELSE if_abap_behv=>fc-f-unrestricted ).

      " BR-09: TECO·CLSD 프로젝트에는 WBS를 새로 등록할 수 없다.
      APPEND VALUE #( %tky               = project-%tky
                       %update            = lv_feature
                       %action-Edit       = lv_feature
                       %assoc-_Wbs        = lv_feature
                       %field-ProfileCode = lv_create_only
                       %field-VesselType  = lv_create_only )
             TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD setInitialStatus.

    " BR-02: 상태는 직접 입력할 수 없고, 선택한 프로파일의 Initial Status로 설정한다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProfileCode Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    DATA profile_codes TYPE SORTED TABLE OF zps_prjprof_yj-profile_code WITH UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_project) WHERE ProfileCode IS NOT INITIAL.
      INSERT ls_project-ProfileCode INTO TABLE profile_codes.
    ENDLOOP.

    IF profile_codes IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_profile TYPE SORTED TABLE OF zps_prjprof_yj WITH UNIQUE KEY profile_code.

    SELECT * FROM zps_prjprof_yj
      FOR ALL ENTRIES IN @profile_codes
      WHERE profile_code = @profile_codes-table_line
      INTO TABLE @lt_profile.

    LOOP AT projects INTO DATA(project) WHERE ProfileCode IS NOT INITIAL.

      " 프로파일이 존재하지 않으면 상태를 비워 두고 validateProfile(CM-02)에서 막는다.
      IF NOT line_exists( lt_profile[ profile_code = project-ProfileCode ] ).
        CONTINUE.
      ENDIF.

      DATA(lv_status) = lt_profile[ profile_code = project-ProfileCode ]-initial_status.

      MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
        ENTITY Project
          UPDATE FIELDS ( Status )
          WITH VALUE #( ( %tky   = project-%tky
                           Status = lv_status ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD setProjectId.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProjectId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    " 이미 ProjectId가 있어도(draft Prepare 단계에서 미리 채번된 경우 포함)
    " 그 번호를 활성 테이블의 다른 프로젝트(다른 UUID)가 먼저 쓰고 있다면
    " 재채번 대상으로 잡는다 (고객사 BO와 같은 패턴).
    DATA assigned_ids TYPE SORTED TABLE OF zps_project_yj-project_id WITH NON-UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_scan) WHERE ProjectId IS NOT INITIAL.
      INSERT ls_scan-ProjectId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_project_yj WITH NON-UNIQUE KEY project_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT project_id, project_uuid FROM zps_project_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE project_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_projects_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT projects INTO DATA(ls_check).
      IF ls_check-ProjectId IS INITIAL
         OR ( line_exists( lt_active[ project_id = ls_check-ProjectId ] )
              AND NOT line_exists( lt_active[ project_id   = ls_check-ProjectId
                                               project_uuid = ls_check-%tky-ProjectUuid ] ) ).
        has_projects_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_projects_to_update = abap_false.
      RETURN.
    ENDIF.

    " 'PRJ'로 시작하는 기존 최대 ProjectId를 조회해 다음 번호부터 채번한다
    " (6단계 테스트 데이터의 'T' 접두어 ID와 섞이지 않도록 접두어를 한정한다).
    " 동시 생성 시 중복 가능성은 Mock-up 범위에서 허용한다
    " (번호 범위 객체는 서버에 없어 사용하지 않음).
    SELECT SINGLE MAX( project_id ) FROM zps_project_yj
      WHERE project_id LIKE 'PRJ%'
      INTO @DATA(lv_max_project_id).

    DATA(lv_next_nr) = COND i( WHEN lv_max_project_id IS NOT INITIAL
                                THEN lv_max_project_id+3(7)
                                ELSE 0 ).

    LOOP AT projects INTO DATA(project).

      CHECK project-ProjectId IS INITIAL
         OR ( line_exists( lt_active[ project_id = project-ProjectId ] )
              AND NOT line_exists( lt_active[ project_id   = project-ProjectId
                                               project_uuid = project-%tky-ProjectUuid ] ) ).

      lv_next_nr = lv_next_nr + 1.

      DATA(lv_project_id) = |PRJ{ lv_next_nr WIDTH = 7 ALIGN = RIGHT PAD = '0' }|.

      MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
        ENTITY Project
          UPDATE FIELDS ( ProjectId )
          WITH VALUE #( ( %tky      = project-%tky
                           ProjectId = lv_project_id ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateRequired.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProjectName ProfileCode PmEmployeeId CustomerId StartDate EndDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_REQUIRED' ) TO reported-project.

      IF project-ProjectName IS INITIAL OR project-ProfileCode IS INITIAL
         OR project-PmEmployeeId IS INITIAL OR project-CustomerId IS INITIAL
         OR project-StartDate IS INITIAL OR project-EndDate IS INITIAL.

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

      ENDIF.

      " 비어 있는 필드마다 CM-01 메시지를 해당 입력 칸에 표시한다.
      IF project-ProjectName IS INITIAL.
        APPEND VALUE #( %tky                 = project-%tky
                         %state_area          = 'VALIDATE_REQUIRED'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '필수 항목을 입력해주세요.' )
                         %element-ProjectName = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

      IF project-ProfileCode IS INITIAL.
        APPEND VALUE #( %tky                 = project-%tky
                         %state_area          = 'VALIDATE_REQUIRED'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '필수 항목을 입력해주세요.' )
                         %element-ProfileCode = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

      IF project-PmEmployeeId IS INITIAL.
        APPEND VALUE #( %tky                  = project-%tky
                         %state_area           = 'VALIDATE_REQUIRED'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '필수 항목을 입력해주세요.' )
                         %element-PmEmployeeId = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

      IF project-CustomerId IS INITIAL.
        APPEND VALUE #( %tky                = project-%tky
                         %state_area         = 'VALIDATE_REQUIRED'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '필수 항목을 입력해주세요.' )
                         %element-CustomerId = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

      IF project-StartDate IS INITIAL.
        APPEND VALUE #( %tky               = project-%tky
                         %state_area        = 'VALIDATE_REQUIRED'
                         %msg               = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = '필수 항목을 입력해주세요.' )
                         %element-StartDate = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

      IF project-EndDate IS INITIAL.
        APPEND VALUE #( %tky             = project-%tky
                         %state_area      = 'VALIDATE_REQUIRED'
                         %msg             = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = '필수 항목을 입력해주세요.' )
                         %element-EndDate = if_abap_behv=>mk-on )
               TO reported-project.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateProfile.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProfileCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    DATA profile_codes TYPE SORTED TABLE OF zps_prjprof_yj-profile_code WITH UNIQUE KEY table_line.
    DATA found_profiles TYPE SORTED TABLE OF zps_prjprof_yj-profile_code WITH NON-UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_project) WHERE ProfileCode IS NOT INITIAL.
      INSERT ls_project-ProfileCode INTO TABLE profile_codes.
    ENDLOOP.

    IF profile_codes IS NOT INITIAL.
      SELECT profile_code FROM zps_prjprof_yj
        FOR ALL ENTRIES IN @profile_codes
        WHERE profile_code = @profile_codes-table_line
        INTO TABLE @found_profiles.
    ENDIF.

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_PROFILE' ) TO reported-project.

      " 빈 값은 validateRequired(CM-01)에서 처리한다.
      IF project-ProfileCode IS NOT INITIAL
         AND NOT line_exists( found_profiles[ table_line = project-ProfileCode ] ).

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

        APPEND VALUE #( %tky                 = project-%tky
                         %state_area          = 'VALIDATE_PROFILE'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-ProfileCode = if_abap_behv=>mk-on )
               TO reported-project.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateVesselType.

    " BR-14: Vessel Type Required = Y인 프로파일(SHIP·REPR·CNVT)은 선박 타입이 필수,
    " RND·FAC는 비어 있어도 통과한다. 값이 있으면 코드 존재 여부를 검증한다 (BR-16).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProfileCode VesselType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    DATA profile_codes TYPE SORTED TABLE OF zps_prjprof_yj-profile_code WITH UNIQUE KEY table_line.
    DATA vessel_codes  TYPE SORTED TABLE OF zps_vsltype_yj-code WITH UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_project).
      IF ls_project-ProfileCode IS NOT INITIAL.
        INSERT ls_project-ProfileCode INTO TABLE profile_codes.
      ENDIF.
      IF ls_project-VesselType IS NOT INITIAL.
        INSERT ls_project-VesselType INTO TABLE vessel_codes.
      ENDIF.
    ENDLOOP.

    DATA lt_profile TYPE SORTED TABLE OF zps_prjprof_yj WITH UNIQUE KEY profile_code.
    DATA lt_vessel  TYPE SORTED TABLE OF zps_vsltype_yj WITH UNIQUE KEY code.

    IF profile_codes IS NOT INITIAL.
      SELECT * FROM zps_prjprof_yj
        FOR ALL ENTRIES IN @profile_codes
        WHERE profile_code = @profile_codes-table_line
        INTO TABLE @lt_profile.
    ENDIF.

    IF vessel_codes IS NOT INITIAL.
      SELECT * FROM zps_vsltype_yj
        FOR ALL ENTRIES IN @vessel_codes
        WHERE code = @vessel_codes-table_line
        INTO TABLE @lt_vessel.
    ENDIF.

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_VESSEL_TYPE' ) TO reported-project.

      IF project-VesselType IS INITIAL.

        " 프로파일을 찾을 수 없으면 validateProfile(CM-02)에서 막으므로 여기서는 건너뛴다.
        IF project-ProfileCode IS NOT INITIAL
           AND line_exists( lt_profile[ profile_code = project-ProfileCode ] )
           AND lt_profile[ profile_code = project-ProfileCode ]-vessel_type_required = abap_true.

          APPEND VALUE #( %tky = project-%tky ) TO failed-project.

          APPEND VALUE #( %tky                = project-%tky
                           %state_area         = 'VALIDATE_VESSEL_TYPE'
                           %msg                = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '선박 타입을 선택해주세요.' )
                           %element-VesselType = if_abap_behv=>mk-on )
                 TO reported-project.

        ENDIF.

      ELSEIF NOT line_exists( lt_vessel[ code = project-VesselType ] ).

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

        APPEND VALUE #( %tky                = project-%tky
                         %state_area         = 'VALIDATE_VESSEL_TYPE'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-VesselType = if_abap_behv=>mk-on )
               TO reported-project.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validatePm.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( PmEmployeeId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    DATA pm_ids    TYPE SORTED TABLE OF zps_employee_yj-employee_id WITH UNIQUE KEY table_line.
    DATA found_pms TYPE SORTED TABLE OF zps_employee_yj-employee_id WITH NON-UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_project) WHERE PmEmployeeId IS NOT INITIAL.
      INSERT ls_project-PmEmployeeId INTO TABLE pm_ids.
    ENDLOOP.

    IF pm_ids IS NOT INITIAL.
      SELECT employee_id FROM zps_employee_yj
        FOR ALL ENTRIES IN @pm_ids
        WHERE employee_id = @pm_ids-table_line
        INTO TABLE @found_pms.
    ENDIF.

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_PM' ) TO reported-project.

      IF project-PmEmployeeId IS NOT INITIAL
         AND NOT line_exists( found_pms[ table_line = project-PmEmployeeId ] ).

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

        APPEND VALUE #( %tky                  = project-%tky
                         %state_area           = 'VALIDATE_PM'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-PmEmployeeId = if_abap_behv=>mk-on )
               TO reported-project.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateCustomer.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( CustomerId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    DATA customer_ids   TYPE SORTED TABLE OF zps_customer_yj-customer_id WITH UNIQUE KEY table_line.
    DATA found_customers TYPE SORTED TABLE OF zps_customer_yj-customer_id WITH NON-UNIQUE KEY table_line.

    LOOP AT projects INTO DATA(ls_project) WHERE CustomerId IS NOT INITIAL.
      INSERT ls_project-CustomerId INTO TABLE customer_ids.
    ENDLOOP.

    IF customer_ids IS NOT INITIAL.
      SELECT customer_id FROM zps_customer_yj
        FOR ALL ENTRIES IN @customer_ids
        WHERE customer_id = @customer_ids-table_line
        INTO TABLE @found_customers.
    ENDIF.

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_CUSTOMER' ) TO reported-project.

      IF project-CustomerId IS NOT INITIAL
         AND NOT line_exists( found_customers[ table_line = project-CustomerId ] ).

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

        APPEND VALUE #( %tky                = project-%tky
                         %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-CustomerId = if_abap_behv=>mk-on )
               TO reported-project.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateDates.

    " BR-15: 시작일 <= 종료일
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project
        FIELDS ( StartDate EndDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    LOOP AT projects INTO DATA(project).

      APPEND VALUE #( %tky = project-%tky %state_area = 'VALIDATE_DATES' ) TO reported-project.

      IF project-StartDate IS NOT INITIAL AND project-EndDate IS NOT INITIAL
         AND project-StartDate > project-EndDate.

        APPEND VALUE #( %tky = project-%tky ) TO failed-project.

        APPEND VALUE #( %tky               = project-%tky
                         %state_area        = 'VALIDATE_DATES'
                         %msg               = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = '시작일은 종료일보다 늦을 수 없습니다.' )
                         %element-StartDate = if_abap_behv=>mk-on
                         %element-EndDate   = if_abap_behv=>mk-on )
               TO reported-project.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


CLASS lhc_wbs DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    " 권한은 프로젝트(루트)에 위임한다 (authorization dependent by _Project).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Wbs RESULT result.

    METHODS setWbsDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Wbs~setWbsDefaults.

    METHODS setWbsId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Wbs~setWbsId.

    METHODS validateWbsName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Wbs~validateWbsName.

    METHODS validateParent FOR VALIDATE ON SAVE
      IMPORTING keys FOR Wbs~validateParent.

    METHODS validateWbsScope FOR VALIDATE ON SAVE
      IMPORTING keys FOR Wbs~validateWbsScope.

ENDCLASS.

CLASS lhc_wbs IMPLEMENTATION.

  METHOD get_instance_features.

    " BR-09: 자신·상위 WBS·프로젝트 중 TECO·CLSD가 하나라도 있으면 수정할 수 없다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    IF wbs_list IS INITIAL.
      RETURN.
    ENDIF.

    " 소속 프로젝트 상태 (draft 포함)
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    " 같은 프로젝트의 모든 WBS (상위 체인 추적용, draft 포함)
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    " BR-12: 활성 데이터가 이미 있는 WBS는 부모를 바꿀 수 없다.
    DATA wbs_uuids    TYPE SORTED TABLE OF zps_wbs_yj-wbs_uuid WITH UNIQUE KEY table_line.
    DATA active_uuids TYPE SORTED TABLE OF zps_wbs_yj-wbs_uuid WITH NON-UNIQUE KEY table_line.
    DATA visited      TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH UNIQUE KEY table_line.

    LOOP AT wbs_list INTO DATA(ls_key).
      INSERT ls_key-%tky-WbsUuid INTO TABLE wbs_uuids.
    ENDLOOP.

    IF wbs_uuids IS NOT INITIAL.
      SELECT wbs_uuid FROM zps_wbs_yj
        FOR ALL ENTRIES IN @wbs_uuids
        WHERE wbs_uuid = @wbs_uuids-table_line
        INTO TABLE @active_uuids.
    ENDIF.

    LOOP AT wbs_list INTO DATA(wbs).

      DATA(lv_locked) = abap_false.

      " 프로젝트 상태
      READ TABLE projects INTO DATA(ls_prj) WITH KEY ProjectUuid = wbs-ProjectUuid.
      IF sy-subrc = 0 AND ( ls_prj-Status = 'TECO' OR ls_prj-Status = 'CLSD' ).
        lv_locked = abap_true.
      ENDIF.

      " 자신의 상태
      IF wbs-Status = 'TECO' OR wbs-Status = 'CLSD'.
        lv_locked = abap_true.
      ENDIF.

      " 상위 WBS 체인을 루트까지 따라간다.
      " 깊이 제한 대신 방문한 WbsId 집합으로 순환을 감지한다 (데이터 오류로 무한 루프 방지).
      CLEAR visited.
      DATA(lv_node) = wbs-ParentWbsId.
      WHILE lv_node IS NOT INITIAL.
        IF line_exists( visited[ table_line = lv_node ] ).
          EXIT.
        ENDIF.
        INSERT lv_node INTO TABLE visited.
        READ TABLE all_wbs INTO DATA(ls_anc)
             WITH KEY ProjectUuid = wbs-ProjectUuid
                      WbsId       = lv_node.
        IF sy-subrc <> 0.
          CLEAR lv_node.
        ELSE.
          IF ls_anc-Status = 'TECO' OR ls_anc-Status = 'CLSD'.
            lv_locked = abap_true.
          ENDIF.
          lv_node = ls_anc-ParentWbsId.
        ENDIF.
      ENDWHILE.

      DATA(lv_update) = COND #( WHEN lv_locked = abap_true
                                 THEN if_abap_behv=>fc-o-disabled
                                 ELSE if_abap_behv=>fc-o-enabled ).

      DATA(lv_parent_fc) = COND #( WHEN line_exists( active_uuids[ table_line = wbs-%tky-WbsUuid ] )
                                    THEN if_abap_behv=>fc-f-read_only
                                    ELSE if_abap_behv=>fc-f-unrestricted ).

      " BR-09: 범위를 벗어난 WBS(자신·상위·프로젝트 중 TECO·CLSD)에는
      " Activity를 새로 등록할 수 없다.
      APPEND VALUE #( %tky               = wbs-%tky
                       %update            = lv_update
                       %assoc-_Activity   = lv_update
                       %field-ParentWbsId = lv_parent_fc )
             TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD setWbsDefaults.

    " BR-02: 상태는 직접 입력할 수 없고 생성 시 CRTD로 설정한다.
    " BR-12: 부모가 없으면 Level 1, 있으면 같은 프로젝트 부모 WBS의 Level + 1.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( ProjectUuid ParentWbsId WbsLevel Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    IF wbs_list IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId WbsLevel )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    DATA lt_update TYPE TABLE FOR UPDATE zr_ps_project_yj\\Wbs.

    LOOP AT wbs_list INTO DATA(wbs).

      DATA(lv_level) = wbs-WbsLevel.

      IF wbs-ParentWbsId IS INITIAL.
        lv_level = 1.
      ELSE.
        READ TABLE all_wbs INTO DATA(ls_parent)
             WITH KEY ProjectUuid = wbs-ProjectUuid
                      WbsId       = wbs-ParentWbsId.
        IF sy-subrc = 0.
          lv_level = ls_parent-WbsLevel + 1.
        ENDIF.
        " 부모를 찾을 수 없으면 Level은 그대로 두고 validateParent(WBS-M06)에서 막는다.
      ENDIF.

      DATA(lv_status) = wbs-Status.
      IF lv_status IS INITIAL.
        lv_status = 'CRTD'.
      ENDIF.

      APPEND VALUE #( %tky     = wbs-%tky
                       WbsLevel = lv_level
                       Status   = lv_status )
             TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        UPDATE FIELDS ( WbsLevel Status )
        WITH lt_update.

  ENDMETHOD.

  METHOD setWbsId.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( WbsId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    " 이미 WbsId가 있어도 그 번호를 활성 테이블의 다른 WBS(다른 UUID)가 먼저 쓰고 있으면
    " 재채번 대상으로 잡는다 (3단계 프로젝트 BO와 같은 패턴).
    DATA assigned_ids TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH NON-UNIQUE KEY table_line.

    LOOP AT wbs_list INTO DATA(ls_scan) WHERE WbsId IS NOT INITIAL.
      INSERT ls_scan-WbsId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_wbs_yj WITH NON-UNIQUE KEY wbs_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT wbs_id, wbs_uuid FROM zps_wbs_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE wbs_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_wbs_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT wbs_list INTO DATA(ls_check).
      IF ls_check-WbsId IS INITIAL
         OR ( line_exists( lt_active[ wbs_id = ls_check-WbsId ] )
              AND NOT line_exists( lt_active[ wbs_id   = ls_check-WbsId
                                               wbs_uuid = ls_check-%tky-WbsUuid ] ) ).
        has_wbs_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_wbs_to_update = abap_false.
      RETURN.
    ENDIF.

    " 'WBS'로 시작하는 기존 최대 WbsId를 조회해 다음 번호부터 채번한다
    " (6단계 테스트 데이터의 'T' 접두어 ID와 섞이지 않도록 접두어를 한정한다).
    " 동시 생성 시 중복 가능성은 Mock-up 범위에서 허용한다.
    SELECT SINGLE MAX( wbs_id ) FROM zps_wbs_yj
      WHERE wbs_id LIKE 'WBS%'
      INTO @DATA(lv_max_wbs_id).

    DATA(lv_next_nr) = COND i( WHEN lv_max_wbs_id IS NOT INITIAL
                                THEN lv_max_wbs_id+3(7)
                                ELSE 0 ).

    LOOP AT wbs_list INTO DATA(wbs).

      CHECK wbs-WbsId IS INITIAL
         OR ( line_exists( lt_active[ wbs_id = wbs-WbsId ] )
              AND NOT line_exists( lt_active[ wbs_id   = wbs-WbsId
                                               wbs_uuid = wbs-%tky-WbsUuid ] ) ).

      lv_next_nr = lv_next_nr + 1.

      DATA(lv_wbs_id) = |WBS{ lv_next_nr WIDTH = 7 ALIGN = RIGHT PAD = '0' }|.

      MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
        ENTITY Wbs
          UPDATE FIELDS ( WbsId )
          WITH VALUE #( ( %tky  = wbs-%tky
                           WbsId = lv_wbs_id ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateWbsName.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( ProjectUuid WbsName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    LOOP AT wbs_list INTO DATA(wbs).

      APPEND VALUE #( %tky = wbs-%tky %state_area = 'VALIDATE_WBS_NAME' ) TO reported-wbs.

      IF wbs-WbsName IS INITIAL.

        APPEND VALUE #( %tky = wbs-%tky ) TO failed-wbs.

        " 자식 엔터티 메시지는 부모 프로젝트를 가리키는 %path가 있어야 UI에 표시된다.
        APPEND VALUE #( %tky             = wbs-%tky
                         %path            = VALUE #( Project-%tky = VALUE #(
                                                 ProjectUuid = wbs-ProjectUuid
                                                 %is_draft   = wbs-%tky-%is_draft ) )
                         %state_area      = 'VALIDATE_WBS_NAME'
                         %msg             = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = '필수 항목을 입력해주세요.' )
                         %element-WbsName = if_abap_behv=>mk-on )
               TO reported-wbs.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateParent.

    " BR-12: 부모는 같은 프로젝트의 WBS여야 하고(WBS-M06),
    " 자기 자신이나 자기 하위 WBS를 부모로 지정할 수 없다(WBS-M07, 순환 금지).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    IF wbs_list IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    DATA visited TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH UNIQUE KEY table_line.

    LOOP AT wbs_list INTO DATA(wbs).

      APPEND VALUE #( %tky = wbs-%tky %state_area = 'VALIDATE_PARENT' ) TO reported-wbs.

      " 최상위 WBS는 부모가 없다 (Level 1).
      IF wbs-ParentWbsId IS INITIAL.
        CONTINUE.
      ENDIF.

      " 같은 프로젝트에 그 부모 WBS가 있는지 확인한다.
      READ TABLE all_wbs TRANSPORTING NO FIELDS
           WITH KEY ProjectUuid = wbs-ProjectUuid
                    WbsId       = wbs-ParentWbsId.

      IF sy-subrc <> 0.

        APPEND VALUE #( %tky = wbs-%tky ) TO failed-wbs.

        APPEND VALUE #( %tky                 = wbs-%tky
                         %path                = VALUE #( Project-%tky = VALUE #(
                                                     ProjectUuid = wbs-ProjectUuid
                                                     %is_draft   = wbs-%tky-%is_draft ) )
                         %state_area          = 'VALIDATE_PARENT'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '같은 프로젝트의 상위 WBS를 선택해주세요.' )
                         %element-ParentWbsId = if_abap_behv=>mk-on )
               TO reported-wbs.

        CONTINUE.

      ENDIF.

      " 자기 자신 또는 자기 자손을 부모로 지정했는지 확인한다.
      DATA(lv_cycle) = abap_false.

      IF wbs-WbsId IS NOT INITIAL.

        IF wbs-ParentWbsId = wbs-WbsId.
          lv_cycle = abap_true.
        ELSE.
          " 부모 체인을 루트까지 따라간다. 방문한 WbsId 집합으로
          " 기존 데이터의 순환을 감지해 무한 루프를 막는다.
          CLEAR visited.
          DATA(lv_node) = wbs-ParentWbsId.
          WHILE lv_node IS NOT INITIAL.
            IF line_exists( visited[ table_line = lv_node ] ).
              EXIT.
            ENDIF.
            INSERT lv_node INTO TABLE visited.
            READ TABLE all_wbs INTO DATA(ls_anc)
                 WITH KEY ProjectUuid = wbs-ProjectUuid
                          WbsId       = lv_node.
            IF sy-subrc <> 0.
              CLEAR lv_node.
            ELSE.
              lv_node = ls_anc-ParentWbsId.
              IF lv_node = wbs-WbsId.
                lv_cycle = abap_true.
                CLEAR lv_node.
              ENDIF.
            ENDIF.
          ENDWHILE.
        ENDIF.

      ENDIF.

      IF lv_cycle = abap_true.

        APPEND VALUE #( %tky = wbs-%tky ) TO failed-wbs.

        APPEND VALUE #( %tky                 = wbs-%tky
                         %path                = VALUE #( Project-%tky = VALUE #(
                                                     ProjectUuid = wbs-ProjectUuid
                                                     %is_draft   = wbs-%tky-%is_draft ) )
                         %state_area          = 'VALIDATE_PARENT'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '자기 자신이나 하위 WBS를 부모로 선택할 수 없습니다.' )
                         %element-ParentWbsId = if_abap_behv=>mk-on )
               TO reported-wbs.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateWbsScope.

    " BR-09: 프로젝트와 모든 상위 WBS가 CRTD 또는 REL이어야 WBS를 등록·수정할 수 있다.
    " 수정(활성 데이터가 이미 있는 WBS)일 때는 대상 WBS 자신의 상태도 함께 본다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(wbs_list).

    IF wbs_list IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(projects).

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    DATA wbs_uuids    TYPE SORTED TABLE OF zps_wbs_yj-wbs_uuid WITH UNIQUE KEY table_line.
    DATA active_uuids TYPE SORTED TABLE OF zps_wbs_yj-wbs_uuid WITH NON-UNIQUE KEY table_line.
    DATA visited      TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH UNIQUE KEY table_line.

    LOOP AT wbs_list INTO DATA(ls_key).
      INSERT ls_key-%tky-WbsUuid INTO TABLE wbs_uuids.
    ENDLOOP.

    IF wbs_uuids IS NOT INITIAL.
      SELECT wbs_uuid FROM zps_wbs_yj
        FOR ALL ENTRIES IN @wbs_uuids
        WHERE wbs_uuid = @wbs_uuids-table_line
        INTO TABLE @active_uuids.
    ENDIF.

    LOOP AT wbs_list INTO DATA(wbs).

      APPEND VALUE #( %tky = wbs-%tky %state_area = 'VALIDATE_WBS_SCOPE' ) TO reported-wbs.

      DATA(lv_blocked) = abap_false.

      " 프로젝트 상태
      READ TABLE projects INTO DATA(ls_prj) WITH KEY ProjectUuid = wbs-ProjectUuid.
      IF sy-subrc <> 0 OR ( ls_prj-Status <> 'CRTD' AND ls_prj-Status <> 'REL' ).
        lv_blocked = abap_true.
      ENDIF.

      " 수정일 때는 자신의 상태도 확인한다.
      IF line_exists( active_uuids[ table_line = wbs-%tky-WbsUuid ] ).
        IF wbs-Status <> 'CRTD' AND wbs-Status <> 'REL'.
          lv_blocked = abap_true.
        ENDIF.
      ENDIF.

      " 부모를 따라 루트까지 올라가며 상위 WBS 상태를 확인한다.
      " 깊이 제한을 두면 더 위의 TECO·CLSD를 놓치므로(BR-09 위반),
      " 방문한 WbsId 집합으로 순환만 감지하고 루트까지 모두 검사한다.
      CLEAR visited.
      DATA(lv_node) = wbs-ParentWbsId.
      WHILE lv_node IS NOT INITIAL.
        IF line_exists( visited[ table_line = lv_node ] ).
          EXIT.
        ENDIF.
        INSERT lv_node INTO TABLE visited.
        READ TABLE all_wbs INTO DATA(ls_anc)
             WITH KEY ProjectUuid = wbs-ProjectUuid
                      WbsId       = lv_node.
        IF sy-subrc <> 0.
          CLEAR lv_node.
        ELSE.
          IF ls_anc-Status <> 'CRTD' AND ls_anc-Status <> 'REL'.
            lv_blocked = abap_true.
          ENDIF.
          lv_node = ls_anc-ParentWbsId.
        ENDIF.
      ENDWHILE.

      IF lv_blocked = abap_true.

        APPEND VALUE #( %tky = wbs-%tky ) TO failed-wbs.

        APPEND VALUE #( %tky        = wbs-%tky
                         %path       = VALUE #( Project-%tky = VALUE #(
                                            ProjectUuid = wbs-ProjectUuid
                                            %is_draft   = wbs-%tky-%is_draft ) )
                         %state_area = 'VALIDATE_WBS_SCOPE'
                         %msg        = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = '완료 또는 종료된 범위는 변경할 수 없습니다.' ) )
               TO reported-wbs.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


CLASS lhc_activity DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    " 권한은 프로젝트(루트)에 위임한다 (authorization dependent by _Project).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Activity RESULT result.

    METHODS setActivityDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Activity~setActivityDefaults.

    METHODS setActivityId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Activity~setActivityId.

    METHODS validateActivityRequired FOR VALIDATE ON SAVE
      IMPORTING keys FOR Activity~validateActivityRequired.

    METHODS validateWorkCenter FOR VALIDATE ON SAVE
      IMPORTING keys FOR Activity~validateWorkCenter.

    METHODS validateEmployee FOR VALIDATE ON SAVE
      IMPORTING keys FOR Activity~validateEmployee.

    METHODS validateActivityDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Activity~validateActivityDates.

    METHODS validateActivityScope FOR VALIDATE ON SAVE
      IMPORTING keys FOR Activity~validateActivityScope.

ENDCLASS.

CLASS lhc_activity IMPLEMENTATION.

  METHOD get_instance_features.

    " BR-09: 프로젝트·직속 WBS·그 상위 WBS 중 TECO·CLSD가 하나라도 있으면
    " Activity를 수정할 수 없다 (등록 차단은 WBS의 %assoc-_Activity에서 처리).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    IF activities IS INITIAL.
      RETURN.
    ENDIF.

    " 직속 WBS (draft 포함)
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(parent_wbs).

    " 소속 프로젝트 상태. 신규 draft에서는 Activity의 ProjectUuid가 아직 비어 있을 수
    " 있으므로 직속 WBS의 to-parent association을 따라 읽는다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid Status )
        WITH CORRESPONDING #( parent_wbs )
      RESULT DATA(projects).

    " 같은 프로젝트의 모든 WBS (상위 체인 추적용, draft 포함)
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    DATA visited TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH UNIQUE KEY table_line.

    LOOP AT activities INTO DATA(activity).

      DATA(lv_locked) = abap_false.

      READ TABLE parent_wbs INTO DATA(ls_wbs) WITH KEY WbsUuid = activity-WbsUuid.

      IF sy-subrc <> 0.
        lv_locked = abap_true.
      ELSE.

        " 직속 WBS 상태
        IF ls_wbs-Status <> 'CRTD' AND ls_wbs-Status <> 'REL'.
          lv_locked = abap_true.
        ENDIF.

        " 프로젝트 상태
        READ TABLE projects INTO DATA(ls_prj) WITH KEY ProjectUuid = ls_wbs-ProjectUuid.
        IF sy-subrc <> 0 OR ( ls_prj-Status <> 'CRTD' AND ls_prj-Status <> 'REL' ).
          lv_locked = abap_true.
        ENDIF.

        " 직속 WBS의 상위 체인을 루트까지 따라간다.
        " 방문한 WbsId 집합으로 순환만 감지하고 깊이 제한은 두지 않는다.
        CLEAR visited.
        DATA(lv_node) = ls_wbs-ParentWbsId.
        WHILE lv_node IS NOT INITIAL.
          IF line_exists( visited[ table_line = lv_node ] ).
            EXIT.
          ENDIF.
          INSERT lv_node INTO TABLE visited.
          READ TABLE all_wbs INTO DATA(ls_anc)
               WITH KEY ProjectUuid = ls_wbs-ProjectUuid
                        WbsId       = lv_node.
          IF sy-subrc <> 0.
            CLEAR lv_node.
          ELSE.
            IF ls_anc-Status <> 'CRTD' AND ls_anc-Status <> 'REL'.
              lv_locked = abap_true.
            ENDIF.
            lv_node = ls_anc-ParentWbsId.
          ENDIF.
        ENDWHILE.

      ENDIF.

      DATA(lv_update) = COND #( WHEN lv_locked = abap_true
                                 THEN if_abap_behv=>fc-o-disabled
                                 ELSE if_abap_behv=>fc-o-enabled ).

      APPEND VALUE #( %tky    = activity-%tky
                       %update = lv_update )
             TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD setActivityDefaults.

    " BR-02: 상태는 직접 입력할 수 없고 생성 시 PLAN으로 설정한다.
    " ProjectUuid는 소속(직속) WBS의 ProjectUuid를 그대로 쓴다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    IF activities IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity BY \_Wbs
        FIELDS ( ProjectUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(parent_wbs).

    DATA lt_update TYPE TABLE FOR UPDATE zr_ps_project_yj\\Activity.

    LOOP AT activities INTO DATA(activity).

      DATA(lv_project_uuid) = activity-ProjectUuid.

      READ TABLE parent_wbs INTO DATA(ls_wbs) WITH KEY WbsUuid = activity-WbsUuid.
      IF sy-subrc = 0.
        lv_project_uuid = ls_wbs-ProjectUuid.
      ENDIF.

      DATA(lv_status) = activity-Status.
      IF lv_status IS INITIAL.
        lv_status = 'PLAN'.
      ENDIF.

      APPEND VALUE #( %tky        = activity-%tky
                       ProjectUuid = lv_project_uuid
                       Status      = lv_status )
             TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        UPDATE FIELDS ( ProjectUuid Status )
        WITH lt_update.

  ENDMETHOD.

  METHOD setActivityId.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( ActivityId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    " 이미 ActivityId가 있어도 그 번호를 활성 테이블의 다른 Activity(다른 UUID)가
    " 먼저 쓰고 있으면 재채번 대상으로 잡는다 (3·4단계와 같은 패턴).
    DATA assigned_ids TYPE SORTED TABLE OF zps_activity_yj-activity_id WITH NON-UNIQUE KEY table_line.

    LOOP AT activities INTO DATA(ls_scan) WHERE ActivityId IS NOT INITIAL.
      INSERT ls_scan-ActivityId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_activity_yj WITH NON-UNIQUE KEY activity_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT activity_id, activity_uuid FROM zps_activity_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE activity_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_acts_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT activities INTO DATA(ls_check).
      IF ls_check-ActivityId IS INITIAL
         OR ( line_exists( lt_active[ activity_id = ls_check-ActivityId ] )
              AND NOT line_exists( lt_active[ activity_id   = ls_check-ActivityId
                                               activity_uuid = ls_check-%tky-ActivityUuid ] ) ).
        has_acts_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_acts_to_update = abap_false.
      RETURN.
    ENDIF.

    " 'ACT'로 시작하는 기존 최대 ActivityId를 조회해 다음 번호부터 채번한다
    " (6단계 테스트 데이터의 'T' 접두어 ID와 섞이지 않도록 접두어를 한정한다).
    " 동시 생성 시 중복 가능성은 Mock-up 범위에서 허용한다
    " (번호 범위 객체는 서버에 없어 사용하지 않음).
    SELECT SINGLE MAX( activity_id ) FROM zps_activity_yj
      WHERE activity_id LIKE 'ACT%'
      INTO @DATA(lv_max_activity_id).

    DATA(lv_next_nr) = COND i( WHEN lv_max_activity_id IS NOT INITIAL
                                THEN lv_max_activity_id+3(7)
                                ELSE 0 ).

    LOOP AT activities INTO DATA(activity).

      CHECK activity-ActivityId IS INITIAL
         OR ( line_exists( lt_active[ activity_id = activity-ActivityId ] )
              AND NOT line_exists( lt_active[ activity_id   = activity-ActivityId
                                               activity_uuid = activity-%tky-ActivityUuid ] ) ).

      lv_next_nr = lv_next_nr + 1.

      DATA(lv_activity_id) = |ACT{ lv_next_nr WIDTH = 7 ALIGN = RIGHT PAD = '0' }|.

      MODIFY ENTITIES OF zr_ps_project_yj IN LOCAL MODE
        ENTITY Activity
          UPDATE FIELDS ( ActivityId )
          WITH VALUE #( ( %tky       = activity-%tky
                           ActivityId = lv_activity_id ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateActivityRequired.

    " CM-01: 이름·작업장·담당자는 필수 (TS-11).
    " 자식 엔터티 메시지는 상위(WBS·프로젝트)를 가리키는 %path가 있어야 UI에 표시된다.
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid ActivityName WorkCenterId EmployeeId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    LOOP AT activities INTO DATA(activity).

      APPEND VALUE #( %tky = activity-%tky %state_area = 'VALIDATE_ACT_REQUIRED' ) TO reported-activity.

      IF activity-ActivityName IS INITIAL OR activity-WorkCenterId IS INITIAL
         OR activity-EmployeeId IS INITIAL.

        APPEND VALUE #( %tky = activity-%tky ) TO failed-activity.

      ENDIF.

      IF activity-ActivityName IS INITIAL.
        APPEND VALUE #( %tky                  = activity-%tky
                         %path                 = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area           = 'VALIDATE_ACT_REQUIRED'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '필수 항목을 입력해주세요.' )
                         %element-ActivityName = if_abap_behv=>mk-on )
               TO reported-activity.
      ENDIF.

      IF activity-WorkCenterId IS INITIAL.
        APPEND VALUE #( %tky                  = activity-%tky
                         %path                 = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area           = 'VALIDATE_ACT_REQUIRED'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '필수 항목을 입력해주세요.' )
                         %element-WorkCenterId = if_abap_behv=>mk-on )
               TO reported-activity.
      ENDIF.

      IF activity-EmployeeId IS INITIAL.
        APPEND VALUE #( %tky                = activity-%tky
                         %path               = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area         = 'VALIDATE_ACT_REQUIRED'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '필수 항목을 입력해주세요.' )
                         %element-EmployeeId = if_abap_behv=>mk-on )
               TO reported-activity.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateWorkCenter.

    " BR-16: 작업장은 마스터에 있는 값만 쓸 수 있다 (CM-02).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid WorkCenterId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    DATA wc_ids   TYPE SORTED TABLE OF zps_wrkctr_yj-work_center_id WITH UNIQUE KEY table_line.
    DATA found_wc TYPE SORTED TABLE OF zps_wrkctr_yj-work_center_id WITH NON-UNIQUE KEY table_line.

    LOOP AT activities INTO DATA(ls_activity) WHERE WorkCenterId IS NOT INITIAL.
      INSERT ls_activity-WorkCenterId INTO TABLE wc_ids.
    ENDLOOP.

    IF wc_ids IS NOT INITIAL.
      SELECT work_center_id FROM zps_wrkctr_yj
        FOR ALL ENTRIES IN @wc_ids
        WHERE work_center_id = @wc_ids-table_line
        INTO TABLE @found_wc.
    ENDIF.

    LOOP AT activities INTO DATA(activity).

      APPEND VALUE #( %tky = activity-%tky %state_area = 'VALIDATE_WORK_CENTER' ) TO reported-activity.

      " 빈 값은 validateActivityRequired(CM-01)에서 처리한다.
      IF activity-WorkCenterId IS NOT INITIAL
         AND NOT line_exists( found_wc[ table_line = activity-WorkCenterId ] ).

        APPEND VALUE #( %tky = activity-%tky ) TO failed-activity.

        APPEND VALUE #( %tky                  = activity-%tky
                         %path                 = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area           = 'VALIDATE_WORK_CENTER'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-WorkCenterId = if_abap_behv=>mk-on )
               TO reported-activity.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateEmployee.

    " BR-16: 담당자는 사원 마스터에 있는 값만 쓸 수 있다 (CM-02).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid EmployeeId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    DATA emp_ids   TYPE SORTED TABLE OF zps_employee_yj-employee_id WITH UNIQUE KEY table_line.
    DATA found_emp TYPE SORTED TABLE OF zps_employee_yj-employee_id WITH NON-UNIQUE KEY table_line.

    LOOP AT activities INTO DATA(ls_activity) WHERE EmployeeId IS NOT INITIAL.
      INSERT ls_activity-EmployeeId INTO TABLE emp_ids.
    ENDLOOP.

    IF emp_ids IS NOT INITIAL.
      SELECT employee_id FROM zps_employee_yj
        FOR ALL ENTRIES IN @emp_ids
        WHERE employee_id = @emp_ids-table_line
        INTO TABLE @found_emp.
    ENDIF.

    LOOP AT activities INTO DATA(activity).

      APPEND VALUE #( %tky = activity-%tky %state_area = 'VALIDATE_EMPLOYEE' ) TO reported-activity.

      IF activity-EmployeeId IS NOT INITIAL
         AND NOT line_exists( found_emp[ table_line = activity-EmployeeId ] ).

        APPEND VALUE #( %tky = activity-%tky ) TO failed-activity.

        APPEND VALUE #( %tky                = activity-%tky
                         %path               = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area         = 'VALIDATE_EMPLOYEE'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-EmployeeId = if_abap_behv=>mk-on )
               TO reported-activity.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateActivityDates.

    " BR-15: 시작일 <= 종료일 (CM-03).
    " 프로젝트 기간을 벗어난 일정은 검증하지 않는다 (ACT-01, TS-11).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid StartDate EndDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    LOOP AT activities INTO DATA(activity).

      APPEND VALUE #( %tky = activity-%tky %state_area = 'VALIDATE_ACT_DATES' ) TO reported-activity.

      IF activity-StartDate IS NOT INITIAL AND activity-EndDate IS NOT INITIAL
         AND activity-StartDate > activity-EndDate.

        APPEND VALUE #( %tky = activity-%tky ) TO failed-activity.

        APPEND VALUE #( %tky               = activity-%tky
                         %path              = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area        = 'VALIDATE_ACT_DATES'
                         %msg               = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = '시작일은 종료일보다 늦을 수 없습니다.' )
                         %element-StartDate = if_abap_behv=>mk-on
                         %element-EndDate   = if_abap_behv=>mk-on )
               TO reported-activity.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateActivityScope.

    " BR-09: 프로젝트, 직속 WBS, 그 WBS의 모든 상위 WBS가 CRTD 또는 REL이어야
    " Activity를 등록·수정할 수 있다 (ACT-M04).
    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity
        FIELDS ( WbsUuid ProjectUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(activities).

    IF activities IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Activity BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(parent_wbs).

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Wbs BY \_Project
        FIELDS ( ProjectUuid Status )
        WITH CORRESPONDING #( parent_wbs )
      RESULT DATA(projects).

    READ ENTITIES OF zr_ps_project_yj IN LOCAL MODE
      ENTITY Project BY \_Wbs
        FIELDS ( ProjectUuid WbsId ParentWbsId Status )
        WITH CORRESPONDING #( projects )
      RESULT DATA(all_wbs).

    DATA visited TYPE SORTED TABLE OF zps_wbs_yj-wbs_id WITH UNIQUE KEY table_line.

    LOOP AT activities INTO DATA(activity).

      APPEND VALUE #( %tky = activity-%tky %state_area = 'VALIDATE_ACT_SCOPE' ) TO reported-activity.

      DATA(lv_blocked) = abap_false.

      READ TABLE parent_wbs INTO DATA(ls_wbs) WITH KEY WbsUuid = activity-WbsUuid.

      IF sy-subrc <> 0.
        lv_blocked = abap_true.
      ELSE.

        " 직속 WBS 상태
        IF ls_wbs-Status <> 'CRTD' AND ls_wbs-Status <> 'REL'.
          lv_blocked = abap_true.
        ENDIF.

        " 프로젝트 상태
        READ TABLE projects INTO DATA(ls_prj) WITH KEY ProjectUuid = ls_wbs-ProjectUuid.
        IF sy-subrc <> 0 OR ( ls_prj-Status <> 'CRTD' AND ls_prj-Status <> 'REL' ).
          lv_blocked = abap_true.
        ENDIF.

        " 직속 WBS의 상위 체인을 루트까지 따라간다.
        CLEAR visited.
        DATA(lv_node) = ls_wbs-ParentWbsId.
        WHILE lv_node IS NOT INITIAL.
          IF line_exists( visited[ table_line = lv_node ] ).
            EXIT.
          ENDIF.
          INSERT lv_node INTO TABLE visited.
          READ TABLE all_wbs INTO DATA(ls_anc)
               WITH KEY ProjectUuid = ls_wbs-ProjectUuid
                        WbsId       = lv_node.
          IF sy-subrc <> 0.
            CLEAR lv_node.
          ELSE.
            IF ls_anc-Status <> 'CRTD' AND ls_anc-Status <> 'REL'.
              lv_blocked = abap_true.
            ENDIF.
            lv_node = ls_anc-ParentWbsId.
          ENDIF.
        ENDWHILE.

      ENDIF.

      IF lv_blocked = abap_true.

        APPEND VALUE #( %tky = activity-%tky ) TO failed-activity.

        APPEND VALUE #( %tky        = activity-%tky
                         %path       = VALUE #(
                             Project-%tky = VALUE #( ProjectUuid = activity-ProjectUuid
                                                     %is_draft   = activity-%tky-%is_draft )
                             Wbs-%tky     = VALUE #( WbsUuid   = activity-WbsUuid
                                                     %is_draft = activity-%tky-%is_draft ) )
                         %state_area = 'VALIDATE_ACT_SCOPE'
                         %msg        = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = '완료 또는 종료된 범위에는 Activity를 등록·수정할 수 없습니다.' ) )
               TO reported-activity.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
