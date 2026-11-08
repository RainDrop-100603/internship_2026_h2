@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '자재'
@Metadata.allowExtensions: true
define root view entity ZC_PS_MATERIAL_YJ
  provider contract transactional_query
  as projection on ZR_PS_MATERIAL_YJ
{
  key MaterialUuid,
      MaterialId,
      MaterialName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_PS_MATCAT_VH_YJ', element: 'Code' } } ]
      MaterialCategoryCode,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Associations
      _Category
}
