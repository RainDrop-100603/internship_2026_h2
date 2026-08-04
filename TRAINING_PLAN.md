# 임유진 프로 연구장학생 실습계획서

## ■ 교육 개요

| 항목 | 내용 |
|---|---|
| 1. 이 름 | 임유진 프로 |
| 2. 배치 일자 | 2026.07.27 |
| 3. 교육 기간 | - 교육 일정 : 약 6개월 ( 7/27 ~ 12/31 )<br>&nbsp;&nbsp;. Learning Hub 과정 포함 ( 5개, 35 MH ) |
| 4. 지도담당자 | 오신일 프로 (SAP/PS모듈 교육), 이소희 프로 (PS Mock System 개발), 박광석 프로 (AI Tool과 BTP 연결) |
| 5. 교육 내용 | 1. SAP 및 PS 모듈, BTP 교육<br>2. Cloud ABAP 코딩, AI Tool을 활용한 Cloud ABAP 코딩 및 검증<br>3. AI Tool을 활용한 BTP 내의 Mock 시스템 실행 |

---

## ■ 교육 상세 일정

### 1. 기본과정

| 소분류 | 내용 및 목적 | 날짜 | 시간 | 교육담당 | 장소 |
|---|---|---|---|---|---|
| 실습 소개 및 설치 방법 Guide | - SAP Cloud와 BTP 소개<br>- 실습환경 구축을 위한 Guide<br>- Self Study 방법 소개 | 2026.07 4주차 | 1H | 박광석 | Knox Meeting |
| 학습자료 및 학습방법 소개 | - Learning Hub 교육과정 소개<br>&nbsp;&nbsp;. SAP Cloud Programing on SAP BTP<br>&nbsp;&nbsp;. RAP(Restful ABAP Programming) 기반 OData V4 서비스 이해<br>&nbsp;&nbsp;. RAP의 동작구조와 Action의 이해 | 2026.07 4주차 | 1H | 박광석 | Knox Meeting |
| SAP 및 PS 모듈 소개 | - ERP는 무엇인가? 왜 사용 하는가?<br>- SAP 소개<br>- PS 모듈 소개 | 2026.08 1주차 | 2H | 오신일 | Knox Meeting |

### 2. PS Mock Up 시스템 설계

| 소분류 | 내용 및 목적 | 날짜 | 시간 | 교육담당 | 장소 |
|---|---|---|---|---|---|
| PS Module Mock up 대상 선정 | - PS(Project System) 모듈의 핵심 기능(구현대상) 설명<br>- 실습 기간 중 구현할 Mock up 대상 업무 프로세스 선정<br>&nbsp;&nbsp;. PS 모듈에 대한 이해를 바탕으로 실습 범위(To-Be 프로세스)를 명확히 정의 | 2026.08 3주차 | 2H | 이소희 | Knox Meeting |
| Mock System Architecture 공유 | - Mock up 시스템 전체 구조 공유<br>&nbsp;&nbsp;. BTP ABAP Environment, RAP 서비스, 데이터 모델 등<br>- 시스템 구성요소 간 연계 방식(Front-end ↔ RAP ↔ DB) 설명<br>&nbsp;&nbsp;. 개발 착수 전 아키텍처에 대한 공통된 이해 형성 | 2026.08 4주차 | 2H | 이소희 | Knox Meeting |

### 3. PS Mock Up 시스템 구축 및 검증

| 소분류 | 내용 및 목적 | 날짜 | 시간 | 교육담당 | 장소 |
|---|---|---|---|---|---|
| Mock System Test 시나리오 공유 | - Mock up 시스템 검증을 위한 테스트 시나리오 정의<br>&nbsp;&nbsp;. 정상 Case / 예외 Case | 2026.09 2주차 | 2H | 이소희 | Knox Meeting |
| Mock System Test 및 보완사항 도출 | - 사전 정의된 시나리오 기반으로 Mock up 시스템 테스트 수행<br>- 테스트 중 발견된 오류 및 개선 필요사항 정리 | 2026.09 5주차 | 2H | 이소희 | Knox Meeting |
| Mock System Review | - 완성된 Mock up 시스템에 대한 최종 결과 리뷰 및 피드백 | 2026.10 3주차 | 2H | 이소희, 오신일 | Knox Meeting |

### 4. 대화형 AI Agent를 통한 설계/개발/검증 ( Switching 포함 )

| 소분류 | 내용 및 목적 | 날짜 | 시간 | 교육담당 | 장소 |
|---|---|---|---|---|---|
| Coding CLI를 통한 개발 기능 세팅 및 검증 | - Claude Code 등 AI Coding CLI 도구 설치 및 개발 환경 구성<br>- 코드 생성/리뷰/실행 등 기본 기능 동작 확인 | 2026.08 3주차 | 2H | 박광석 | Knox Meeting |
| Coding CLI Switching을 위한 Context 설계 | - 여러 AI 모델·CLI 환경 간 전환시 필요한 Context(설정, 세션 정보 등) 설계 | 2026.09 1주차 | 2H | 박광석 | Knox Meeting |
| 다양한 AI API를 통한 개발검증(Review) 기능 | - 서로 다른 AI 모델의 API를 활용하여 개발 결과물을 교차 검증(Review)<br>&nbsp;&nbsp;. 단일 모델 의존도를 낮추고 결과물의 신뢰성을 높이는 검증 방식 습득 | 2026.09 3주차 | 2H | 박광석, 오신일 | Knox Meeting |

### 5. 대화형 AI Agent를 통한 PS Mock 시스템 실행

| 소분류 | 내용 및 목적 | 날짜 | 시간 | 교육담당 | 장소 |
|---|---|---|---|---|---|
| AI Agent를 통한 PS Mock System 조회 | - 대화형 AI와 BTP 내 Mock System(ABAP/RAP 서비스) 연동<br>- 자연어 입력 기반 PS Mock Data(WBS, 원가 등) 조회 기능 구현 및 테스트<br>&nbsp;&nbsp;. AI Tool을 통한 SAP 데이터 조회 자동화 가능성 검증 | 2026.11 1주차 | 2H | 박광석, 이소희, 오신일 | Knox Meeting |
| AI Agent를 통한 PS Mock System 변경 | - 대화형 AI를 통한 PS Mock System 데이터 입력/변경 기능 구현<br>&nbsp;&nbsp;. 입력/변경시, AI Tool 연동 범위를 확장하고 리스크 요소 점검 | 2026.11 3주차 | 2H | 박광석, 이소희, 오신일 | Knox Meeting |

---

> ※ 원본 파일의 「Learning Hub 목록」 시트에는 별도 데이터가 입력되어 있지 않아, 위 상세 일정에 포함된 Learning Hub 과정(5개, 35 MH) 관련 세부 항목은 반영되지 않았습니다.
