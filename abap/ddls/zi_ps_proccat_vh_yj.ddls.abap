@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '공정 분류 Value Help'
define view entity ZI_PS_PROCCAT_VH_YJ
  as select from zps_proccat_yj
{
  @ObjectModel.text.element: ['Name']
  key code   as Code,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  name       as Name,

  remark     as Remark
}
