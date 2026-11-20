@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '사원 Value Help'
define view entity ZI_PS_EMPLOYEE_VH_YJ
  as select from zps_employee_yj
{
  @ObjectModel.text.element: ['EmployeeName']
  key employee_id       as EmployeeId,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  employee_name          as EmployeeName,

  department_code         as DepartmentCode,

  position_code           as PositionCode
}
