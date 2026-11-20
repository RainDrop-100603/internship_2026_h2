@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Activity'
@Metadata.allowExtensions: true
define view entity ZC_PS_ACTIVITY_YJ
  as projection on ZR_PS_ACTIVITY_YJ
{
  key ActivityUuid,
      WbsUuid,
      ProjectUuid,
      ActivityId,
      ActivityName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_WRKCTR_VH_YJ', element: 'WorkCenterId' } } ]
      @ObjectModel.text.element: ['WorkCenterName']
      WorkCenterId,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_EMPLOYEE_VH_YJ', element: 'EmployeeId' } } ]
      @ObjectModel.text.element: ['EmployeeName']
      EmployeeId,

      StartDate,
      EndDate,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_ACTSTAT_VH_YJ', element: 'Code' } } ]
      @ObjectModel.text.element: ['StatusName']
      Status,

      // 코드 필드의 이름 텍스트 (association에서 읽기 전용으로 노출)
      @Semantics.text: true
      _WorkCenter.WorkCenterName as WorkCenterName,

      @Semantics.text: true
      _Employee.EmployeeName     as EmployeeName,

      @Semantics.text: true
      _Status.Name               as StatusName,

      // BR-10: 직속 WBS의 상태를 조회 시 함께 보여준다 (Activity 테이블에 저장하지 않음).
      _Wbs.Status                as WbsStatus,

      LocalLastChangedAt,

      // Compositions / Associations
      _Wbs     : redirected to parent ZC_PS_WBS_YJ,
      _Project : redirected to ZC_PS_PROJECT_YJ,
      _WorkCenter,
      _Employee,
      _Status
}
