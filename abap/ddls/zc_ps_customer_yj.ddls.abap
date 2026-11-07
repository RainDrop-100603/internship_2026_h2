@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '고객사'
@Metadata.allowExtensions: true
define view entity ZC_PS_CUSTOMER_YJ
  as projection on ZR_PS_CUSTOMER_YJ
  provider contract transactional_query
{
  key CustomerUuid,
      CustomerId,
      CustomerName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_COUNTRY_VH_YJ', element: 'Code' } } ]
      CountryCode,

      ContactPerson,
      Contact,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Associations
      _Country
}
