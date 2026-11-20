@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@EndUserText.label: '프로젝트 프로파일 Value Help'
define view entity ZI_PS_PRJPROF_VH_YJ
  as select from zps_prjprof_yj
{
  @ObjectModel.text.element: ['ProfileName']
  key profile_code         as ProfileCode,

  @Semantics.text: true
  @Search.defaultSearchElement: true
  profile_name             as ProfileName,

  description              as Description,
  initial_status           as InitialStatus,
  wbs_template             as WbsTemplate,
  vessel_type_required     as VesselTypeRequired
}
