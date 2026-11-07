@EndUserText.label : 'Position Code Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zps_position_yj {

  key client : abap.clnt not null;
  key code   : abap.char(4) not null;
  name       : abap.char(40);
  remark     : abap.char(60);

}