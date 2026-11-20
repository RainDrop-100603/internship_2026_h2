@EndUserText.label : 'Employee Master - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_emp_d_yj {

  key client         : abap.clnt not null;
  key employeeuuid   : sysuuid_x16 not null;
  employeeid         : abap.char(10);
  employeename       : abap.char(80);
  departmentcode     : abap.char(4);
  positioncode       : abap.char(4);
  contact            : abap.char(40);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  lastchangedat      : abp_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}