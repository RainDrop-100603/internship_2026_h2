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

    DATA has_customers_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT customers INTO DATA(ls_check) WHERE CustomerId IS INITIAL.
      has_customers_to_update = abap_true.
      EXIT.
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

      LOOP AT customers INTO DATA(customer) WHERE CustomerId IS INITIAL.

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
                                                     text     = '번호 범위 채번에 실패하여 저장할 수 없습니다. 번호 범위 설정을 확인해주세요.' )
                         %element-CustomerId  = if_abap_behv=>mk-on )
               TO reported-customer.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


CLASS ltc_customer DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA:
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      class_setup,
      class_teardown.

    METHODS:
      setup,

      validateName_empty_fails      FOR TESTING RAISING cx_static_check,
      validateName_filled_succeeds  FOR TESTING RAISING cx_static_check,
      validateCountry_unknown_fails  FOR TESTING RAISING cx_static_check,
      validateCountry_known_succeeds FOR TESTING RAISING cx_static_check,
      validateCountry_empty_succeeds FOR TESTING RAISING cx_static_check,
      customerId_assigned_on_save    FOR TESTING RAISING cx_static_check,
      customerId_format_and_unique   FOR TESTING RAISING cx_static_check,

      authEdit_requested_is_allowed      FOR TESTING RAISING cx_static_check,
      authEdit_not_requested_unauthorized FOR TESTING RAISING cx_static_check.

ENDCLASS.

" get_global_authorizations가 PRIVATE SECTION에 있어 ltc_customer가 직접 호출할 수 있도록
" 로컬 friend로 선언한다. draft Edit 권한 결과(%action-Edit)는 IN LOCAL MODE EML 호출로는
" 검증되지 않으므로(권한 검사 자체를 우회), 핸들러 메서드를 직접 호출해 검증한다.
CLASS lhc_customer DEFINITION LOCAL FRIENDS ltc_customer.


