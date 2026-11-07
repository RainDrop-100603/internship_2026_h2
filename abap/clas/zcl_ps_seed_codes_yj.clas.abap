class ZCL_PS_SEED_CODES_YJ definition
  public
  final
  create public .

  public section.
    interfaces if_oo_adt_classrun.

  protected section.
  private section.
endclass.



class ZCL_PS_SEED_CODES_YJ implementation.

  method if_oo_adt_classrun~main.

    data:
      lt_prjstat  type standard table of zps_prjstat_yj with empty key,
      lt_wbsstat  type standard table of zps_wbsstat_yj with empty key,
      lt_actstat  type standard table of zps_actstat_yj with empty key,
      lt_country  type standard table of zps_country_yj with empty key,
      lt_vsltype  type standard table of zps_vsltype_yj with empty key,
      lt_dept     type standard table of zps_dept_yj with empty key,
      lt_position type standard table of zps_position_yj with empty key,
      lt_matcat   type standard table of zps_matcat_yj with empty key,
      lt_proccat  type standard table of zps_proccat_yj with empty key,
      lt_prjprof  type standard table of zps_prjprof_yj with empty key.

    "--------------------------------------------------------------
    " Project Status Code Master
    "--------------------------------------------------------------
    lt_prjstat = value #(
      ( client = sy-mandt code = 'CRTD' name = 'Created'                remark = '프로젝트 생성' )
      ( client = sy-mandt code = 'REL'  name = 'Released'               remark = '프로젝트 실행 가능' )
      ( client = sy-mandt code = 'TECO' name = 'Technically Completed'  remark = '기술적 완료' )
      ( client = sy-mandt code = 'CLSD' name = 'Closed'                 remark = '마감/종료' )
    ).

    "--------------------------------------------------------------
    " WBS Status Code Master
    "--------------------------------------------------------------
    lt_wbsstat = value #(
      ( client = sy-mandt code = 'CRTD' name = 'Created'               remark = 'WBS 생성' )
      ( client = sy-mandt code = 'REL'  name = 'Released'              remark = 'WBS 실행 가능 (Activity 착수 가능)' )
      ( client = sy-mandt code = 'TECO' name = 'Technically Completed' remark = '기술적 완료 (진행 중 Activity 완료만 가능)' )
      ( client = sy-mandt code = 'CLSD' name = 'Closed'                remark = '마감/종료 (조회만 가능)' )
    ).

    "--------------------------------------------------------------
    " Activity Status Code Master
    "--------------------------------------------------------------
    lt_actstat = value #(
      ( client = sy-mandt code = 'PLAN' name = 'Planned'     remark = '작업 계획 수립 상태(착수 전)' )
      ( client = sy-mandt code = 'PROC' name = 'In Progress' remark = '현재 작업 진행 중' )
      ( client = sy-mandt code = 'COMP' name = 'Completed'   remark = '작업 완료' )
      ( client = sy-mandt code = 'HOLD' name = 'On Hold'     remark = '작업 일시 중지' )
    ).

    "--------------------------------------------------------------
    " Country Code Master
    "--------------------------------------------------------------
    lt_country = value #(
      ( client = sy-mandt code = 'KR' name = 'Korea'         remark = '대한민국' )
      ( client = sy-mandt code = 'US' name = 'United States' remark = '미국' )
      ( client = sy-mandt code = 'JP' name = 'Japan'         remark = '일본' )
    ).

    "--------------------------------------------------------------
    " Vessel Type Code Master
    "--------------------------------------------------------------
    lt_vsltype = value #(
      ( client = sy-mandt code = 'LNG' name = 'LNG 운반선' remark = 'LNG Carrier' )
      ( client = sy-mandt code = 'CON' name = '컨테이너선'  remark = 'Container Ship' )
      ( client = sy-mandt code = 'TNK' name = '유조선'      remark = 'Oil Tanker' )
      ( client = sy-mandt code = 'CRU' name = '크루즈선'    remark = 'Cruise Ship' )
    ).

    "--------------------------------------------------------------
    " Department Code Master
    "--------------------------------------------------------------
    lt_dept = value #(
      ( client = sy-mandt code = 'DSG' name = '설계부'     remark = 'Design' )
      ( client = sy-mandt code = 'PUR' name = '구매부'     remark = 'Purchasing' )
      ( client = sy-mandt code = 'PPC' name = '생산관리부' remark = 'Production Planning & Control' )
      ( client = sy-mandt code = 'HUL' name = '선체가공부' remark = 'Hull Fabrication' )
      ( client = sy-mandt code = 'OUT' name = '의장부'     remark = 'Outfitting' )
      ( client = sy-mandt code = 'PNT' name = '도장부'     remark = 'Painting' )
      ( client = sy-mandt code = 'QAA' name = '품질보증부' remark = 'Quality Assurance' )
    ).

    "--------------------------------------------------------------
    " Position Code Master
    "--------------------------------------------------------------
    lt_position = value #(
      ( client = sy-mandt code = 'PRO'  name = '프로' remark = 'Professional' )
      ( client = sy-mandt code = 'SEN'  name = '선임' remark = 'Senior Professional' )
      ( client = sy-mandt code = 'LEAD' name = '책임' remark = 'Lead Professional' )
    ).

    "--------------------------------------------------------------
    " Material Category Code Master
    "--------------------------------------------------------------
    lt_matcat = value #(
      ( client = sy-mandt code = 'STL' name = '강재'   remark = 'Steel' )
      ( client = sy-mandt code = 'EQP' name = '기자재' remark = 'Equipment' )
      ( client = sy-mandt code = 'OUT' name = '의장품' remark = 'Outfitting Material' )
    ).

    "--------------------------------------------------------------
    " Process Category Code Master
    "--------------------------------------------------------------
    lt_proccat = value #(
      ( client = sy-mandt code = 'DSG' name = '설계'      remark = 'Design' )
      ( client = sy-mandt code = 'MAT' name = '자재/조달' remark = 'Material & Procurement' )
      ( client = sy-mandt code = 'FAB' name = '가공'      remark = 'Fabrication' )
      ( client = sy-mandt code = 'ASM' name = '조립'      remark = 'Assembly' )
      ( client = sy-mandt code = 'ERE' name = '탑재'      remark = 'Erection' )
      ( client = sy-mandt code = 'OUT' name = '의장'      remark = 'Outfitting' )
      ( client = sy-mandt code = 'PNT' name = '도장'      remark = 'Painting' )
      ( client = sy-mandt code = 'TST' name = '검사/시험' remark = 'Inspection & Testing' )
    ).

    "--------------------------------------------------------------
    " Project Profile Master
    "--------------------------------------------------------------
    lt_prjprof = value #(
      ( client = sy-mandt profile_code = 'SHIP' profile_name = '신규 선박 건조'
        description = '신규 선박 건조 프로젝트' initial_status = 'CRTD'
        wbs_template = '' vessel_type_required = abap_true )
      ( client = sy-mandt profile_code = 'REPR' profile_name = '기존 선박 수리'
        description = '기존 선박 수리 프로젝트' initial_status = 'CRTD'
        wbs_template = '' vessel_type_required = abap_true )
      ( client = sy-mandt profile_code = 'CNVT' profile_name = '기존 선박 개조'
        description = '기존 선박 개조 프로젝트' initial_status = 'CRTD'
        wbs_template = '' vessel_type_required = abap_true )
      ( client = sy-mandt profile_code = 'RND' profile_name = '기술·공법 연구개발'
        description = '기술 및 공법 연구개발 프로젝트' initial_status = 'CRTD'
        wbs_template = '' vessel_type_required = abap_false )
      ( client = sy-mandt profile_code = 'FAC' profile_name = '생산 설비 구축 및 개선'
        description = '생산 설비 구축·개선 프로젝트' initial_status = 'CRTD'
        wbs_template = '' vessel_type_required = abap_false )
    ).

    "--------------------------------------------------------------
    " Reload (delete then insert) so repeated runs are idempotent
    "--------------------------------------------------------------
    delete from zps_prjstat_yj.
    insert zps_prjstat_yj from table @lt_prjstat.

    delete from zps_wbsstat_yj.
    insert zps_wbsstat_yj from table @lt_wbsstat.

    delete from zps_actstat_yj.
    insert zps_actstat_yj from table @lt_actstat.

    delete from zps_country_yj.
    insert zps_country_yj from table @lt_country.

    delete from zps_vsltype_yj.
    insert zps_vsltype_yj from table @lt_vsltype.

    delete from zps_dept_yj.
    insert zps_dept_yj from table @lt_dept.

    delete from zps_position_yj.
    insert zps_position_yj from table @lt_position.

    delete from zps_matcat_yj.
    insert zps_matcat_yj from table @lt_matcat.

    delete from zps_proccat_yj.
    insert zps_proccat_yj from table @lt_proccat.

    delete from zps_prjprof_yj.
    insert zps_prjprof_yj from table @lt_prjprof.

    "--------------------------------------------------------------
    " Report loaded counts
    "--------------------------------------------------------------
    out->write( |ZPS_PRJSTAT_YJ : { lines( lt_prjstat )  } rows| ).
    out->write( |ZPS_WBSSTAT_YJ : { lines( lt_wbsstat )  } rows| ).
    out->write( |ZPS_ACTSTAT_YJ : { lines( lt_actstat )  } rows| ).
    out->write( |ZPS_COUNTRY_YJ : { lines( lt_country )  } rows| ).
    out->write( |ZPS_VSLTYPE_YJ : { lines( lt_vsltype )  } rows| ).
    out->write( |ZPS_DEPT_YJ    : { lines( lt_dept )     } rows| ).
    out->write( |ZPS_POSITION_YJ: { lines( lt_position ) } rows| ).
    out->write( |ZPS_MATCAT_YJ  : { lines( lt_matcat )   } rows| ).
    out->write( |ZPS_PROCCAT_YJ : { lines( lt_proccat )  } rows| ).
    out->write( |ZPS_PRJPROF_YJ : { lines( lt_prjprof )  } rows| ).

  endmethod.

endclass.
