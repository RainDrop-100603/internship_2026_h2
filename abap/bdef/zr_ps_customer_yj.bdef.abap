managed implementation in class zbp_r_ps_customer_yj unique;
strict ( 2 );
with draft;

define behavior for ZR_PS_CUSTOMER_YJ alias Customer
persistent table zps_customer_yj
draft table zps_cust_d_yj
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )

{
  field ( numbering : managed, readonly ) CustomerUuid;
  field ( readonly ) CustomerId, CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt, LastChangedAt;
  field ( mandatory ) CustomerName;

  create;
  update;

  determination setCustomerId on save { create; }

  validation validateName on save { create; field CustomerName; }
  validation validateCountry on save { create; field CountryCode; }

  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { validation validateName; validation validateCountry; }

  mapping for zps_customer_yj corresponding
  {
    CustomerUuid         = customer_uuid;
    CustomerId           = customer_id;
    CustomerName         = customer_name;
    CountryCode          = country_code;
    ContactPerson        = contact_person;
    Contact              = contact;
    CreatedBy            = created_by;
    CreatedAt            = created_at;
    LastChangedBy        = last_changed_by;
    LocalLastChangedAt   = local_last_changed_at;
    LastChangedAt        = last_changed_at;
  }
}
