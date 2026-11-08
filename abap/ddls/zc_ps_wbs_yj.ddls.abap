@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'WBS'
@Metadata.allowExtensions: true
// BO 프로젝션의 자식 뷰도 루트와 동일하게 transactional_query 계약을 선언해야
// 부모 프로젝션(ZC_PS_PROJECT_YJ)에서 composition child로 redirect할 수 있다.
define view entity ZC_PS_WBS_YJ
  provider contract transactional_query
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
