@EndUserText.label : 'Project Profile Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_prjprof_yj {
  key client            : abap.clnt not null;
  key profile_code       : abap.char(4) not null;
  profile_name          : abap.char(40);
  description           : abap.char(60);
  initial_status        : abap.char(4);
  wbs_template          : abap.char(10);
  vessel_type_required  : abap_boolean;

}
