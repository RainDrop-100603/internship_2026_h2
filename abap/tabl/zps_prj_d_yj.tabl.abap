@EndUserText.label : 'Project - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_prj_d_yj {

  key client         : abap.clnt not null;
  key projectuuid    : sysuuid_x16 not null;
  projectid          : abap.char(10);
  projectname        : abap.char(80);
  profilecode        : abap.char(4);
  vesseltype         : abap.char(4);
  pmemployeeid       : abap.char(10);
  customerid         : abap.char(10);
  contractamount     : abap.dec(15,2);
  startdate          : abap.dats;
  enddate            : abap.dats;
  status             : abap.char(4);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  lastchangedat      : abp_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}