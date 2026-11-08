@EndUserText.label : 'Material Master - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_mat_d_yj {

  key client           : abap.clnt not null;
  key materialuuid     : sysuuid_x16 not null;
  materialid           : abap.char(10);
  materialname         : abap.char(80);
  materialcategorycode : abap.char(4);
  createdby            : abp_creation_user;
  createdat            : abp_creation_tstmpl;
  lastchangedby        : abp_locinst_lastchange_user;
  locallastchangedat   : abp_locinst_lastchange_tstmpl;
  lastchangedat        : abp_lastchange_tstmpl;
  "%admin"             : include sych_bdl_draft_admin_inc;

}