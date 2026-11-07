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
      customerId_reassigned_on_conflict FOR TESTING RAISING cx_static_check,

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

  METHOD customerId_reassigned_on_conflict.

    " 리뷰 지적 재현: draft A에 Prepare를 실행해 번호를 미리 부여한 뒤
    " 활성화를 보류하고, 그 사이 고객사 B가 같은 번호로 먼저 활성화되면
    " A를 최종 활성화(= 다시 SAVE determination 실행)할 때 재채번되어야 한다.
    " (https://help.sap.com/docs/abap-cloud/abap-rap/preparing-draft-instances-for-activation
    "  에 따르면 Prepare 단계에서도 on-save determination이 실행된다.)
    " B의 활성화는 A와 다른 LUW에서 일어나므로, 여기서는 활성 테이블 더블에
    " 직접 레코드를 넣어 "B가 이미 저장됨"을 모사한다.

    " 1) draft A 생성 (아직 활성 테이블에는 없음).
    MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        CREATE FIELDS ( CustomerName CountryCode )
        WITH VALUE #( ( %cid = 'A' CustomerName = '고객사 A' CountryCode = 'KR' ) )
      MAPPED   DATA(mapped_a)
      FAILED   DATA(failed_a)
      REPORTED DATA(reported_a).

    cl_abap_unit_assert=>assert_initial( failed_a-customer ).

    DATA(tky_a) = mapped_a-customer[ 1 ]-%tky.

    DATA keys_a TYPE TABLE FOR DETERMINATION zr_ps_customer_yj\\Customer~setCustomerId.
    keys_a = VALUE #( ( %tky = tky_a ) ).

    " 2) Prepare 단계를 모사: determination을 직접 실행해 A에 번호를 미리
    "    부여한다(활성 테이블이 비어 있으므로 'C000000001').
    NEW lhc_customer( )->setCustomerId( keys = keys_a ).

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH VALUE #( ( %tky = tky_a ) )
      RESULT DATA(customers_preview).

    DATA(customer_id_preview) = customers_preview[ 1 ]-CustomerId.

    cl_abap_unit_assert=>assert_equals( act = customer_id_preview exp = 'C000000001' ).

    " 3) 고객사 B가 같은 번호로 먼저 활성화된 상태를 모사: 활성 테이블(CDS 더블,
    "    enable_double_redirection으로 zps_customer_yj에 대한 일반 SELECT와도
    "    공유된다)에 직접 충돌 레코드를 추가한다(A의 draft와는 별개로 이미
    "    저장된 것으로 간주).
    DATA lt_conflict TYPE STANDARD TABLE OF zps_customer_yj.
    lt_conflict = VALUE #( ( client        = sy-mandt
                              customer_uuid = cl_system_uuid=>create_uuid_x16_static( )
                              customer_id   = customer_id_preview
                              customer_name = '고객사 B' ) ).
    cds_test_environment->insert_test_data( i_data = lt_conflict ).

    " 4) A를 최종 활성화하는 상황을 모사: determination을 다시 실행한다. 이제
    "    활성 테이블에 다른 UUID가 같은 번호를 쓰고 있으므로 재채번되어야 한다
    "    (수정 전에는 CustomerId가 이미 채워져 있어 재채번 로직을 건너뛰고
    "    중복이 그대로 남았다).
    NEW lhc_customer( )->setCustomerId( keys = keys_a ).

    READ ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
      ENTITY Customer
        FIELDS ( CustomerId )
        WITH VALUE #( ( %tky = tky_a ) )
      RESULT DATA(customers_final).

    DATA(customer_id_final) = customers_final[ 1 ]-CustomerId.

    cl_abap_unit_assert=>assert_not_initial( customer_id_final ).
    cl_abap_unit_assert=>assert_differs( act = customer_id_final exp = customer_id_preview ).

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
