CLASS lhc_customer DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR Customer
      RESULT result.

    METHODS setCustomerId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Customer~setCustomerId.

    METHODS validateName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Customer~validateName.

    METHODS validateCountry FOR VALIDATE ON SAVE
      IMPORTING keys FOR Customer~validateCountry.

    METHODS validateCustomerId FOR VALIDATE ON SAVE
      IMPORTING keys FOR Customer~validateCustomerId.

ENDCLASS.

CLASS lhc_customer IMPLEMENTATION.

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

  METHOD setCustomerId.

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(customers).

    " 이미 CustomerId가 있어도(draft Prepare 단계에서 미리 채번된 경우 포함)
    " 그 번호를 활성 테이블의 다른 고객사(다른 UUID)가 먼저 쓰고 있다면
    " 재채번 대상으로 잡는다. draft A에 Prepare를 실행해 번호를 미리 부여한 뒤
    " 활성화를 보류하고, 그 사이 고객사 B가 같은 번호로 먼저 활성화되는
    " 시나리오(Prepare → 다른 고객사 저장 → 기존 draft 활성화)에서, A를
    " 활성화할 때 이 determination이 다시 실행되며 충돌을 감지해 재채번한다.
    DATA assigned_ids TYPE SORTED TABLE OF zps_customer_yj-customer_id WITH NON-UNIQUE KEY table_line.

    LOOP AT customers INTO DATA(ls_scan) WHERE CustomerId IS NOT INITIAL.
      INSERT ls_scan-CustomerId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_customer_yj WITH NON-UNIQUE KEY customer_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT customer_id, customer_uuid FROM zps_customer_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE customer_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_customers_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT customers INTO DATA(ls_check).
      IF ls_check-CustomerId IS INITIAL
         OR ( line_exists( lt_active[ customer_id = ls_check-CustomerId ] )
              AND NOT line_exists( lt_active[ customer_id   = ls_check-CustomerId
                                               customer_uuid = ls_check-%tky-CustomerUuid ] ) ).
        has_customers_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_customers_to_update = abap_true.

      " 기존 최대 CustomerId('C' + 9자리 숫자)를 조회해 다음 번호부터 채번한다.
      " 동시 생성 시 같은 최대값을 기준으로 중복 ID가 생길 수 있으나, Mock-up
      " 범위에서는 이 가능성을 허용한다(번호 범위 객체는 서버에 없어 사용하지 않음).
      SELECT SINGLE MAX( customer_id ) FROM zps_customer_yj
        WHERE customer_id LIKE 'C%'
        INTO @DATA(lv_max_customer_id).

      DATA(lv_next_nr) = COND i( WHEN lv_max_customer_id IS NOT INITIAL
                                  THEN lv_max_customer_id+1(9)
                                  ELSE 0 ).

      LOOP AT customers INTO DATA(customer).

        CHECK customer-CustomerId IS INITIAL
           OR ( line_exists( lt_active[ customer_id = customer-CustomerId ] )
                AND NOT line_exists( lt_active[ customer_id   = customer-CustomerId
                                                 customer_uuid = customer-%tky-CustomerUuid ] ) ).

        lv_next_nr = lv_next_nr + 1.

        DATA(lv_customer_id) = |C{ lv_next_nr WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

        MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
          ENTITY Customer
            UPDATE FIELDS ( CustomerId )
            WITH VALUE #( ( %tky        = customer-%tky
                             CustomerId  = lv_customer_id ) ).

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD validateName.

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(customers).

    LOOP AT customers INTO DATA(customer).

      APPEND VALUE #( %tky = customer-%tky %state_area = 'VALIDATE_NAME' ) TO reported-customer.

      IF customer-CustomerName IS INITIAL.

        APPEND VALUE #( %tky = customer-%tky ) TO failed-customer.

        APPEND VALUE #( %tky                 = customer-%tky
                         %state_area          = 'VALIDATE_NAME'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '필수 항목을 입력해주세요.' )
                         %element-CustomerName = if_abap_behv=>mk-on )
               TO reported-customer.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateCountry.

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CountryCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(customers).

    DATA country_codes TYPE SORTED TABLE OF zps_country_yj-code WITH UNIQUE KEY table_line.
    DATA lt_country     TYPE SORTED TABLE OF zps_country_yj WITH UNIQUE KEY code.

    LOOP AT customers INTO DATA(ls_customer) WHERE CountryCode IS NOT INITIAL.
      INSERT ls_customer-CountryCode INTO TABLE country_codes.
    ENDLOOP.

    IF country_codes IS NOT INITIAL.
      SELECT * FROM zps_country_yj
        FOR ALL ENTRIES IN @country_codes
        WHERE code = @country_codes-table_line
        INTO TABLE @lt_country.
    ENDIF.

    LOOP AT customers INTO DATA(customer).

      APPEND VALUE #( %tky = customer-%tky %state_area = 'VALIDATE_COUNTRY' ) TO reported-customer.

      IF customer-CountryCode IS NOT INITIAL AND NOT line_exists( lt_country[ code = customer-CountryCode ] ).

        APPEND VALUE #( %tky = customer-%tky ) TO failed-customer.

        APPEND VALUE #( %tky                = customer-%tky
                         %state_area         = 'VALIDATE_COUNTRY'
                         %msg                = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-error
                                                    text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-CountryCode = if_abap_behv=>mk-on )
               TO reported-customer.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateCustomerId.

    " setCustomerId 채번이 실패(번호 범위 미설정/소진 등)하면 CustomerId가 빈 상태로
    " 남는다. CustomerId는 readonly라 사용자가 직접 보완할 수 없으므로, 이 상태로는
    " 저장이 끝나지 않도록 여기서 막는다.
    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(customers).

    LOOP AT customers INTO DATA(customer).

      APPEND VALUE #( %tky = customer-%tky %state_area = 'VALIDATE_CUSTOMER_ID' ) TO reported-customer.

      IF customer-CustomerId IS INITIAL.

        APPEND VALUE #( %tky = customer-%tky ) TO failed-customer.

        APPEND VALUE #( %tky                 = customer-%tky
                         %state_area          = 'VALIDATE_CUSTOMER_ID'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '고객사 ID를 채번하지 못했습니다. 다시 저장해주세요.' )
                         %element-CustomerId  = if_abap_behv=>mk-on )
               TO reported-customer.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
