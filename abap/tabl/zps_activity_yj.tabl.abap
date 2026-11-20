@EndUserText.label : 'Activity'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_activity_yj {

  key client            : abap.clnt not null;
  key activity_uuid     : sysuuid_x16 not null;
  wbs_uuid              : sysuuid_x16;
  project_uuid          : sysuuid_x16;
  activity_id           : abap.char(10);
  activity_name         : abap.char(80);
  work_center_id        : abap.char(10);
  employee_id           : abap.char(10);
  start_date            : abap.dats;
  end_date              : abap.dats;
  status                : abap.char(4);
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}