@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '선종 Value Help'
define view entity ZI_PS_VSLTYPE_VH_YJ
  as select from zps_vsltype_yj
{
  @ObjectModel.text.element: ['Name']
  key code   as Code,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  name       as Name,

  remark     as Remark
}
