# BTP Trial + Eclipse/ADT 설치 과정 기록

> 실제 진행하면서 겪은 선택지·트러블슈팅을 순서대로 기록. 공유용.
> 진행 기준: Windows 11, 한국, 개인 교육용 계정 (2026-07)

## 1. SAP 계정 준비

- 회사 SAP 계정이 있어도 **교육용은 별도 개인 계정으로 분리**하는 것을 권장 (실제로 그렇게 진행)
- ⚠️ 주의: 브라우저에 회사 SAP 계정 세션이 남아 있으면 트라이얼이 회사 계정에 붙을 수 있음 → **시크릿 창에서 진행 권장**

### 트러블슈팅: 전화번호 인증

- 트라이얼 신청 시 전화번호 인증(SMS) 요구됨
- **회사 계정에 등록한 번호와 같은 본인 번호를 써도 됨** — "번호 1개당 계정 1개" 같은 제한은 SAP 문서·약관에 없음. 본인 확인이 목적이므로 실제 수신 가능한 본인 번호를 쓰는 게 중요
- 인증 코드 수신 실패(5회 초과 등)가 흔한 문제 → 해결 안 되면 `SAPBTPTrialSupport@sap.com` 또는 `sso@sap.com`으로 문의

## 2. BTP Trial 계정 생성 + 리전 선택

