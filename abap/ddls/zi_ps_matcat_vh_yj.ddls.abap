@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '자재 분류 Value Help'
define view entity ZI_PS_MATCAT_VH_YJ
  as select from zps_matcat_yj
{
  @ObjectModel.text.element: ['Name']
  key code   as Code,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  name       as Name,

  remark     as Remark
}
