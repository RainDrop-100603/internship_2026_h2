@EndUserText.label : 'Customer Master - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_cust_d_yj {

  key client                 : abap.clnt not null;
  key CustomerUuid           : sysuuid_x16 not null;
  CustomerId                 : abap.char(10);
  CustomerName                : abap.char(80);
  CountryCode                 : abap.char(4);
  ContactPerson                : abap.char(40);
  Contact                       : abap.char(40);
  CreatedBy                     : abp_creation_user;
  CreatedAt                     : abp_creation_tstmpl;
  LastChangedBy                 : abp_locinst_lastchange_user;
  LocalLastChangedAt            : abp_locinst_lastchange_tstmpl;
  LastChangedAt                 : abp_lastchange_tstmpl;

  "%admin" : include sych_bdl_draft_admin_inc;

}
