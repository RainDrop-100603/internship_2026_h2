@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'WBS'
@Metadata.allowExtensions: true
// 자식 프로젝션 뷰(_Project : redirected to parent)에는 provider contract를 선언하지 않는다.
// 계약은 루트 프로젝션(ZC_PS_PROJECT_YJ)에서만 선언한다.
define view entity ZC_PS_WBS_YJ
  as projection on ZR_PS_WBS_YJ
{
  key WbsUuid,
      ProjectUuid,
      WbsId,
      WbsName,

      // 부모는 같은 프로젝트(ProjectUuid)의 저장된 WBS만 선택할 수 있게 한다 (BR-12)
      @Consumption.valueHelpDefinition: [ { entity:            { name: 'ZI_PS_WBS_VH_YJ', element: 'WbsId' },
                                            additionalBinding: [ { localElement: 'ProjectUuid',
                                                                   element:      'ProjectUuid',
                                                                   usage:        #FILTER } ] } ]
      ParentWbsId,

      WbsLevel,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_WBSSTAT_VH_YJ', element: 'Code' } } ]
      @ObjectModel.text.element: ['StatusName']
      Status,

      @Semantics.text: true
      _Status.Name as StatusName,

      LocalLastChangedAt,

      // Compositions / Associations
      _Project : redirected to parent ZC_PS_PROJECT_YJ,
      _Status
}
