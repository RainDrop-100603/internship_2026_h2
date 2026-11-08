@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: '자재',
  typeNamePlural: '자재 목록',
  title: { type: #STANDARD, value: 'MaterialName' }
}

annotate entity ZC_PS_MATERIAL_YJ with
{
  @UI.facet: [
    {
      id: 'Material',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: '기본 정보',
      position: 10
    }
  ]

  @UI.hidden: true
  MaterialUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  @EndUserText.label: '자재 ID'
  MaterialId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 20 } ]
  @EndUserText.label: '자재명'
  MaterialName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  @EndUserText.label: '자재 분류'
  MaterialCategoryCode;
}
