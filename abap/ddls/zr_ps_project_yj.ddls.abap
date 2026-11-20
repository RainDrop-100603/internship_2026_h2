@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '프로젝트'
define root view entity ZR_PS_PROJECT_YJ
  as select from zps_project_yj
  composition [0..*] of ZR_PS_WBS_YJ         as _Wbs
  association [0..1] to ZI_PS_PRJPROF_VH_YJ  as _Profile    on $projection.ProfileCode  = _Profile.ProfileCode
  association [0..1] to ZI_PS_VSLTYPE_VH_YJ  as _VesselType on $projection.VesselType   = _VesselType.Code
  association [0..1] to ZI_PS_EMPLOYEE_VH_YJ as _Pm         on $projection.PmEmployeeId = _Pm.EmployeeId
  association [0..1] to ZI_PS_CUSTOMER_VH_YJ as _Customer   on $projection.CustomerId   = _Customer.CustomerId
  association [0..1] to ZI_PS_PRJSTAT_VH_YJ  as _Status     on $projection.Status       = _Status.Code
{
  key project_uuid                as ProjectUuid,
      project_id                  as ProjectId,
      project_name                as ProjectName,
      profile_code                as ProfileCode,
      vessel_type                 as VesselType,
      pm_employee_id              as PmEmployeeId,
      customer_id                 as CustomerId,
      contract_amount             as ContractAmount,
      start_date                  as StartDate,
      end_date                    as EndDate,
      status                      as Status,

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

      // Compositions / Associations
      _Wbs,
      _Profile,
      _VesselType,
      _Pm,
      _Customer,
      _Status
}
