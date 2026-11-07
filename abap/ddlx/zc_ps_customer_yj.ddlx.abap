@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: '고객사',
  typeNamePlural: '고객사 목록',
  title: { type: #STANDARD, value: 'CustomerName' }
}

annotate entity ZC_PS_CUSTOMER_YJ with
{
  @UI.facet: [
    {
      id: 'Customer',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: '기본 정보',
      position: 10
    }
  ]

  @UI.hidden: true
  CustomerUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  CustomerId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 20 } ]
  CustomerName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  CountryCode;

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 40 } ]
  ContactPerson;

  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 50 } ]
  Contact;
}
