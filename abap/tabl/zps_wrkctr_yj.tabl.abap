@EndUserText.label : 'Work Center Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_wrkctr_yj {

  key client            : abap.clnt not null;
  key work_center_uuid  : sysuuid_x16 not null;
  work_center_id        : abap.char(10);
  work_center_name      : abap.char(80);
  process_category_code : abap.char(4);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;

}
