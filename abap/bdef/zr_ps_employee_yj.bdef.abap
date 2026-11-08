managed implementation in class zbp_r_ps_employee_yj unique;
strict ( 2 );
with draft;

define behavior for ZR_PS_EMPLOYEE_YJ alias Employee
persistent table zps_employee_yj
draft table zps_emp_d_yj
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )

{
  field ( numbering : managed, readonly ) EmployeeUuid;
  field ( readonly ) EmployeeId, CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt, LastChangedAt;
  field ( mandatory ) EmployeeName;

  create;
  update;
  internal delete;

  determination setEmployeeId on save { create; }

  validation validateName on save { create; field EmployeeName; }
  validation validateDepartment on save { create; field DepartmentCode; }
  validation validatePosition on save { create; field PositionCode; }
  validation validateEmployeeId on save { create; field EmployeeId; }

  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { determination setEmployeeId; validation validateName; validation validateDepartment; validation validatePosition; validation validateEmployeeId; }

  mapping for zps_employee_yj corresponding
  {
    EmployeeUuid         = employee_uuid;
    EmployeeId           = employee_id;
    EmployeeName         = employee_name;
    DepartmentCode       = department_code;
    PositionCode         = position_code;
    Contact              = contact;
    CreatedBy            = created_by;
    CreatedAt            = created_at;
    LastChangedBy        = last_changed_by;
    LocalLastChangedAt   = local_last_changed_at;
    LastChangedAt        = last_changed_at;
  }
}