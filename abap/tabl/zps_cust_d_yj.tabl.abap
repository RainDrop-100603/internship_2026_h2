@EndUserText.label : 'Customer Master - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_cust_d_yj {

  key client         : abap.clnt not null;
  key customeruuid   : sysuuid_x16 not null;
  customerid         : abap.char(10);
  customername       : abap.char(80);
  countrycode        : abap.char(4);
  contactperson      : abap.char(40);
  contact            : abap.char(40);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  lastchangedat      : abp_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}