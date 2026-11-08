@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: '프로젝트',
  typeNamePlural: '프로젝트 목록',
  title: { type: #STANDARD, value: 'ProjectName' },
  description: { type: #STANDARD, value: 'ProjectId' }
}

annotate entity ZC_PS_PROJECT_YJ with
{
  @UI.facet: [
    {
      id: 'General',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: '기본 정보',
      position: 10
    },
    {
      id: 'Status',
      purpose: #STANDARD,
      type: #FIELDGROUP_REFERENCE,
      label: '상태',
      position: 20,
      targetQualifier: 'StatusGroup'
    }
    // position 30: 다음 단계에서 WBS facet(#LINEITEM_REFERENCE, '_Wbs')을 추가할 자리
  ]

  @UI.hidden: true
  ProjectUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  @EndUserText.label: '프로젝트 ID'
  ProjectId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 10 } ]
  @UI.selectionField: [ { position: 20 } ]
  @EndUserText.label: '프로젝트명'
  ProjectName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 30 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '프로젝트 프로파일'
  ProfileCode;

  @UI.identification: [ { position: 30 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '선박 타입'
  VesselType;

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 40 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '프로젝트 관리자(PM)'
  PmEmployeeId;

  @UI.identification: [ { position: 50 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '발주처'
  CustomerId;

  @UI.identification: [ { position: 60 } ]
  @EndUserText.label: '계약 금액'
  ContractAmount;

  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 70 } ]
  @UI.selectionField: [ { position: 50 } ]
  @EndUserText.label: '시작일'
  StartDate;

  @UI.lineItem: [ { position: 60 } ]
  @UI.identification: [ { position: 80 } ]
  @UI.selectionField: [ { position: 60 } ]
  @EndUserText.label: '종료일'
  EndDate;

  @UI.lineItem: [ { position: 70 } ]
  @UI.fieldGroup: [ { qualifier: 'StatusGroup', position: 10 } ]
  @UI.selectionField: [ { position: 40 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '프로젝트 상태'
  Status;

  @EndUserText.label: '프로파일명'
  ProfileName;

  @EndUserText.label: '선박 타입명'
  VesselTypeName;

  @EndUserText.label: 'PM 이름'
  PmName;

  @EndUserText.label: '발주처명'
  CustomerName;

  @EndUserText.label: '상태명'
  StatusName;

  @UI.fieldGroup: [ { qualifier: 'StatusGroup', position: 20 } ]
  @EndUserText.label: '생성자'
  CreatedBy;

  @UI.fieldGroup: [ { qualifier: 'StatusGroup', position: 30 } ]
  @EndUserText.label: '생성 시각'
  CreatedAt;

  @UI.fieldGroup: [ { qualifier: 'StatusGroup', position: 40 } ]
  @EndUserText.label: '최종 변경자'
  LastChangedBy;

  @UI.fieldGroup: [ { qualifier: 'StatusGroup', position: 50 } ]
  @EndUserText.label: '최종 변경 시각'
  LocalLastChangedAt;

  @UI.hidden: true
  LastChangedAt;
}