- 신청 후 리전 선택 화면이 나옴. 제시된 선택지: `US East (VA) - AWS` / `Singapore - Azure`
- **한국에서는 Singapore - Azure 선택** — 물리적으로 가까워 지연시간이 낮고(Eclipse↔서버 통신이 상시 발생), ABAP Environment 트라이얼 지원 리전임
- 리전은 서브계정 생성 후 변경 불가 → 처음에 확정해야 함
- 선택 후 Global Account / Subaccount / CF Org·Space가 자동 생성됨 (몇 분 소요, 완료되면 Continue)
- 콘솔 URL: [SAP BTP Trial Home](https://account.hanatrial.ondemand.com/trial/#/home/trial)

## 3. Eclipse 설치

- [Eclipse 다운로드 페이지](https://www.eclipse.org/downloads/)에서 **Eclipse IDE for Java Developers** 다운로드
- 아키텍처 선택: **x86_64 vs AArch64** → 일반 Intel/AMD PC는 **x86_64**
  - 확인 방법(PowerShell): `echo $env:PROCESSOR_ARCHITECTURE` → `AMD64`면 x86_64
  - AArch64는 ARM 칩(Snapdragon Windows 노트북, Apple Silicon)용
- JRE/JDK 별도 설치 불필요 — 최신 Eclipse 패키지에 Temurin JRE가 번들되어 있음
- 설치 패키지 종류: **Eclipse IDE for Java Developers** 선택 (Enterprise Java, C/C++ 등은 불필요)
- zip 압축 해제 후 `eclipse.exe` 실행 → 워크스페이스 지정

### 설치 경로 / 워크스페이스 경로 — 사용자명이 한글이면 반드시 영문 경로로 변경

- 설치 마법사가 기본 제안하는 경로는 `C:\Users\<사용자명>\eclipse\...` — 사용자명이 한글(예: `재택`)이면 그대로 두지 말 것
- **권장 경로**: 사용자 프로필을 아예 거치지 않는 `C:\` 드라이브 루트 하위로 직접 지정
  ```
  C:\eclipse\java-2026-06     ← Eclipse 설치 폴더
  C:\workspace                ← Eclipse 워크스페이스 (프로젝트 저장 위치)
  ```
- 설치 폴더(Installation Folder)와 최초 실행 시 뜨는 워크스페이스(Workspace) 지정 창, **둘 다** 변경 필요
- 이유: 한글 경로 이슈 회피 + `C:\` 루트 하위는 경로 길이 제한(MAX_PATH) 이슈도 줄어듦

### 트러블슈팅: `eclipse-inst-jre-win64.exe` 실행해도 아무 반응 없음

- **원인**: Windows 사용자명이 한글(예: `재택`)일 때, 설치기가 자기 자신을 `%TEMP%`(`C:\Users\재택\AppData\Local\Temp\...`)에 풀어놓고 내부 설치기를 실행하는 구조인데, 이 자체 추출기가 **비-ASCII(한글) 경로를 처리하지 못함**
  - 임시 폴더에 `eoi*.tmp` 폴더만 생성되고 내용은 0바이트 → 아무것도 못 쓴 채 조용히 종료(exit code 0)돼서 겉으로는 "반응 없음"처럼 보임
  - 파일 손상/서명 문제/보안 소프트웨어 충돌이 아님 (다운로드 파일 크기·서명 정상 확인됨)
- **해결**: `TEMP`/`TMP` 환경변수를 영문 경로(예: `C:\Temp`)로 임시 지정한 뒤 실행하면 정상 추출됨
  - 재실행용 배치 파일 예시:
    ```bat
    @echo off
    mkdir C:\Temp 2>nul
    set TEMP=C:\Temp
    set TMP=C:\Temp
    start "" "%~dp0eclipse-inst-jre-win64.exe"
    ```
- **설치 대상 폴더도 영문 경로 권장** (예: `C:\eclipse`) — Eclipse 본체·워크스페이스도 한글 경로에서 종종 문제 발생

## 4. ADT(ABAP Development Tools) 플러그인 설치

- Eclipse 메뉴: `Help > Install New Software`
- URL 입력: `https://tools.hana.ondemand.com/latest`
- **ABAP Development Tools** 선택 → Next → 라이선스 동의 → Finish
- Trust Authorities / Trust Artifacts 화면이 나오면 All 선택 → Trust Selected
- 설치 후 재시작 → `Window > Perspective > Open Perspective > Other > ABAP`
- 공식 가이드: [Download the Eclipse IDE and add the ADT Plugin](https://developers.sap.com/tutorials/abap-install-adt..html)

## 5. ABAP Trial 인스턴스 생성 (부스터)

- [BTP Trial Home](https://account.hanatrial.ondemand.com/trial/#/home/trial) → Go To Your Trial Account
- 왼쪽 메뉴 **Boosters** → **"Prepare an Account for ABAP Trial"** 검색 → **Start**
- 부스터가 ABAP 서비스 인스턴스 등을 자동 생성 (몇 분 소요)
- ⚠️ 계정당 인스턴스 1개만 생성 가능
- 공식 가이드: [Create an SAP BTP ABAP Environment Trial User](https://developers.sap.com/tutorials/abap-environment-trial-onboarding..html)

## 6. Eclipse에서 ABAP Cloud Project 연결

- Eclipse: `File > New > Other > ABAP Cloud Project`
- 부스터 완료 후 받은 ABAP 인스턴스 URL 입력 → "Open Logon Page in Browser"로 브라우저 로그인 → 연결 완료

## 7. 이후 학습

- [Learning Basic ABAP Programming (S4D400)](https://learning.sap.com/courses/basic-abap-programming) 코스 진행
- 상세 학습 자료: `1_사전공부/README.md` 참고

---

## 기타 결정 사항 기록

| 항목 | 결정 | 이유 |
|---|---|---|
| 환경 | SAP BTP Trial | 별도 SAP 서버 없음. 다운로드형 서버는 현재 배포 중단/EOL |
| 리전 | Singapore - Azure | 한국에서 최저 지연시간, ABAP 트라이얼 지원 |
| IDE | Eclipse ADT (VS Code 아님) | 공식 툴링이 Eclipse 전용. 강의·튜토리얼 전부 Eclipse 기준. VS Code는 커뮤니티 확장만 있고 RAP/디버깅 지원 부족 |
| Eclipse 아키텍처 | x86_64 | Intel i7-1165G7 (AMD64) |
| 90일 만료 대응 | 같은 계정으로 트라이얼 재생성 + abapGit 백업 | 연장 불가, 데이터 소멸되므로 코드 백업 필수 |
