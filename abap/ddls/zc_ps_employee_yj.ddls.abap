@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '사원'
@Metadata.allowExtensions: true
define root view entity ZC_PS_EMPLOYEE_YJ
  provider contract transactional_query
  as projection on ZR_PS_EMPLOYEE_YJ
{
  key EmployeeUuid,
      EmployeeId,
      EmployeeName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_DEPT_VH_YJ', element: 'Code' } } ]
      DepartmentCode,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_POSITION_VH_YJ', element: 'Code' } } ]
      PositionCode,

      Contact,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Associations
      _Department,
      _Position
}
