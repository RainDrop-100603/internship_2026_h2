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

ENDCLASS.

CLASS lhc_customer IMPLEMENTATION.

  METHOD get_global_authorizations.

    result-%create = COND #( WHEN requested_authorizations-%create = if_abap_behv=>mk-on
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

    result-%update = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

    result-%delete = if_abap_behv=>auth-unauthorized.

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

      " 번호 범위 객체(NR_RANGE_NR '01', OBJECT 'ZCUSTNR_YJ')로 채번을 직렬화한다.
      " MAX(customer_id)+1 방식은 동시 생성 시 중복 ID가 발생할 수 있어 사용하지 않는다.
      " 번호 범위 객체는 파일로 만들 수 없으므로 SNRO에서 사전 생성되어 있어야 한다
      " (object ZCUSTNR_YJ, 구간 01, 자릿수 9, 1 ~ 999999999).
      LOOP AT customers INTO DATA(customer) WHERE CustomerId IS INITIAL.

        TRY.
            DATA(lv_next_nr) = cl_numberrange_runtime=>number_get_next(
                                    nr_range_nr = '01'
                                    object      = 'ZCUSTNR_YJ' ).
          CATCH cx_number_ranges.
            CONTINUE.
        ENDTRY.

        DATA(lv_customer_id) = |C{ lv_next_nr+0(9) }|.

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
      validateCountry_empty_succeeds FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_customer IMPLEMENTATION.

  METHOD class_setup.

    cds_test_environment = cl_cds_test_environment=>create( i_for_entity = 'ZR_PS_CUSTOMER_YJ' ).
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

ENDCLASS.
