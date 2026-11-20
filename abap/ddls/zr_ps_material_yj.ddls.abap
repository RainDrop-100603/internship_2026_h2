@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '자재'
define root view entity ZR_PS_MATERIAL_YJ
  as select from zps_material_yj
  association [0..1] to ZI_PS_MATCAT_VH_YJ as _Category on $projection.MaterialCategoryCode = _Category.Code
{
  key material_uuid               as MaterialUuid,
      material_id                 as MaterialId,
      material_name                as MaterialName,
      material_category_code        as MaterialCategoryCode,

      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at                     as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by                as LastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at          as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                 as LastChangedAt,

      // Associations
      _Category
}
