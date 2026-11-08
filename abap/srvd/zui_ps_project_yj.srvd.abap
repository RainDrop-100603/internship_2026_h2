@EndUserText.label: '프로젝트 관리'
define service ZUI_PS_PROJECT_YJ {
  expose ZC_PS_PROJECT_YJ as Project;
  expose ZI_PS_PRJPROF_VH_YJ as Profile;
  expose ZI_PS_VSLTYPE_VH_YJ as VesselType;
  expose ZI_PS_EMPLOYEE_VH_YJ as Employee;
  expose ZI_PS_CUSTOMER_VH_YJ as Customer;
  expose ZI_PS_PRJSTAT_VH_YJ as ProjectStatus;
}
