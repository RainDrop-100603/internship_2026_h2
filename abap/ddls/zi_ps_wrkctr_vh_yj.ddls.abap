@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '작업장 Value Help'
define view entity ZI_PS_WRKCTR_VH_YJ
  as select from zps_wrkctr_yj
{
  @ObjectModel.text.element: ['WorkCenterName']
  key work_center_id      as WorkCenterId,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  work_center_name         as WorkCenterName,

  process_category_code     as ProcessCategoryCode
}
