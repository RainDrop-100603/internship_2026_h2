# 사전공부

SAP BTP·ABAP 사전학습을 위한 **학습 자료 링크와 학습 순서**를 정리한 폴더.

- 환경 세팅 절차·트러블슈팅: [docs/setup-guide.md](../docs/setup-guide.md)
- 환경·도구 선택의 조사·결정 기록 (온프레미스 서버 현황, 90일 정책, MCP 서버 비교 등): [docs/research-notes.md](../docs/research-notes.md)

## 계정 / 콘솔

- [SAP BTP Trial Home](https://account.hanatrial.ondemand.com/trial/#/home/trial) — 트라이얼 글로벌 계정 콘솔 (리전: Singapore - Azure)

## SAP BTP ABAP 학습 자료

### 무료 공식 강의 (learning.sap.com)

- [Learning Basic ABAP Programming (S4D400)](https://learning.sap.com/courses/basic-abap-programming) — 17시간 29분, 8개 유닛, 초급. BTP ABAP 환경 기준으로 구성된 무료 정식 코스. **BTP Trial로 진행 가능 확인 완료 (2026-07)**
  - Unit 1 "Getting Started" 첫 레슨: [Preparing the Development Environment](https://learning.sap.com/courses/basic-abap-programming/preparing-the-development-environment_bc84941b-b4e6-4a6a-9b71-bb5b80e4a4ce) — Eclipse 개발 환경 설치부터 ABAP Cloud Project 생성까지 다룸
- [Acquiring Core ABAP Skills](https://learning.sap.com/learning-journeys/acquiring-core-abap-skills) — 위 코스를 포함한 전체 학습 여정 (Learning Journey). 자격증 취득까지 이어지는 4개 코스로 구성
- [Exploring SAP Business Technology Platform](https://learning.sap.com/courses/exploring-sap-business-technology-platform) — BTP 개념이 처음이라면 먼저 들으면 좋은 선수 코스

### SAP Tutorials (developers.sap.com)

- [Set Up an SAP BTP Account for Tutorials](https://developers.sap.com/group.btp-setup.html) — BTP 트라이얼 계정 준비
- [Download the Eclipse IDE and add the ABAP Development Tools (ADT) Plugin](https://developers.sap.com/tutorials/abap-install-adt..html) — Eclipse 다운로드 및 ADT 플러그인 설치 (환경 무관 공통 단계)
- [SAP BTP ABAP Environment: Create a Trial User](https://developers.sap.com/mission.abap-env-trial-user.html) — BTP ABAP 환경 트라이얼 유저 생성 + ABAP Cloud Project로 Eclipse 연결 (**BTP Trial 핵심 경로**)
- [SAP Tutorial Navigator](https://developers.sap.com/tutorial-navigator.html) — 전체 튜토리얼 탐색 허브

> ⚠️ 주의: [Create an ABAP Project (abap-create-project)](https://developers.sap.com/tutorials/abap-create-project.html) 튜토리얼은 BTP가 아닌 **온프레미스 AS ABAP 서버용**이므로 이 프로젝트에서는 사용하지 않음.

## 실습 환경 — 두 가지 방법

**방법 A — 본인 BTP Trial 사용 (권장·이 프로젝트에서 채택)**

- BTP Trial 계정 + Eclipse/ADT + ABAP Trial 인스턴스로 직접 구축
- 전체 절차: [docs/setup-guide.md](../docs/setup-guide.md)
- ⚠️ 트라이얼 계정은 **90일 후 자동 삭제** → abapGit 백업 필수 (상세: [research-notes.md 조사 3](../docs/research-notes.md#조사-3-btp-trial-90일-정책))

**방법 B — SAP 호스팅 연습 시스템**

- [Acquiring Core ABAP Skills](https://learning.sap.com/learning-journeys/acquiring-core-abap-skills) 학습 여정의 "Hands-on Practice" 항목은 SAP가 미리 세팅한 연습 시스템을 제공
- learning.sap.com 무료 가입만 하면 잠금 해제 — 본인 트라이얼 만료 걱정 없이 실습 가능

## 학습 순서 제안

1. BTP 트라이얼 계정 생성
2. Eclipse + ADT 설치 (Learning Basic ABAP Programming Unit 1, 또는 SAP Tutorials 가이드)
3. "Prepare an Account for ABAP Trial" 부스터로 ABAP 인스턴스 생성 후 Eclipse 연결 (→ [setup-guide.md](../docs/setup-guide.md))
4. [Learning Basic ABAP Programming](https://learning.sap.com/courses/basic-abap-programming) 코스 순서대로 진행
