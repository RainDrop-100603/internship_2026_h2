@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '작업장'
@Metadata.allowExtensions: true
define root view entity ZC_PS_WORKCENTER_YJ
  provider contract transactional_query
  as projection on ZR_PS_WORKCENTER_YJ
{
  key WorkCenterUuid,
      WorkCenterId,
      WorkCenterName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_PROCCAT_VH_YJ', element: 'Code' } } ]
      ProcessCategoryCode,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Associations
      _ProcessCategory
}
