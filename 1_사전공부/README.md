# 사전공부

## 계정 / 콘솔

- [SAP BTP Trial Home](https://account.hanatrial.ondemand.com/trial/#/home/trial) — 트라이얼 글로벌 계정 콘솔 (리전: Singapore - Azure)

## SAP BTP ABAP 학습 자료

### 무료 공식 강의 (learning.sap.com)

- [Learning Basic ABAP Programming (S4D400)](https://learning.sap.com/courses/basic-abap-programming) — 17시간 29분, 8개 유닛, 초급. BTP ABAP 환경 기준으로 구성된 무료 정식 코스.
  - Unit 1 "Getting Started" 첫 레슨: [Preparing the Development Environment](https://learning.sap.com/courses/basic-abap-programming/preparing-the-development-environment_bc84941b-b4e6-4a6a-9b71-bb5b80e4a4ce) — Eclipse 개발 환경 설치부터 ABAP Cloud Project 생성까지 다룸
- [Acquiring Core ABAP Skills](https://learning.sap.com/learning-journeys/acquiring-core-abap-skills) — 위 코스를 포함한 전체 학습 여정 (Learning Journey). 자격증 취득까지 이어지는 4개 코스로 구성
- [Exploring SAP Business Technology Platform](https://learning.sap.com/courses/exploring-sap-business-technology-platform) — BTP 개념이 처음이라면 먼저 들으면 좋은 선수 코스

### SAP Tutorials (developers.sap.com)

- [Set Up an SAP BTP Account for Tutorials](https://developers.sap.com/group.btp-setup.html) — BTP 트라이얼 계정 준비
- [Download the Eclipse IDE and add the ABAP Development Tools (ADT) Plugin](https://developers.sap.com/tutorials/abap-install-adt..html) — Eclipse 다운로드 및 ADT 플러그인 설치 (환경 무관 공통 단계)
- [SAP BTP ABAP Environment: Create a Trial User](https://developers.sap.com/mission.abap-env-trial-user.html) — BTP ABAP 환경 트라이얼 유저 생성 + ABAP Cloud Project로 Eclipse 연결 (**BTP Trial 핵심 경로**)
- [SAP Tutorial Navigator](https://developers.sap.com/tutorial-navigator.html) — 전체 튜토리얼 탐색 허브

> ⚠️ 주의: [Create an ABAP Project (abap-create-project)](https://developers.sap.com/tutorials/abap-create-project.html) 튜토리얼은 BTP가 아닌 **온프레미스 AS ABAP 서버용**이므로 이 프로젝트에서는 사용하지 않음.

### 참고: 다운로드형 서버(온프레미스 Developer Edition) 현황

> 이 프로젝트는 **SAP BTP Trial 기준**으로 진행. 아래는 대안이었던 다운로드형 서버가 왜 제외되었는지 기록.

- **ABAP Cloud Developer Trial** (Docker 이미지) — 무료, 교육·데모 목적 전용(상업적 사용 불가), 커뮤니티 지원만 제공. ABAP 라이선스가 3개월짜리라 minisap에서 데모 라이선스를 받아 SLICENSE로 주기 갱신 필요. 하드웨어 요구 높음(이미지 15GB+, Docker 메모리 20GB+ 할당 권장, RAM 32GB 권장)
  - **2026년 2월부로 전 버전이 Docker Hub에서 내려간 상태.** SAP가 ABAP Platform 2025 SP01 기반의 2025 버전을 준비 중이나 일정 미정
- **AS ABAP 7.xx Developer Edition** (구형, 2017년~) — EOL 선언. **2026년 9월 30일 완전 철수 예정.** 구버전(7.52)이라 ABAP Cloud/RAP 학습에 부적합
- 출처: [ABAP Cloud Developer Trial 2023 Available Now (SAP 공식 블로그)](https://community.sap.com/t5/technology-blog-posts-by-sap/abap-cloud-developer-trial-2023-available-now/ba-p/14057183), [ABAP Platform Trial FAQ (GitHub)](https://github.com/SAP-docs/abap-platform-trial-image/blob/main/faq-v7.md)
- 결론: 현시점(2026-07) 로컬 서버 경로는 사실상 막혀 있으므로 **BTP Trial이 유일한 실용적 경로**

### 강의 진행 가능 여부 확인 (2026-07 체크 완료)

- [Learning Basic ABAP Programming](https://learning.sap.com/courses/basic-abap-programming) 코스는 "SAP BTP ABAP environment 기반"으로 명시되어 있어 **BTP Trial로 진행 가능** ✅
- [Create an SAP BTP ABAP Environment Trial User](https://developers.sap.com/tutorials/abap-environment-trial-onboarding..html) 튜토리얼 현재 유효 (2025-05 업데이트 확인)

### 실습 환경 세팅 — 두 가지 방법

**방법 A — 본인 BTP Trial 사용 (권장)**

1. BTP Trial 계정 생성
2. Eclipse + ADT 설치
3. BTP Cockpit → Boosters → **"Prepare an Account for ABAP Trial"** 부스터 실행 → ABAP 서비스 인스턴스 생성
4. Eclipse에서 ABAP Cloud Project로 인스턴스에 연결

> 트라이얼 ABAP 인스턴스는 계정당 1개만 생성 가능하며, 리소스 제한이 있는 교육용 공유 환경 (학습 목적으로는 충분)

**방법 B — SAP 호스팅 연습 시스템**

- [Acquiring Core ABAP Skills](https://learning.sap.com/learning-journeys/acquiring-core-abap-skills) 학습 여정의 "Hands-on Practice" 항목은 SAP가 미리 세팅한 연습 시스템을 제공
- learning.sap.com 무료 가입만 하면 잠금 해제 — 본인 트라이얼 만료 걱정 없이 실습 가능

### BTP Trial 90일 정책 ⚠️

- 트라이얼 계정은 90일 후 **자동 삭제** — 앱·서비스·데이터·설정 전부 소멸, 연장 불가
- **새 SAP 계정을 팔 필요는 없음**: 같은 SAP 로그인(이메일)으로 새 트라이얼 계정을 다시 생성하면 됨
- 단, 이전 작업물은 복구 불가 → **코드는 abapGit 등으로 주기적 백업 필수**
- 시간 제한 없는 대안인 Free Tier는 ABAP 환경에 [정책 변경](https://community.sap.com/t5/technology-blog-posts-by-sap/important-update-changes-to-the-free-tier-option-for-sap-btp-abap/ba-p/13592731)이 있었으므로, 학습용은 90일마다 트라이얼 재생성이 현실적
- 출처: [Trial Accounts and Free Tier (SAP Help Portal)](https://help.sap.com/docs/btp/sap-business-technology-platform/trial-accounts-and-free-tier)

### 학습 순서 제안

1. BTP 트라이얼 계정 생성
2. Eclipse + ADT 설치 (Learning Basic ABAP Programming Unit 1, 또는 SAP Tutorials 가이드)
3. "Prepare an Account for ABAP Trial" 부스터로 ABAP 인스턴스 생성 후 Eclipse 연결
4. Learning Basic ABAP Programming 코스 순서대로 진행

## Claude Code ↔ BTP Trial ABAP 연동 (MCP) 조사 (2026-07)

목표: Claude Code에서 (1) ABAP 코드/테이블 데이터 조회, (2) 외부에서 호출한 OData 요청을 BTP Trial이 인바운드로 수신. **아웃바운드(ABAP → 외부) 불필요**, 인바운드만 필요.

### 트라이얼 네트워크 제약 요약

- BTP Trial ABAP 환경은 **Destination Service를 지원하지 않음** → 표준 방식의 아웃바운드(ABAP가 외부를 호출하는 것)는 불가
  - 우회책은 있음: 코드 내 `cl_http_destination_provider=>create_by_url()`로 URL 직접 지정 (트라이얼 한정 workaround)
  - 이번 목적(인바운드만)에는 해당 없음 — 참고용으로만 기록
- **인바운드(외부 → ABAP)는 트라이얼에서도 정상 지원.** Basic Auth 기반 Communication User/Arrangement로 외부 클라이언트가 호출 가능

### 목적 1 — Claude Code에서 코드/테이블 조회: 가능, 기존 MCP 서버 활용 가능

ADT REST API(`/sap/bc/adt/`, Eclipse ADT 플러그인이 내부적으로 쓰는 것과 동일한 API)를 감싼 오픈소스 MCP 서버가 이미 여럿 존재:

- [fr0ster/mcp-abap-adt](https://github.com/fr0ster/mcp-abap-adt) — **BTP ABAP Cloud + 온프레미스 ECC/S4HANA 둘 다 지원**, full CRUD, **서비스 키 기반 JWT/XSUAA 인증** 내장 (BTP Trial 서비스 키를 그대로 사용 가능)
- [mario-andreschak/mcp-abap-adt](https://mcpservers.org/servers/mario-andreschak/mcp-abap-adt) — 읽기 전용 13개 툴(GetClass, GetTable, SearchObject 등). 조회만 필요하면 더 안전한 선택
- 참고 가이드: [How I Connected Claude AI to My SAP ABAP System Using MCP (Windows)](https://community.sap.com/t5/artificial-intelligence-blogs-posts/how-i-connected-claude-ai-to-my-sap-abap-system-using-mcp-a-complete/ba-p/14365831)
- MCP 서버 종합 목록: [marianfoo/sap-ai-mcp-servers](https://github.com/marianfoo/sap-ai-mcp-servers)

> ⚠️ 인증 주의: BTP ABAP 환경(Steampunk)의 ADT API는 Basic Auth가 아니라 **OAuth(서비스 키 → JWT 토큰)** 방식. 위 MCP 서버들이 토큰 발급을 처리해주므로, BTP Cockpit에서 ABAP 인스턴스의 **서비스 키(Service Key) 발급**만 하면 됨.

### 목적 2 — 외부에서 OData 호출 → BTP Trial이 수신: 가능, 표준 경로 존재

1. RAP으로 서비스 개발 → **Service Binding**(OData V2/V4 Web API) 생성 → 외부 접근 가능한 URL 발급
2. **Communication Scenario/Arrangement** 생성해 인바운드 허용
3. **Communication User**(ID/비밀번호, Basic Auth) 생성
4. 외부 클라이언트(Claude Code, curl, Postman 등)에서 해당 URL 호출

- 공식 튜토리얼: [Publish an OData service for remote consumption as an API](https://developers.sap.com/tutorials/abap-environment-a4c-inbound-communication..html)
- BTP Trial 온보딩 3부작의 2번째 튜토리얼("Create and Expose a CDS-Based Data Model")이 정확히 이 경로라 트라이얼에서 검증된 시나리오

### 결론

| 목적 | 가능 여부 | 방법 |
|---|---|---|
| 1. 코드/테이블 조회 (Claude Code → ABAP) | ✅ | 기존 MCP 서버(fr0ster/mcp-abap-adt 등) + 서비스 키(OAuth) |
| 2. 외부 OData 호출 수신 (외부 → BTP Trial) | ✅ | Service Binding + Communication Arrangement (Basic Auth) |

두 목적 모두 인바운드 방향이라 BTP Trial의 아웃바운드 제약(Destination Service 미지원)과 무관하게 정상 동작.
