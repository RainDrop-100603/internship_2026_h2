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

  // WBS는 프로젝트와 같은 draft·lock 단위로 묶인다. TECO·CLSD 프로젝트에서는
  // 하위 WBS 등록을 막으므로 create를 인스턴스 기능 제어로 둔다 (BR-09).
  association _Wbs { create ( features : instance ); with draft; }

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
                                   validation validateDates;
                                   validation Wbs~validateWbsName;
                                   validation Wbs~validateParent;
                                   validation Wbs~validateWbsScope;
                                   validation Activity~validateActivityRequired;
                                   validation Activity~validateWorkCenter;
                                   validation Activity~validateEmployee;
                                   validation Activity~validateActivityDates;
                                   validation Activity~validateActivityScope; }

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

define behavior for ZR_PS_WBS_YJ alias Wbs
persistent table zps_wbs_yj
draft table zps_wbs_d_yj
etag master LocalLastChangedAt
lock dependent by _Project
authorization dependent by _Project

{
  field ( numbering : managed, readonly ) WbsUuid;
  field ( readonly ) ProjectUuid, WbsId, WbsLevel, Status, LocalLastChangedAt;

  // BR-12: 부모 WBS는 등록할 때만 정하고 이후에는 변경할 수 없다 (TS-08).
  // draft 시나리오에서는 생성 직후 입력도 UPDATE로 전달되므로 정적 readonly:update를 쓰면
  // 신규 draft에서 부모를 아예 지정할 수 없다. 활성 데이터 유무로 판단하는 동적 필드 제어를 쓴다
  // (3단계 프로젝트 ProfileCode와 같은 패턴).
  field ( features : instance ) ParentWbsId;

  field ( mandatory ) WbsName;

  update ( features : instance );
  internal delete;

  association _Project { with draft; }

  // Activity도 프로젝트와 같은 draft·lock 단위로 묶인다. BR-09 범위를 벗어난 WBS
  // (자신·상위 WBS·프로젝트 중 TECO·CLSD)에서는 Activity 등록을 막는다.
  association _Activity { create ( features : instance ); with draft; }

  // BR-02: 상태는 CRTD로, BR-12: Level은 부모 Level + 1로 자동 설정
  determination setWbsDefaults on modify { create; field ParentWbsId; }
  // 'WBS' + 7자리 채번 (BR-17)
  determination setWbsId on save { create; }

  validation validateWbsName on save { create; update; field WbsName; }
  validation validateParent on save { create; field ParentWbsId; }
  validation validateWbsScope on save { create; update; }

  mapping for zps_wbs_yj corresponding
  {
    WbsUuid            = wbs_uuid;
    ProjectUuid        = project_uuid;
    WbsId              = wbs_id;
    WbsName            = wbs_name;
    ParentWbsId        = parent_wbs_id;
    WbsLevel           = wbs_level;
    Status             = status;
    LocalLastChangedAt = local_last_changed_at;
  }
}

define behavior for ZR_PS_ACTIVITY_YJ alias Activity
persistent table zps_activity_yj
draft table zps_act_d_yj
etag master LocalLastChangedAt
lock dependent by _Project
authorization dependent by _Project

{
  field ( numbering : managed, readonly ) ActivityUuid;
  field ( readonly ) WbsUuid, ProjectUuid, ActivityId, Status, LocalLastChangedAt;

  field ( mandatory ) ActivityName, WorkCenterId, EmployeeId;

  update ( features : instance );
  internal delete;

  association _Wbs { with draft; }
  association _Project { with draft; }

  // BR-02: 상태는 PLAN으로, ProjectUuid는 소속 WBS에서 가져온다
  determination setActivityDefaults on modify { create; }
  // 'ACT' + 7자리 채번 (BR-17)
  determination setActivityId on save { create; }

  validation validateActivityRequired on save { create; update; field ActivityName, WorkCenterId, EmployeeId; }
  validation validateWorkCenter on save { create; update; field WorkCenterId; }
  validation validateEmployee on save { create; update; field EmployeeId; }
  validation validateActivityDates on save { create; update; field StartDate, EndDate; }
  validation validateActivityScope on save { create; update; }

  mapping for zps_activity_yj corresponding
  {
    ActivityUuid       = activity_uuid;
    WbsUuid            = wbs_uuid;
    ProjectUuid        = project_uuid;
    ActivityId         = activity_id;
    ActivityName       = activity_name;
    WorkCenterId       = work_center_id;
    EmployeeId         = employee_id;
    StartDate          = start_date;
    EndDate            = end_date;
    Status             = status;
    LocalLastChangedAt = local_last_changed_at;
  }
}