@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: 'Activity',
  typeNamePlural: 'Activity 목록',
  title: { type: #STANDARD, value: 'ActivityName' },
  description: { type: #STANDARD, value: 'ActivityId' }
}

@UI.presentationVariant: [ { sortOrder: [ { by: 'ActivityId', direction: #ASC } ] } ]

annotate entity ZC_PS_ACTIVITY_YJ with
{
  @UI.facet: [
    {
      id: 'ActivityGeneral',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: 'Activity 정보',
      position: 10
    }
  ]

  @UI.hidden: true
  ActivityUuid;

  @UI.hidden: true
  WbsUuid;

  @UI.hidden: true
  ProjectUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @EndUserText.label: 'Activity ID'
  ActivityId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @EndUserText.label: 'Activity 명'
  ActivityName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '작업장'
  WorkCenterId;

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 40 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '담당자'
  EmployeeId;

  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 50 } ]
  @EndUserText.label: '시작일'
  StartDate;

  @UI.lineItem: [ { position: 60 } ]
  @UI.identification: [ { position: 60 } ]
  @EndUserText.label: '종료일'
  EndDate;

  @UI.lineItem: [ { position: 70 } ]
  @UI.identification: [ { position: 70 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: '작업 상태'
  Status;

  // BR-10: Activity 상태와 직속 WBS 상태를 함께 보여준다 (예: PLAN · WBS CRTD).
  @UI.lineItem: [ { position: 80 } ]
  @UI.identification: [ { position: 80 } ]
  @EndUserText.label: 'WBS 상태'
  WbsStatus;

  @EndUserText.label: '작업장명'
  WorkCenterName;

  @EndUserText.label: '담당자명'
  EmployeeName;

  @EndUserText.label: '상태명'
  StatusName;

  @UI.hidden: true
  LocalLastChangedAt;
}
