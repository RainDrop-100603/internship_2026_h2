@EndUserText.label : 'Material Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_material_yj {

  key client             : abap.clnt not null;
  key material_uuid      : sysuuid_x16 not null;
  material_id            : abap.char(10);
  material_name          : abap.char(80);
  material_category_code : abap.char(4);
  created_by             : abp_creation_user;
  created_at             : abp_creation_tstmpl;
  last_changed_by        : abp_locinst_lastchange_user;
  local_last_changed_at  : abp_locinst_lastchange_tstmpl;
  last_changed_at        : abp_lastchange_tstmpl;

}