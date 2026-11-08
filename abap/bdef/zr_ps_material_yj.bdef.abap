managed implementation in class zbp_r_ps_material_yj unique;
strict ( 2 );
with draft;

define behavior for ZR_PS_MATERIAL_YJ alias Material
persistent table zps_material_yj
draft table zps_mat_d_yj
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )

{
  field ( numbering : managed, readonly ) MaterialUuid;
  field ( readonly ) MaterialId, CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt, LastChangedAt;
  field ( mandatory ) MaterialName;

  create;
  update;
  internal delete;

  determination setMaterialId on save { create; }

  validation validateName on save { create; field MaterialName; }
  validation validateCategory on save { create; field MaterialCategoryCode; }
  validation validateMaterialId on save { create; field MaterialId; }

  draft action Edit;
  // Activate optimized를 쓰지 않는다: optimized는 Prepare 이후 draft가 바뀌지 않았으면
  // Activate 시점에 determination/validation 재실행을 건너뛸 수 있어, setMaterialId의
  // 충돌 재채번 로직(다른 자재가 그 사이 같은 ID로 먼저 저장되는 경우)이 생략될 수 있다.
  // 일반 Activate로 지정해 Activate 시점에도 save 시퀀스가 항상 실행되게 한다.
  draft action Activate;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { determination setMaterialId; validation validateName; validation validateCategory; validation validateMaterialId; }

  mapping for zps_material_yj corresponding
  {
    MaterialUuid         = material_uuid;
    MaterialId           = material_id;
    MaterialName         = material_name;
    MaterialCategoryCode = material_category_code;
    CreatedBy            = created_by;
    CreatedAt            = created_at;
    LastChangedBy        = last_changed_by;
    LocalLastChangedAt   = local_last_changed_at;
    LastChangedAt        = last_changed_at;
  }
}
