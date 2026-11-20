@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Activity'
define view entity ZR_PS_ACTIVITY_YJ
  as select from zps_activity_yj
  association        to parent ZR_PS_WBS_YJ  as _Wbs        on  $projection.WbsUuid      = _Wbs.WbsUuid
  association [1..1] to ZR_PS_PROJECT_YJ     as _Project    on  $projection.ProjectUuid  = _Project.ProjectUuid
  association [0..1] to ZI_PS_WRKCTR_VH_YJ   as _WorkCenter on  $projection.WorkCenterId = _WorkCenter.WorkCenterId
  association [0..1] to ZI_PS_EMPLOYEE_VH_YJ as _Employee   on  $projection.EmployeeId   = _Employee.EmployeeId
  association [0..1] to ZI_PS_ACTSTAT_VH_YJ  as _Status     on  $projection.Status       = _Status.Code
{
  key activity_uuid             as ActivityUuid,
      wbs_uuid                  as WbsUuid,
      project_uuid              as ProjectUuid,
      activity_id               as ActivityId,
      activity_name             as ActivityName,
      work_center_id            as WorkCenterId,
      employee_id               as EmployeeId,
      start_date                as StartDate,
      end_date                  as EndDate,
      status                    as Status,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at     as LocalLastChangedAt,

      // Associations
      _Wbs,
      _Project,
      _WorkCenter,
      _Employee,
      _Status
}
