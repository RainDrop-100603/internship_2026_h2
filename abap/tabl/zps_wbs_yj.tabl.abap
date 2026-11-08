@EndUserText.label : 'WBS'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_wbs_yj {

  key client            : abap.clnt not null;
  key wbs_uuid          : sysuuid_x16 not null;
  project_uuid          : sysuuid_x16;
  wbs_id                : abap.char(10);
  wbs_name              : abap.char(80);
  parent_wbs_id         : abap.char(10);
  wbs_level             : abap.int2;
  status                : abap.char(4);
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
