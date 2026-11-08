@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '프로젝트'
@Metadata.allowExtensions: true
define root view entity ZC_PS_PROJECT_YJ
  provider contract transactional_query
  as projection on ZR_PS_PROJECT_YJ
{
  key ProjectUuid,
      ProjectId,
      ProjectName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_PRJPROF_VH_YJ', element: 'ProfileCode' } } ]
      @ObjectModel.text.element: ['ProfileName']
      ProfileCode,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_VSLTYPE_VH_YJ', element: 'Code' } } ]
      @ObjectModel.text.element: ['VesselTypeName']
      VesselType,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_EMPLOYEE_VH_YJ', element: 'EmployeeId' } } ]
      @ObjectModel.text.element: ['PmName']
      PmEmployeeId,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_CUSTOMER_VH_YJ', element: 'CustomerId' } } ]
      @ObjectModel.text.element: ['CustomerName']
      CustomerId,

      ContractAmount,
      StartDate,
      EndDate,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_PRJSTAT_VH_YJ', element: 'Code' } } ]
      @ObjectModel.text.element: ['StatusName']
      Status,

      // 코드 필드의 이름 텍스트 (association에서 읽기 전용으로 노출)
      @Semantics.text: true
      _Profile.ProfileName    as ProfileName,

      @Semantics.text: true
      _VesselType.Name        as VesselTypeName,

      @Semantics.text: true
      _Pm.EmployeeName        as PmName,

      @Semantics.text: true
      _Customer.CustomerName  as CustomerName,

      @Semantics.text: true
      _Status.Name            as StatusName,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Associations
      _Profile,
      _VesselType,
      _Pm,
      _Customer,
      _Status
}
