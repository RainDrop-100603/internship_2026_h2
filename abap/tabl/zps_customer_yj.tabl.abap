@EndUserText.label : 'Customer Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_customer_yj {

  key client                 : abap.clnt not null;
  key customer_uuid          : sysuuid_x16 not null;
  customer_id                : abap.char(10);
  customer_name               : abap.char(80);
  country_code                : abap.char(4);
  contact_person               : abap.char(40);
  contact                      : abap.char(40);
  created_by                   : abp_creation_user;
  created_at                   : abp_creation_tstmpl;
  last_changed_by              : abp_locinst_lastchange_user;
  local_last_changed_at        : abp_locinst_lastchange_tstmpl;
  last_changed_at              : abp_lastchange_tstmpl;

}
