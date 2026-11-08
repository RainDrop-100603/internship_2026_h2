CLASS lhc_workcenter DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR WorkCenter
      RESULT result.

    METHODS setWorkCenterId FOR DETERMINE ON SAVE
      IMPORTING keys FOR WorkCenter~setWorkCenterId.

    METHODS validateName FOR VALIDATE ON SAVE
      IMPORTING keys FOR WorkCenter~validateName.

    METHODS validateProcessCategory FOR VALIDATE ON SAVE
      IMPORTING keys FOR WorkCenter~validateProcessCategory.

    METHODS validateWorkCenterId FOR VALIDATE ON SAVE
      IMPORTING keys FOR WorkCenter~validateWorkCenterId.

ENDCLASS.

CLASS lhc_workcenter IMPLEMENTATION.

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

  METHOD setWorkCenterId.

    READ ENTITIES OF zr_ps_workcenter_yj IN LOCAL MODE
      ENTITY WorkCenter
        FIELDS ( WorkCenterId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(workcenters).

    " 이미 WorkCenterId가 있어도(draft Prepare 단계에서 미리 채번된 경우 포함)
    " 그 번호를 활성 테이블의 다른 작업장(다른 UUID)이 먼저 쓰고 있다면
    " 재채번 대상으로 잡는다. draft A에 Prepare를 실행해 번호를 미리 부여한 뒤
    " 활성화를 보류하고, 그 사이 작업장 B가 같은 번호로 먼저 활성화되는
    " 시나리오(Prepare → 다른 작업장 저장 → 기존 draft 활성화)에서, A를
    " 활성화할 때 이 determination이 다시 실행되며 충돌을 감지해 재채번한다.
    DATA assigned_ids TYPE SORTED TABLE OF zps_wrkctr_yj-work_center_id WITH NON-UNIQUE KEY table_line.

    LOOP AT workcenters INTO DATA(ls_scan) WHERE WorkCenterId IS NOT INITIAL.
      INSERT ls_scan-WorkCenterId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_wrkctr_yj WITH NON-UNIQUE KEY work_center_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT work_center_id, work_center_uuid FROM zps_wrkctr_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE work_center_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_wc_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT workcenters INTO DATA(ls_check).
      IF ls_check-WorkCenterId IS INITIAL
         OR ( line_exists( lt_active[ work_center_id = ls_check-WorkCenterId ] )
              AND NOT line_exists( lt_active[ work_center_id   = ls_check-WorkCenterId
                                               work_center_uuid = ls_check-%tky-WorkCenterUuid ] ) ).
        has_wc_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_wc_to_update = abap_true.

      " 기존 최대 WorkCenterId('W' + 9자리 숫자)를 조회해 다음 번호부터 채번한다.
      " 동시 생성 시 같은 최대값을 기준으로 중복 ID가 생길 수 있으나, Mock-up
      " 범위에서는 이 가능성을 허용한다(번호 범위 객체는 서버에 없어 사용하지 않음).
      SELECT SINGLE MAX( work_center_id ) FROM zps_wrkctr_yj
        WHERE work_center_id LIKE 'W%'
        INTO @DATA(lv_max_wc_id).

      DATA(lv_next_nr) = COND i( WHEN lv_max_wc_id IS NOT INITIAL
                                  THEN lv_max_wc_id+1(9)
                                  ELSE 0 ).

      LOOP AT workcenters INTO DATA(workcenter).

        CHECK workcenter-WorkCenterId IS INITIAL
           OR ( line_exists( lt_active[ work_center_id = workcenter-WorkCenterId ] )
                AND NOT line_exists( lt_active[ work_center_id   = workcenter-WorkCenterId
                                                 work_center_uuid = workcenter-%tky-WorkCenterUuid ] ) ).

        lv_next_nr = lv_next_nr + 1.

        DATA(lv_wc_id) = |W{ lv_next_nr WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

        MODIFY ENTITIES OF zr_ps_workcenter_yj IN LOCAL MODE
          ENTITY WorkCenter
            UPDATE FIELDS ( WorkCenterId )
            WITH VALUE #( ( %tky         = workcenter-%tky
                             WorkCenterId = lv_wc_id ) ).

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD validateName.

    READ ENTITIES OF zr_ps_workcenter_yj IN LOCAL MODE
      ENTITY WorkCenter
        FIELDS ( WorkCenterName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(workcenters).

    LOOP AT workcenters INTO DATA(workcenter).

      APPEND VALUE #( %tky = workcenter-%tky %state_area = 'VALIDATE_NAME' ) TO reported-workcenter.

      IF workcenter-WorkCenterName IS INITIAL.

        APPEND VALUE #( %tky = workcenter-%tky ) TO failed-workcenter.

        APPEND VALUE #( %tky                   = workcenter-%tky
                         %state_area            = 'VALIDATE_NAME'
                         %msg                   = new_message_with_text(
                                                       severity = if_abap_behv_message=>severity-error
                                                       text     = '필수 항목을 입력해주세요.' )
                         %element-WorkCenterName = if_abap_behv=>mk-on )
               TO reported-workcenter.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateProcessCategory.

    READ ENTITIES OF zr_ps_workcenter_yj IN LOCAL MODE
      ENTITY WorkCenter
        FIELDS ( ProcessCategoryCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(workcenters).

    DATA category_codes TYPE SORTED TABLE OF zps_proccat_yj-code WITH UNIQUE KEY table_line.
    DATA lt_category     TYPE SORTED TABLE OF zps_proccat_yj WITH UNIQUE KEY code.

    LOOP AT workcenters INTO DATA(ls_workcenter) WHERE ProcessCategoryCode IS NOT INITIAL.
      INSERT ls_workcenter-ProcessCategoryCode INTO TABLE category_codes.
    ENDLOOP.

    IF category_codes IS NOT INITIAL.
      SELECT * FROM zps_proccat_yj
        FOR ALL ENTRIES IN @category_codes
        WHERE code = @category_codes-table_line
        INTO TABLE @lt_category.
    ENDIF.

    LOOP AT workcenters INTO DATA(workcenter).

      APPEND VALUE #( %tky = workcenter-%tky %state_area = 'VALIDATE_PROC_CATEGORY' ) TO reported-workcenter.

      IF workcenter-ProcessCategoryCode IS NOT INITIAL AND NOT line_exists( lt_category[ code = workcenter-ProcessCategoryCode ] ).

        APPEND VALUE #( %tky = workcenter-%tky ) TO failed-workcenter.

        APPEND VALUE #( %tky                         = workcenter-%tky
                         %state_area                  = 'VALIDATE_PROC_CATEGORY'
                         %msg                         = new_message_with_text(
                                                             severity = if_abap_behv_message=>severity-error
                                                             text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-ProcessCategoryCode = if_abap_behv=>mk-on )
               TO reported-workcenter.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateWorkCenterId.

    " setWorkCenterId 채번이 실패하면 WorkCenterId가 빈 상태로 남는다.
    " WorkCenterId는 readonly라 사용자가 직접 보완할 수 없으므로, 이 상태로는
    " 저장이 끝나지 않도록 여기서 막는다.
    READ ENTITIES OF zr_ps_workcenter_yj IN LOCAL MODE
      ENTITY WorkCenter
        FIELDS ( WorkCenterId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(workcenters).

    LOOP AT workcenters INTO DATA(workcenter).

      APPEND VALUE #( %tky = workcenter-%tky %state_area = 'VALIDATE_WORK_CENTER_ID' ) TO reported-workcenter.

      IF workcenter-WorkCenterId IS INITIAL.

        APPEND VALUE #( %tky = workcenter-%tky ) TO failed-workcenter.

        APPEND VALUE #( %tky                  = workcenter-%tky
                         %state_area           = 'VALIDATE_WORK_CENTER_ID'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '작업장 ID를 채번하지 못했습니다. 다시 저장해주세요.' )
                         %element-WorkCenterId = if_abap_behv=>mk-on )
               TO reported-workcenter.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
