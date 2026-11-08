@EndUserText.label : 'Project'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_project_yj {

  key client            : abap.clnt not null;
  key project_uuid      : sysuuid_x16 not null;
  project_id            : abap.char(10);
  project_name          : abap.char(80);
  profile_code          : abap.char(4);
  vessel_type           : abap.char(4);
  pm_employee_id        : abap.char(10);
  customer_id           : abap.char(10);
  contract_amount       : abap.dec(15,2);
  start_date            : abap.dats;
  end_date              : abap.dats;
  status                : abap.char(4);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;

}
