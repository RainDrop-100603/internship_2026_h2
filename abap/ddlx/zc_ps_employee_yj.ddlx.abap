@Metadata.layer: #CUSTOMER

@UI.headerInfo: {
  typeName: '사원',
  typeNamePlural: '사원 목록',
  title: { type: #STANDARD, value: 'EmployeeName' }
}

annotate entity ZC_PS_EMPLOYEE_YJ with
{
  @UI.facet: [
    {
      id: 'Employee',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: '기본 정보',
      position: 10
    }
  ]

  @UI.hidden: true
  EmployeeUuid;

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  @EndUserText.label: '사원 ID'
  EmployeeId;

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 20 } ]
  @EndUserText.label: '사원명'
  EmployeeName;

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  @EndUserText.label: '부서'
  DepartmentCode;

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 40 } ]
  @EndUserText.label: '직급'
  PositionCode;

  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 50 } ]
  @EndUserText.label: '연락처'
  Contact;
}
