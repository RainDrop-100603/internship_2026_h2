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
                              THEN cl_abap_behv=>flag-on
                              ELSE cl_abap_behv=>flag-off ).

    result-%update = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                              THEN cl_abap_behv=>flag-on
                              ELSE cl_abap_behv=>flag-off ).

    result-%delete = cl_abap_behv=>flag-off.

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

      SELECT SINGLE FROM zps_customer_yj
        FIELDS MAX( customer_id ) AS customer_id
        INTO @DATA(lv_max_id).

      DATA(lv_next) = COND int8( WHEN lv_max_id IS INITIAL
                                  THEN 1
                                  ELSE CONV int8( lv_max_id+1(9) ) + 1 ).

      LOOP AT customers INTO DATA(customer) WHERE CustomerId IS INITIAL.

        DATA(lv_customer_id) = |C{ lv_next WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

        MODIFY ENTITIES OF zr_ps_customer_yj IN LOCAL MODE
          ENTITY Customer
            UPDATE FIELDS ( CustomerId )
            WITH VALUE #( ( %tky        = customer-%tky
                             CustomerId  = lv_customer_id ) ).

        lv_next = lv_next + 1.

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

      APPEND VALUE #( %tky = customer-%tky ) TO reported-customer.

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

      APPEND VALUE #( %tky = customer-%tky ) TO reported-customer.

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
