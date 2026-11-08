@EndUserText.label: '사원 관리'
define service ZUI_PS_EMPLOYEE_YJ {
  expose ZC_PS_EMPLOYEE_YJ as Employee;
  expose ZI_PS_DEPT_VH_YJ as Department;
  expose ZI_PS_POSITION_VH_YJ as Position;
}
