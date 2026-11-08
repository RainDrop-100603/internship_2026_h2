@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'WBS'
define view entity ZR_PS_WBS_YJ
  as select from zps_wbs_yj
  association        to parent ZR_PS_PROJECT_YJ as _Project on $projection.ProjectUuid = _Project.ProjectUuid
  association [0..1] to ZI_PS_WBSSTAT_VH_YJ     as _Status  on $projection.Status      = _Status.Code
{
  key wbs_uuid                  as WbsUuid,
      project_uuid              as ProjectUuid,
      wbs_id                    as WbsId,
      wbs_name                  as WbsName,
      parent_wbs_id             as ParentWbsId,
      wbs_level                 as WbsLevel,
      status                    as Status,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at     as LocalLastChangedAt,

      // Associations
      _Project,
      _Status
}
