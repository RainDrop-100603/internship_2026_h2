@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '작업장'
define root view entity ZR_PS_WORKCENTER_YJ
  as select from zps_wrkctr_yj
  association [0..1] to ZI_PS_PROCCAT_VH_YJ as _ProcessCategory on $projection.ProcessCategoryCode = _ProcessCategory.Code
{
  key work_center_uuid            as WorkCenterUuid,
      work_center_id              as WorkCenterId,
      work_center_name             as WorkCenterName,
      process_category_code         as ProcessCategoryCode,

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
      _ProcessCategory
}
