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

    METHODS validateEmployeeId FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateEmployeeId.

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

    " 이미 EmployeeId가 있어도(draft Prepare 단계에서 미리 채번된 경우 포함)
    " 그 번호를 활성 테이블의 다른 사원(다른 UUID)이 먼저 쓰고 있다면
    " 재채번 대상으로 잡는다. draft A에 Prepare를 실행해 번호를 미리 부여한 뒤
    " 활성화를 보류하고, 그 사이 사원 B가 같은 번호로 먼저 활성화되는
    " 시나리오(Prepare → 다른 사원 저장 → 기존 draft 활성화)에서, A를
    " 활성화할 때 이 determination이 다시 실행되며 충돌을 감지해 재채번한다.
    DATA assigned_ids TYPE SORTED TABLE OF zps_employee_yj-employee_id WITH NON-UNIQUE KEY table_line.

    LOOP AT employees INTO DATA(ls_scan) WHERE EmployeeId IS NOT INITIAL.
      INSERT ls_scan-EmployeeId INTO TABLE assigned_ids.
    ENDLOOP.

    DATA lt_active TYPE SORTED TABLE OF zps_employee_yj WITH NON-UNIQUE KEY employee_id.

    IF assigned_ids IS NOT INITIAL.
      SELECT employee_id, employee_uuid FROM zps_employee_yj
        FOR ALL ENTRIES IN @assigned_ids
        WHERE employee_id = @assigned_ids-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_active.
    ENDIF.

    DATA has_employees_to_update TYPE abap_bool VALUE abap_false.

    LOOP AT employees INTO DATA(ls_check).
      IF ls_check-EmployeeId IS INITIAL
         OR ( line_exists( lt_active[ employee_id = ls_check-EmployeeId ] )
              AND NOT line_exists( lt_active[ employee_id   = ls_check-EmployeeId
                                               employee_uuid = ls_check-%tky-EmployeeUuid ] ) ).
        has_employees_to_update = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF has_employees_to_update = abap_true.

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

        CHECK employee-EmployeeId IS INITIAL
           OR ( line_exists( lt_active[ employee_id = employee-EmployeeId ] )
                AND NOT line_exists( lt_active[ employee_id   = employee-EmployeeId
                                                 employee_uuid = employee-%tky-EmployeeUuid ] ) ).

        lv_next_nr = lv_next_nr + 1.

        DATA(lv_employee_id) = |E{ lv_next_nr WIDTH = 9 ALIGN = RIGHT PAD = '0' }|.

        MODIFY ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
          ENTITY Employee
            UPDATE FIELDS ( EmployeeId )
            WITH VALUE #( ( %tky        = employee-%tky
                             EmployeeId  = lv_employee_id ) ).

      ENDLOOP.

    ENDIF.

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

  METHOD validateEmployeeId.

    " setEmployeeId 채번이 실패(번호 범위 미설정/소진 등)하면 EmployeeId가 빈 상태로
    " 남는다. EmployeeId는 readonly라 사용자가 직접 보완할 수 없으므로, 이 상태로는
    " 저장이 끝나지 않도록 여기서 막는다.
    READ ENTITIES OF zr_ps_employee_yj IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      APPEND VALUE #( %tky = employee-%tky %state_area = 'VALIDATE_EMPLOYEE_ID' ) TO reported-employee.

      IF employee-EmployeeId IS INITIAL.

        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.

        APPEND VALUE #( %tky                 = employee-%tky
                         %state_area          = 'VALIDATE_EMPLOYEE_ID'
                         %msg                 = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = '사원 ID를 채번하지 못했습니다. 다시 저장해주세요.' )
                         %element-EmployeeId  = if_abap_behv=>mk-on )
               TO reported-employee.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
