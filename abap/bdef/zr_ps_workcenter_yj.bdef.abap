managed implementation in class zbp_r_ps_workcenter_yj unique;
strict ( 2 );
with draft;

define behavior for ZR_PS_WORKCENTER_YJ alias WorkCenter
persistent table zps_wrkctr_yj
draft table zps_wc_d_yj
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )

{
  field ( numbering : managed, readonly ) WorkCenterUuid;
  field ( readonly ) WorkCenterId, CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt, LastChangedAt;
  field ( mandatory ) WorkCenterName;

  create;
  update;
  internal delete;

  determination setWorkCenterId on save { create; }

  validation validateName on save { create; field WorkCenterName; }
  validation validateProcessCategory on save { create; field ProcessCategoryCode; }
  validation validateWorkCenterId on save { create; field WorkCenterId; }

  draft action Edit;
  // Activate optimized를 쓰지 않는다: optimized는 Prepare 이후 draft가 바뀌지 않았으면
  // Activate 시점에 determination/validation 재실행을 건너뛸 수 있어, setWorkCenterId의
  // 충돌 재채번 로직(다른 작업장이 그 사이 같은 ID로 먼저 저장되는 경우)이 생략될 수 있다.
  // 일반 Activate로 지정해 Activate 시점에도 save 시퀀스가 항상 실행되게 한다.
  draft action Activate;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { determination setWorkCenterId; validation validateName; validation validateProcessCategory; validation validateWorkCenterId; }

  mapping for zps_wrkctr_yj corresponding
  {
    WorkCenterUuid      = work_center_uuid;
    WorkCenterId        = work_center_id;
    WorkCenterName      = work_center_name;
    ProcessCategoryCode = process_category_code;
    CreatedBy           = created_by;
    CreatedAt           = created_at;
    LastChangedBy       = last_changed_by;
    LocalLastChangedAt  = local_last_changed_at;
    LastChangedAt       = last_changed_at;
  }
}
