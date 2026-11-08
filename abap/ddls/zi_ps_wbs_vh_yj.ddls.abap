@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: 'WBS Value Help'
define view entity ZI_PS_WBS_VH_YJ
  as select from zps_wbs_yj
{
      // 내부 키는 화면에 노출하지 않는다 (선택 값은 WbsId).
      @UI.hidden: true
  key wbs_uuid       as WbsUuid,

      @ObjectModel.text.element: ['WbsName']
      wbs_id         as WbsId,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      wbs_name       as WbsName,

      wbs_level      as WbsLevel,

      // 같은 프로젝트의 WBS만 걸러내기 위한 필터 필드 (additionalBinding 대상)
      @UI.hidden: true
      project_uuid   as ProjectUuid
}
