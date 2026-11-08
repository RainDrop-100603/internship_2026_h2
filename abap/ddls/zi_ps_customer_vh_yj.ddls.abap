@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '고객사 Value Help'
define view entity ZI_PS_CUSTOMER_VH_YJ
  as select from zps_customer_yj
{
  @ObjectModel.text.element: ['CustomerName']
  key customer_id        as CustomerId,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  customer_name           as CustomerName,

  country_code            as CountryCode
}
