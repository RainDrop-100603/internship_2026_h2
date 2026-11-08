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

    LOOP AT projects INTO DATA(project).

      DATA(lv_feature) = COND #( WHEN project-Status = 'TECO' OR project-Status = 'CLSD'
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled ).

      APPEND VALUE #( %tky         = project-%tky
                       %update      = lv_feature
                       %action-Edit = lv_feature )
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