CLASS ltc_customer IMPLEMENTATION.

  METHOD class_setup.

    cds_test_environment = cl_cds_test_environment=>create( i_for_entity = 'ZR_PS_CUSTOMER_YJ' ).
    cds_test_environment->enable_double_redirection( ).
    sql_test_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZPS_COUNTRY_YJ' ) ) ).

  ENDMETHOD.

  METHOD class_teardown.

    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).

  ENDMETHOD.

  METHOD setup.

    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).

    DATA lt_country TYPE STANDARD TABLE OF zps_country_yj.
    lt_country = VALUE #( ( client = sy-mandt code = 'KR' name = '대한민국' ) ).
    sql_test_environment->insert_test_data( lt_country ).

  ENDMETHOD.

  METHOD validateName_empty_fails.

    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_not_initial( failed_save-customer ).

    cl_abap_unit_assert=>assert_true(
      xsdbool( line_exists( reported_save-customer[ %state_area = 'VALIDATE_NAME'
                                                      %element-CustomerName = if_abap_behv=>mk-on ] ) ) ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD validateName_filled_succeeds.

    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_initial( failed_save-customer ).

    cl_abap_unit_assert=>assert_false(
      xsdbool( line_exists( reported_save-customer[ %state_area = 'VALIDATE_NAME'
                                                      %element-CustomerName = if_abap_behv=>mk-on ] ) ) ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD validateCountry_unknown_fails.

    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사' CountryCode = 'ZZ' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_not_initial( failed_save-customer ).

    cl_abap_unit_assert=>assert_true(
      xsdbool( line_exists( reported_save-customer[ %state_area = 'VALIDATE_COUNTRY'
                                                      %element-CountryCode = if_abap_behv=>mk-on ] ) ) ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD validateCountry_known_succeeds.

    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_initial( failed_save-customer ).

    cl_abap_unit_assert=>assert_false(
      xsdbool( line_exists( reported_save-customer[ %state_area = 'VALIDATE_COUNTRY'
                                                      %element-CountryCode = if_abap_behv=>mk-on ] ) ) ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD validateCountry_empty_succeeds.

    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사' CountryCode = '' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_initial( failed_save-customer ).

    cl_abap_unit_assert=>assert_false(
      xsdbool( line_exists( reported_save-customer[ %state_area = 'VALIDATE_COUNTRY'
                                                      %element-CountryCode = if_abap_behv=>mk-on ] ) ) ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD customerId_assigned_on_save.

    " setCustomerId(번호 범위 채번)가 정상 동작하고, validateCustomerId가 채번된
    " 결과를 막지 않는지 함께 검증한다. 번호 범위 채번이 실패하면 save 자체가
    " failed_save-customer로 막히므로(validateCustomerId), 이 테스트가 통과하면
    " 두 로직이 함께 정상 동작함을 보장한다.
    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_initial( failed_save-customer ).

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH CORRESPONDING #( mapped-customer )
      RESULT DATA(customers).

    cl_abap_unit_assert=>assert_not_initial( customers ).
    cl_abap_unit_assert=>assert_not_initial( customers[ 1 ]-CustomerId ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD customerId_format_and_unique.

    " 연속으로 생성한 두 고객사의 CustomerId가 'C' + 9자리 숫자 형식이고,
    " 서로 다른 값으로 채번되는지 검증한다(C000000000 중복 회귀 방지).
    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'C1' CustomerName = '테스트 고객사 1' CountryCode = 'KR' )
                       ( %cid = 'C2' CustomerName = '테스트 고객사 2' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

    COMMIT ENTITIES
      RESPONSE OF zr_ps_customer_yj
      FAILED   DATA(failed_save)
      REPORTED DATA(reported_save).

    cl_abap_unit_assert=>assert_initial( failed_save-customer ).

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH CORRESPONDING #( mapped-customer )
      RESULT DATA(customers).

    cl_abap_unit_assert=>assert_equals( act = lines( customers ) exp = 2 ).

    LOOP AT customers INTO DATA(customer).
      cl_abap_unit_assert=>assert_equals( act = strlen( customer-CustomerId ) exp = 10 ).
      cl_abap_unit_assert=>assert_char_cp( act = customer-CustomerId exp = 'C*' ).
      cl_abap_unit_assert=>assert_true( xsdbool( customer-CustomerId+1(9) CO '0123456789' ) ).
      cl_abap_unit_assert=>assert_differs( act = customer-CustomerId exp = 'C000000000' ).
    ENDLOOP.

    cl_abap_unit_assert=>assert_differs( act = customers[ 1 ]-CustomerId exp = customers[ 2 ]-CustomerId ).

    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD authEdit_requested_is_allowed.

    " Edit 요청이 있으면(%action-Edit = mk-on) 결과도 allowed여야 한다(기존 고객사 편집 가능).
    DATA requested_authorizations TYPE STRUCTURE FOR GLOBAL AUTHORIZATION REQUEST zr_ps_customer_yj.
    DATA result                   TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT zr_ps_customer_yj.

    requested_authorizations-%action-Edit = if_abap_behv=>mk-on.

    NEW lhc_customer( )->get_global_authorizations(
      EXPORTING requested_authorizations = requested_authorizations
      CHANGING  result                   = result ).

    cl_abap_unit_assert=>assert_equals( act = result-%action-Edit exp = if_abap_behv=>auth-allowed ).

  ENDMETHOD.

  METHOD authEdit_not_requested_unauthorized.

    " Edit 요청이 없으면(%action-Edit 미설정) 결과는 unauthorized로 남아야 한다.
    DATA requested_authorizations TYPE STRUCTURE FOR GLOBAL AUTHORIZATION REQUEST zr_ps_customer_yj.
    DATA result                   TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT zr_ps_customer_yj.

    NEW lhc_customer( )->get_global_authorizations(
      EXPORTING requested_authorizations = requested_authorizations
      CHANGING  result                   = result ).

    cl_abap_unit_assert=>assert_equals( act = result-%action-Edit exp = if_abap_behv=>auth-unauthorized ).

  ENDMETHOD.

ENDCLASS.
