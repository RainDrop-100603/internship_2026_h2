@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: '작업장',
  typeNamePlural: '작업장 목록',
  title: { type: #STANDARD, value: 'WorkCenterName' }
}

annotate entity ZC_PS_WORKCENTER_YJ with
{
  @UI.facet: [
    {
      id: 'WorkCenter',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: '기본 정보',
      position: 10
    }
  ]

  @UI.hidden: true
  WorkCenterUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  @EndUserText.label: '작업장 ID'
  WorkCenterId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 20 } ]
  @EndUserText.label: '작업장명'
  WorkCenterName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  @EndUserText.label: '공정 분류'
  ProcessCategoryCode;
}
