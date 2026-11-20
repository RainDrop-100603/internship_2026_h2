@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '고객사'
define root view entity ZR_PS_CUSTOMER_YJ
  as select from zps_customer_yj
  association [0..1] to ZI_PS_COUNTRY_VH_YJ as _Country on $projection.CountryCode = _Country.Code
{
  key customer_uuid               as CustomerUuid,
      customer_id                 as CustomerId,
      customer_name                as CustomerName,
      country_code                 as CountryCode,
      contact_person                as ContactPerson,
      contact                       as Contact,

      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at                     as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by                as LastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at          as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                 as LastChangedAt,

      // Associations
      _Country
}
