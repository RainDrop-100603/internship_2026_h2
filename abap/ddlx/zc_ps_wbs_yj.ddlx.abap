@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: 'WBS',
  typeNamePlural: 'WBS 목록',
  title: { type: #STANDARD, value: 'WbsName' },
  description: { type: #STANDARD, value: 'WbsId' }
}

// Fiori Elements 하위 테이블은 트리가 아닌 평평한 목록이다.
// 계층은 WbsLevel·ParentWbsId 컬럼으로 표현하고 기본 정렬은 WbsId로 둔다.
@UI.presentationVariant: [ { sortOrder: [ { by: 'WbsId', direction: #ASC } ] } ]

annotate entity ZC_PS_WBS_YJ with
{
  @UI.facet: [
    {
      id: 'WbsGeneral',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: 'WBS 정보',
      position: 10
    },
    {
      id: 'Activity',
      purpose: #STANDARD,
      type: #LINEITEM_REFERENCE,
      label: 'Activity',
      position: 20,
      targetElement: '_Activity'
    }
  ]

  @UI.hidden: true
  WbsUuid;

  @UI.hidden: true
  ProjectUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @EndUserText.label: 'WBS ID'
  WbsId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @EndUserText.label: 'WBS 명'
  WbsName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  @EndUserText.label: 'WBS Level'
  WbsLevel;

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 40 } ]
  @EndUserText.label: '상위 WBS'
  ParentWbsId;

  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 50 } ]
  @UI.textArrangement: #TEXT_FIRST
  @EndUserText.label: 'WBS 상태'
  Status;

  @EndUserText.label: '상태명'
  StatusName;

  @UI.hidden: true
  LocalLastChangedAt;
}
