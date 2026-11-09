@EndUserText.label : 'Activity - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_act_d_yj {

  key client         : abap.clnt not null;
  key activityuuid   : sysuuid_x16 not null;
  wbsuuid            : sysuuid_x16;
  projectuuid        : sysuuid_x16;
  activityid         : abap.char(10);
  activityname       : abap.char(80);
  workcenterid       : abap.char(10);
  employeeid         : abap.char(10);
  startdate          : abap.dats;
  enddate            : abap.dats;
  status             : abap.char(4);
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}
