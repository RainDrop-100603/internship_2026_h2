@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '사원'
define root view entity ZR_PS_EMPLOYEE_YJ
  as select from zps_employee_yj
  association [0..1] to ZI_PS_DEPT_VH_YJ as _Department on $projection.DepartmentCode = _Department.Code
  association [0..1] to ZI_PS_POSITION_VH_YJ as _Position on $projection.PositionCode = _Position.Code
{
  key employee_uuid               as EmployeeUuid,
      employee_id                 as EmployeeId,
      employee_name                as EmployeeName,
      department_code               as DepartmentCode,
      position_code                 as PositionCode,
      contact                       as Contact,

      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at                     as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by                as LastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at          as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                 as LastChangedAt,

      // Associations
      _Department,
      _Position
}
