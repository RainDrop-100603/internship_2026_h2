CLASS lhc_material DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR Material
      RESULT result.

    METHODS setMaterialId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Material~setMaterialId.

    METHODS validateName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateName.

    METHODS validateCategory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateCategory.

    METHODS validateMaterialId FOR VALIDATE ON SAVE
      IMPORTING keys FOR Material~validateMaterialId.

ENDCLASS.

CLASS lhc_material IMPLEMENTATION.

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

  METHOD setMaterialId.

    READ ENTITIES OF zr_ps_material_yj IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    " 이미 MaterialId가 있어도(draft Prepare 단계에서 미리 채번된 경우 포함)
    " 그 번호를 활성 테이블의 다른 자재(다른 UUID)가 먼저 쓰고 있다면
    " 재채번 대상으로 잡는다. draft A에 Prepare를 실행해 번호를 미리 부여한 뒤
    " 활성화를 보류하고, 그 사이 자재 B가 같은 번호로 먼저 활성화되는
    " 시나리오(Prepare → 다른 자재 저장 → 기존 draft 활성화)에서, A를
    " 활성화할 때 이 determination이 다시 실행되며 충돌을 감지해 재채번한다.
    DATA assigned_ids TYPE SORTED TABLE OF zps_material_yj-material_id WITH NON-UNIQUE KEY table_line.

    LOOP AT materials INTO DATA(ls_scan) WHERE MaterialId IS NOT INITIAL.
      INSERT ls_scan-MaterialId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_material_yj WITH NON-UNIQUE KEY material_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT material_id, material_uuid FROM zps_material_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE material_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_materials_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT materials INTO DATA(ls_check).
      IF ls_check-MaterialId IS INITIAL
         OR ( line_exists( lt_active[ material_id = ls_check-MaterialId ] )
              AND NOT line_exists( lt_active[ material_id   = ls_check-MaterialId
                                               material_uuid = ls_check-%tky-MaterialUuid ] ) ).
        has_materials_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_materials_to_update = abap_true.

      " 기존 최대 MaterialId('M' + 9자리 숫자)를 조회해 다음 번호부터 채번한다.
      " 동시 생성 시 같은 최대값을 기준으로 중복 ID가 생길 수 있으나, Mock-up
      " 범위에서는 이 가능성을 허용한다(번호 범위 객체는 서버에 없어 사용하지 않음).
      SELECT SINGLE MAX( material_id ) FROM zps_material_yj
        WHERE material_id LIKE 'M%'
        INTO @DATA(lv_max_material_id).

      DATA(lv_next_nr) = COND i( WHEN lv_max_material_id IS NOT INITIAL
                                  THEN lv_max_material_id+1(9)
                                  ELSE 0 ).

      LOOP AT materials INTO DATA(material).

        CHECK material-MaterialId IS INITIAL
           OR ( line_exists( lt_active[ material_id = material-MaterialId ] )
                AND NOT line_exists( lt_active[ material_id   = material-MaterialId
                                                 material_uuid = material-%tky-MaterialUuid ] ) ).

        lv_next_nr = lv_next_nr + 1.

        DATA(lv_material_id) = |M{ lv_next_nr WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

        MODIFY ENTITIES OF zr_ps_material_yj IN LOCAL MODE
          ENTITY Material
            UPDATE FIELDS ( MaterialId )
            WITH VALUE #( ( %tky        = material-%tky
                             MaterialId  = lv_material_id ) ).

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD validateName.

    READ ENTITIES OF zr_ps_material_yj IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    LOOP AT materials INTO DATA(material).

      APPEND VALUE #( %tky = material-%tky %state_area = 'VALIDATE_NAME' ) TO reported-material.

      IF material-MaterialName IS INITIAL.

        APPEND VALUE #( %tky = material-%tky ) TO failed-material.

        APPEND VALUE #( %tky                 = material-%tky
                         %state_area          = 'VALIDATE_NAME'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '필수 항목을 입력해주세요.' )
                         %element-MaterialName = if_abap_behv=>mk-on )
               TO reported-material.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateCategory.

    READ ENTITIES OF zr_ps_material_yj IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialCategoryCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    DATA category_codes TYPE SORTED TABLE OF zps_matcat_yj-code WITH UNIQUE KEY table_line.
    DATA lt_category     TYPE SORTED TABLE OF zps_matcat_yj WITH UNIQUE KEY code.

    LOOP AT materials INTO DATA(ls_material) WHERE MaterialCategoryCode IS NOT INITIAL.
      INSERT ls_material-MaterialCategoryCode INTO TABLE category_codes.
    ENDLOOP.

    IF category_codes IS NOT INITIAL.
      SELECT * FROM zps_matcat_yj
        FOR ALL ENTRIES IN @category_codes
        WHERE code = @category_codes-table_line
        INTO TABLE @lt_category.
    ENDIF.

    LOOP AT materials INTO DATA(material).

      APPEND VALUE #( %tky = material-%tky %state_area = 'VALIDATE_CATEGORY' ) TO reported-material.

      IF material-MaterialCategoryCode IS NOT INITIAL AND NOT line_exists( lt_category[ code = material-MaterialCategoryCode ] ).

        APPEND VALUE #( %tky = material-%tky ) TO failed-material.

        APPEND VALUE #( %tky                          = material-%tky
                         %state_area                   = 'VALIDATE_CATEGORY'
                         %msg                          = new_message_with_text(
                                                              severity = if_abap_behv_message=>severity-error
                                                              text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-MaterialCategoryCode = if_abap_behv=>mk-on )
               TO reported-material.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateMaterialId.

    " setMaterialId 채번이 실패(번호 범위 미설정/소진 등)하면 MaterialId가 빈 상태로
    " 남는다. MaterialId는 readonly라 사용자가 직접 보완할 수 없으므로, 이 상태로는
    " 저장이 끝나지 않도록 여기서 막는다.
    READ ENTITIES OF zr_ps_material_yj IN LOCAL MODE
      ENTITY Material
        FIELDS ( MaterialId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(materials).

    LOOP AT materials INTO DATA(material).

      APPEND VALUE #( %tky = material-%tky %state_area = 'VALIDATE_MATERIAL_ID' ) TO reported-material.

      IF material-MaterialId IS INITIAL.

        APPEND VALUE #( %tky = material-%tky ) TO failed-material.

        APPEND VALUE #( %tky                 = material-%tky
                         %state_area          = 'VALIDATE_MATERIAL_ID'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '자재 ID를 채번하지 못했습니다. 다시 저장해주세요.' )
                         %element-MaterialId  = if_abap_behv=>mk-on )
               TO reported-material.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
