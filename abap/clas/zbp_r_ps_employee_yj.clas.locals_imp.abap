CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR Employee
      RESULT result.

    METHODS setEmployeeId FOR DETERMINE ON SAVE
      IMPORTING keys FOR Employee~setEmployeeId.

    METHODS validateName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateName.

    METHODS validateDepartment FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateDepartment.

    METHODS validatePosition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validatePosition.

ENDCLASS.

CLASS lhc_employee IMPLEMENTATION.

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

  METHOD setEmployeeId.

    READ ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    DELETE employees WHERE EmployeeId IS NOT INITIAL.
    CHECK employees IS NOT INITIAL.

    " 기존 최대 EmployeeId('E' + 9자리 숫자)를 조회해 다음 번호부터 채번한다.
    " 동시 생성 시 같은 최대값을 기준으로 중복 ID가 생길 수 있으나, Mock-up
    " 범위에서는 이 가능성을 허용한다(번호 범위 객체는 서버에 없어 사용하지 않음).
    SELECT SINGLE MAX( employee_id ) FROM zps_employee_yj
      WHERE employee_id LIKE 'E%'
      INTO @DATA(lv_max_employee_id).

    DATA(lv_next_nr) = COND i( WHEN lv_max_employee_id IS NOT INITIAL
                                THEN lv_max_employee_id+1(9)
                                ELSE 0 ).

    LOOP AT employees INTO DATA(employee).

      lv_next_nr = lv_next_nr + 1.

      DATA(lv_employee_id) = |E{ lv_next_nr WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

      MODIFY ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
        ENTITY Employee
          UPDATE FIELDS ( EmployeeId )
          WITH VALUE #( ( %tky        = employee-%tky
                           EmployeeId  = lv_employee_id ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateName.

    READ ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      APPEND VALUE #( %tky = employee-%tky %state_area = 'VALIDATE_NAME' ) TO reported-employee.

      IF employee-EmployeeName IS INITIAL.

        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.

        APPEND VALUE #( %tky                 = employee-%tky
                         %state_area          = 'VALIDATE_NAME'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '필수 항목을 입력해주세요.' )
                         %element-EmployeeName = if_abap_behv=>mk-on )
               TO reported-employee.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateDepartment.

    READ ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
      ENTITY Employee
        FIELDS ( DepartmentCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    DATA department_codes TYPE SORTED TABLE OF zps_dept_yj-code WITH UNIQUE KEY table_line.
    DATA lt_department     TYPE SORTED TABLE OF zps_dept_yj WITH UNIQUE KEY code.

    LOOP AT employees INTO DATA(ls_employee) WHERE DepartmentCode IS NOT INITIAL.
      INSERT ls_employee-DepartmentCode INTO TABLE department_codes.
    ENDLOOP.

    IF department_codes IS NOT INITIAL.
      SELECT * FROM zps_dept_yj
        FOR ALL ENTRIES IN @department_codes
        WHERE code = @department_codes-table_line
        INTO TABLE @lt_department.
    ENDIF.

    LOOP AT employees INTO DATA(employee).

      APPEND VALUE #( %tky = employee-%tky %state_area = 'VALIDATE_DEPARTMENT' ) TO reported-employee.

      IF employee-DepartmentCode IS NOT INITIAL AND NOT line_exists( lt_department[ code = employee-DepartmentCode ] ).

        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.

        APPEND VALUE #( %tky                    = employee-%tky
                         %state_area             = 'VALIDATE_DEPARTMENT'
                         %msg                    = new_message_with_text(
                                                        severity = if_abap_behv_message=>severity-error
                                                        text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-DepartmentCode = if_abap_behv=>mk-on )
               TO reported-employee.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validatePosition.

    READ ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
      ENTITY Employee
        FIELDS ( PositionCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    DATA position_codes TYPE SORTED TABLE OF zps_position_yj-code WITH UNIQUE KEY table_line.
    DATA lt_position     TYPE SORTED TABLE OF zps_position_yj WITH UNIQUE KEY code.

    LOOP AT employees INTO DATA(ls_employee) WHERE PositionCode IS NOT INITIAL.
      INSERT ls_employee-PositionCode INTO TABLE position_codes.
    ENDLOOP.

    IF position_codes IS NOT INITIAL.
      SELECT * FROM zps_position_yj
        FOR ALL ENTRIES IN @position_codes
        WHERE code = @position_codes-table_line
        INTO TABLE @lt_position.
    ENDIF.

    LOOP AT employees INTO DATA(employee).

      APPEND VALUE #( %tky = employee-%tky %state_area = 'VALIDATE_POSITION' ) TO reported-employee.

      IF employee-PositionCode IS NOT INITIAL AND NOT line_exists( lt_position[ code = employee-PositionCode ] ).

        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.

        APPEND VALUE #( %tky                  = employee-%tky
                         %state_area           = 'VALIDATE_POSITION'
                         %msg                  = new_message_with_text(
                                                      severity = if_abap_behv_message=>severity-error
                                                      text     = '유효한 참조 코드를 선택해주세요.' )
                         %element-PositionCode = if_abap_behv=>mk-on )
               TO reported-employee.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
