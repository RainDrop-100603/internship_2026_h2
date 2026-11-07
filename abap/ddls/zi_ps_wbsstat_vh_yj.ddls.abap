@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: 'WBS 상태 Value Help'
define view entity ZI_PS_WBSSTAT_VH_YJ
  as select from zps_wbsstat_yj
{
  @ObjectModel.text.element: ['Name']
  key code   as Code,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  name       as Name,

  remark     as Remark
}
