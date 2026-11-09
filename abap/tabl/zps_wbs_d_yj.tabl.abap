@EndUserText.label : 'WBS - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_wbs_d_yj {

  key client         : abap.clnt not null;
  key wbsuuid        : sysuuid_x16 not null;
  projectuuid        : sysuuid_x16;
  wbsid              : abap.char(10);
  wbsname            : abap.char(80);
  parentwbsid        : abap.char(10);
  wbslevel           : abap.int2;
  status             : abap.char(4);
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}