@EndUserText.label : 'Employee Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_employee_yj {

  key client            : abap.clnt not null;
  key employee_uuid     : sysuuid_x16 not null;
  employee_id           : abap.char(10);
  employee_name         : abap.char(80);
  department_code       : abap.char(4);
  position_code         : abap.char(4);
  contact               : abap.char(40);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;

}