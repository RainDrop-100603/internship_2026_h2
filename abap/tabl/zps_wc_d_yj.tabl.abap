@EndUserText.label : 'Work Center Master - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_wc_d_yj {

  key client          : abap.clnt not null;
  key workcenteruuid  : sysuuid_x16 not null;
  workcenterid        : abap.char(10);
  workcentername      : abap.char(80);
  processcategorycode : abap.char(4);
  createdby           : abp_creation_user;
  createdat           : abp_creation_tstmpl;
  lastchangedby       : abp_locinst_lastchange_user;
  locallastchangedat  : abp_locinst_lastchange_tstmpl;
  lastchangedat       : abp_lastchange_tstmpl;
  "%admin"            : include sych_bdl_draft_admin_inc;

}
