managed implementation in class zbp_r_ps_project_yj unique;
strict ( 2 );
with draft;

define behavior for ZR_PS_PROJECT_YJ alias Project
persistent table zps_project_yj
draft table zps_prj_d_yj
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )

{
  field ( numbering : managed, readonly ) ProjectUuid;
  field ( readonly ) ProjectId, Status, CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt, LastChangedAt;

  // 프로파일·선박 타입은 생성 후 수정 불가 (PRJ-03).
  // draft 시나리오에서는 생성 직후 입력도 UPDATE로 전달되므로 정적 readonly:update를 쓰면
  // 신규 draft에서도 입력이 막힌다. 활성 데이터 유무로 판단하는 동적 필드 제어를 사용한다.
  field ( mandatory : create, features : instance ) ProfileCode;
  field ( features : instance ) VesselType;

  field ( mandatory ) ProjectName, PmEmployeeId, CustomerId, StartDate, EndDate;

  create;
  update ( features : instance );
  internal delete;

  // 프로파일의 Initial Status로 상태 설정 (BR-02)
  determination setInitialStatus on modify { create; }
  // 'PRJ' + 7자리 채번 (BR-17)
  determination setProjectId on save { create; }

  validation validateRequired on save { create; update; field ProjectName, ProfileCode, PmEmployeeId, CustomerId, StartDate, EndDate; }
  validation validateProfile on save { create; field ProfileCode; }
  validation validateVesselType on save { create; field ProfileCode, VesselType; }
  validation validatePm on save { create; update; field PmEmployeeId; }
  validation validateCustomer on save { create; update; field CustomerId; }
  validation validateDates on save { create; update; field StartDate, EndDate; }

  draft action ( features : instance ) Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { determination setProjectId;
                                   validation validateRequired;
                                   validation validateProfile;
                                   validation validateVesselType;
                                   validation validatePm;
                                   validation validateCustomer;
                                   validation validateDates; }

  mapping for zps_project_yj corresponding
  {
    ProjectUuid          = project_uuid;
    ProjectId            = project_id;
    ProjectName          = project_name;
    ProfileCode          = profile_code;
    VesselType           = vessel_type;
    PmEmployeeId         = pm_employee_id;
    CustomerId           = customer_id;
    ContractAmount       = contract_amount;
    StartDate            = start_date;
    EndDate              = end_date;
    Status               = status;
    CreatedBy            = created_by;
    CreatedAt            = created_at;
    LastChangedBy        = last_changed_by;
    LocalLastChangedAt   = local_last_changed_at;
    LastChangedAt        = last_changed_at;
  }
}