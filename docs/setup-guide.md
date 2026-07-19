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
- **워크스페이스는 git 저장소 하위에 두지 말 것** (로컬 `C:\workspace` 사용):
  - 이 프로젝트 저장소 경로에는 한글이 포함되어 있음
  - ABAP Cloud Project의 실제 소스는 BTP 서버에 저장됨 — 워크스페이스는 뷰/캐시일 뿐이라 git으로 추적할 실익 없음
  - ABAP 소스 백업/버전관리는 abapGit으로 별도 진행하는 게 정석
  - 워크스페이스의 `.metadata`(IDE 설정·인덱스·로그)가 git에 딸려 들어가면 저장소만 지저분해짐

### 참고: 실행 시 나타나는 보안 관련 창

- **Microsoft Defender Exclusion Check** (ADT가 띄우는 안내): Defender 실시간 검사가 Eclipse 작업 폴더를 매번 스캔하면 느려질 수 있어 예외 등록을 권장하는 것
  - 개인 PC면 `Windows 보안 > 바이러스 및 위협 방지 > 제외 항목`에 `C:\eclipse`, `C:\workspace` 폴더 추가 (관리자 권한 필요)
  - 필수 아님 — 건너뛰어도 동작에는 문제없고 성능만 다소 저하. 회사 보안 정책이 있는 PC면 건너뛸 것

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
  - Trust Artifacts에서 `javax.wsdl` 같은 **Unsigned 항목 경고**가 뜨는 건 정상 (ADT가 의존하는 구형 라이브러리가 미서명 배포되던 시절 번들) → Unsigned 체크 후 Trust Selected
  - 단, **"Always trust all content"는 체크하지 않기** — 앞으로 모든 미서명 콘텐츠를 무조건 신뢰하는 전역 설정이라 개별 신뢰가 더 안전
- 설치 후 재시작 → `Window > Perspective > Open Perspective > Other > ABAP`
  - 목록에 ABAP이 없으면 ADT 설치 미완료 또는 재시작 안 된 상태
- 공식 가이드: [Download the Eclipse IDE and add the ADT Plugin](https://developers.sap.com/tutorials/abap-install-adt..html)

## 5. ABAP Trial 인스턴스 생성 (부스터)

- [BTP Trial Home](https://account.hanatrial.ondemand.com/trial/#/home/trial) → Go To Your Trial Account
- 왼쪽 메뉴 **Boosters** → **"Prepare an Account for ABAP Trial"** 검색 → **Start**
- 부스터가 ABAP 서비스 인스턴스 등을 자동 생성 (몇 분 소요)
- ⚠️ 계정당 인스턴스 1개만 생성 가능
- 공식 가이드: [Create an SAP BTP ABAP Environment Trial User](https://developers.sap.com/tutorials/abap-environment-trial-onboarding..html)

## 6. Eclipse에서 ABAP Cloud Project 연결

- **인스턴스 URL 확인**: BTP Cockpit → 서브계정(trial) → `Services > Instances and Subscriptions` → 부스터가 만든 ABAP environment 인스턴스에서 URL 복사
  - 형태: `https://<시스템ID>.abap.ap21.hana.ondemand.com` (ap21 = Singapore 리전). 일반 웹사이트가 아니라 본인 전용 ABAP 시스템의 접속 엔드포인트
- Eclipse: `File > New > Other > ABAP Cloud Project` → **SAP BTP ABAP Environment** 선택
- 연결 방식: **"Use a Service Instance URL"** 선택 후 URL 붙여넣기 (서비스 키 JSON 방식도 있으나 URL이 더 간단)
- **"Open Logon Page in Browser"** → 브라우저에서 트라이얼 SAP 계정으로 로그인 → Eclipse로 돌아오면 자동 연결
- 프로젝트 이름은 자유 (예: `Connect_Test_260719`)
- **Working Sets는 체크 안 하고 Finish** — 프로젝트가 많아졌을 때의 그룹핑 기능일 뿐, 나중에 언제든 추가 가능

## 7. 연결 검증 — Hello World

- 화면에 Project Explorer가 안 보이면: `Window > Show View > Project Explorer` (또는 `Window > Perspective > Reset Perspective`)
- `File > New > ABAP Class` → Package: 본인 패키지(아래 공유 시스템 참고), Name: `ZCL_HELLO_<고유접미사>`
- 코드:
  ```abap
  CLASS zcl_hello_xxx DEFINITION
    PUBLIC FINAL CREATE PUBLIC.
    PUBLIC SECTION.
      INTERFACES if_oo_adt_classrun.
  ENDCLASS.

  CLASS zcl_hello_xxx IMPLEMENTATION.
    METHOD if_oo_adt_classrun~main.
      out->write( 'Hello World from BTP Trial!' ).
    ENDMETHOD.
  ENDCLASS.
  ```
- **Ctrl+F3**(활성화 — 저장만으로는 반영 안 됨) → **F9**(콘솔 실행) → Console 뷰에 출력 확인되면 환경 구축 완료

### ⚠️ BTP Trial은 공유 시스템 — 네이밍/보안 주의

- 트라이얼 ABAP 시스템은 **전 세계 트라이얼 사용자가 함께 쓰는 공유 시스템** (ZLOCAL 하위에 타 사용자 패키지 수만 개 존재)
- **작업 공간**: `ZLOCAL`을 superpackage로 하는 **본인 패키지**를 만들어 그 안에서 작업 (`File > New > ABAP Package`, transport 불필요). 트라이얼에선 ZLOCAL 계열이 사실상 유일한 작업 공간
- **네이밍**: `Z` 네임스페이스를 모든 사용자가 공유하므로 오브젝트 이름은 시스템 전체에서 유일해야 함. `ZCL_HELLO_WORLD` 같은 뻔한 이름은 이미 선점됐을 확률 높음 → **이니셜+날짜 등 고유 접미사** 사용 (예: `ZPKG_KS0719`, `ZCL_HELLO_KS0719`)
- **보안**: 내가 만든 오브젝트는 다른 트라이얼 사용자에게도 보임 → **실제 업무 데이터·회사 정보·자격증명 절대 금지**, 교육용 코드만

### ⚠️ ABAP Cloud 언어 제약 — 만들 수 있는 것 / 없는 것

BTP ABAP 환경은 **"ABAP for Cloud Development"라는 제한된 언어 버전만 허용** (트라이얼 한정이 아니라 유료 BTP ABAP 환경도 동일 — SAP가 의도적으로 클라우드에서는 모던 개발 모델만 쓰도록 설계한 것).

**가능 ✅**

- 데이터베이스 테이블 (ADT에서 생성, HANA 저장, 데이터 입력/조회 정상)
- CDS View, 클래스, 인터페이스
- RAP 기반 서비스 (Business Object, Service Definition/Binding → OData 노출)
- → **Mock 시스템(테이블 + CDS + RAP/OData) 구축 및 외부 OData 호출 수신 시나리오 모두 가능**

**불가 ❌ — ECC식 클래식 개발**

| 클래식 ABAP | BTP (ABAP Cloud) 대체 수단 |
|---|---|
| Function Module (SE37) | 클래스 메서드 |
| 리포트 프로그램 (`REPORT`, `WRITE`) | `if_oo_adt_classrun` 콘솔 클래스 |
| Dynpro / Module Pool 화면 | Fiori Elements |
| SAP GUI 트랜잭션 (SE80, SE11 등) | 모든 개발은 ADT(Eclipse)에서만 |
| SAP 표준 테이블 직접 SELECT | released API / CDS만 접근 가능 |

- Function Module은 "구식이라 없어진 것"이 아님 — 온프레미스 S/4HANA·ECC에서는 지금도 실무에서 대량 사용. BTP ABAP 환경(Steampunk)이 클라우드 확장 전용으로 설계되면서 처음부터 배제한 것
- 따라서 **클래식 ABAP(FM, 리포트, GUI) 연습이 교육 목표에 포함된다면 BTP Trial로는 불가** — 이 갭은 인지할 것
- 트라이얼이라서 추가로 걸리는 제약(유료면 풀림): Destination Service 미지원(아웃바운드), 공유 시스템, 리소스 쿼터, 90일 만료, 인스턴스 1개

## 8. abapGit 세팅 (90일 만료 대비 백업 + 코드 공유)

> BTP ABAP 환경은 서버 쪽 abapGit이 **이미 내장** — 온프레미스처럼 ZABAPGIT 설치 불필요. Eclipse 플러그인만 추가하면 됨.

1. **GitHub에 ABAP 코드 전용 repo 생성** (예: `abap_backup`)
   - 문서 repo와 **분리** — abapGit이 repo 루트에 `.abapgit.xml`과 패키지 폴더 구조를 만들기 때문
   - README 포함으로 생성 (빈 repo는 브랜치가 없어 연결이 번거로움), Private 권장
2. **GitHub Fine-grained PAT 발급** (push 인증용 — 비밀번호 인증은 폐지됨)
   - GitHub → Settings → Developer settings → Personal access tokens → Fine-grained token
   - **Contents: Read and write만 부여** (Metadata: Read-only는 자동 포함). 나머지 권한 불필요
   - Repository access는 "Only select repositories"로 해당 repo만 지정
   - Expiration은 트라이얼 주기에 맞춰 90일 권장. 토큰은 발급 화면에서만 보이므로 안전하게 보관
3. **Eclipse에 abapGit 플러그인 설치**
   - `Help > Install New Software` → `https://eclipse.abapgit.org/updatesite/`
   - "abapGit for ABAP Development Tools" 설치 → 재시작
4. **저장소 연결**
   - `Window > Show View > Other > ABAP > abapGit Repositories` 뷰 열기
   - "+" (Link New abapGit Repository) → repo URL, Branch `main`, Package: 본인 패키지(`ZPKG_...`)
   - 인증: GitHub 사용자명 + PAT
5. **Push**: 뷰에서 repo 우클릭 → **Stage and Push** → 오브젝트 선택, 커밋 메시지 → Push → GitHub에서 확인

### 트러블슈팅 / 참고

- **"No ABAP Project Active"**: abapGit 뷰는 현재 활성 ABAP 프로젝트 기준으로 동작 → Project Explorer에서 ABAP 프로젝트를 클릭(또는 프로젝트 내 오브젝트를 에디터로 열기)하면 해결
- **Credentials Manager "store in secure storage?"**: 개인 PC면 **예** — 인증정보가 암호화 저장되어 매번 토큰 입력 불필요. "아니요"는 기존 저장 정보도 삭제하므로 토큰 교체 시 활용
- **복원 방법**: 새 트라이얼에서 패키지 생성 → 같은 repo Link → **Pull**
- **3인 공유**: repo에 collaborator 추가, 각자 PAT는 각자 발급

## 9. Claude Code ↔ ABAP MCP 연동 (mcp-abap-adt)

> 목적: Claude Code에서 트라이얼 ABAP의 코드·테이블 조회 및 full-access.
> 서버 선정 배경은 `1_사전공부/README.md`의 MCP 조사 섹션 참고 (vibing-steampunk는 BTP 인증이 쿠키 방식이라 보류, 서비스 키 OAuth를 지원하는 fr0ster/mcp-abap-adt 채택).

### 세팅 절차

1. **서비스 키 발급** (BTP Cockpit)
   - 서브계정 → `Services > Instances and Subscriptions` → ABAP 인스턴스(`default_abap-trial`)
   - 부스터가 만든 키가 이미 1개 있음 (Credentials "1 key"). 그대로 써도 되고, `⋯ > Create Service Key`로 MCP 전용 키(예: `mcp-key`)를 분리 발급하면 관리가 깔끔 (용도별 폐기 가능)
   - 키 JSON은 **git 저장소 밖에** 저장: `C:\Users\<사용자>\Documents\mcp-abap-adt\service-keys\TRIAL.json`
2. **Node.js 설치** (없다면): `winget install OpenJS.NodeJS.LTS`
3. **MCP 서버 설치** (fr0ster/mcp-abap-adt — 패키지 2개가 한 세트):
   ```
   npm install -g @mcp-abap-adt/core @mcp-abap-adt/connection
   ```
   - `@mcp-abap-adt/core` = 서버 본체(`mcp-abap-adt` 명령), `connection` = 인증 도구(`sap-abap-auth` 명령)
4. **브라우저 OAuth 인증** → JWT 담긴 `.env` 생성:
   ```
   sap-abap-auth auth -k "%USERPROFILE%\Documents\mcp-abap-adt\service-keys\TRIAL.json" -b system -o "%USERPROFILE%\Documents\mcp-abap-adt\sessions\TRIAL.env"
   ```
   - 브라우저가 열리면 트라이얼 SAP 계정으로 로그인
5. **프로젝트 루트에 `.mcp.json` 등록** (비밀정보 없음 — env 파일 경로만 참조하므로 커밋 안전):
   ```json
   {
     "mcpServers": {
       "abap-trial": {
         "command": "mcp-abap-adt",
         "args": [
           "--transport=stdio",
           "--env-path=C:\\Users\\<사용자>\\Documents\\mcp-abap-adt\\sessions\\TRIAL.env",
           "--exposition=readonly,high,low"
         ]
       }
     }
   }
   ```
   - `--exposition`: `readonly`(조회)만 노출할지, `high`(생성/수정), `low`(삭제/활성화 등 위험 작업)까지 노출할지 선택. full-access는 `readonly,high,low`
6. **Claude Code 재시작** → `abap-trial` MCP 로드됨

### 검증 결과 (2026-07-19)

- SearchObject로 시스템 검색 정상 (공유 시스템이라 타 사용자 오브젝트 대량 검색됨 — CLAUDE.md에 기준 패키지 규칙 명시로 대응)
- GetPackageContents로 본인 패키지(`ZPKS_INTERN_260719`) 조회 정상 — Hello World 클래스 확인
- 노출 툴 60여 개: 테이블 데이터 조회(GetTableContents), 클래스/CDS/RAP 아티팩트 읽기, SQL 쿼리, 클래스 실행(RuntimeRunClass), Where-Used 등

### 참고

- **토큰 갱신**: JWT 만료 시 refresh token으로 자동 갱신. refresh token까지 만료되면 4번 명령 재실행
- **기준 패키지 규칙**: 조회·생성은 `ZPKS_INTERN_260719` 패키지 기준 (CLAUDE.md "ABAP 작업 규칙" 참고)

## 10. 이후 학습

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
| Eclipse 패키지 | Eclipse IDE for Java Developers | SAP 공식 튜토리얼 기준. Enterprise/C++ 등은 불필요 |
| 워크스페이스 위치 | 로컬 `C:\workspace` (git 저장소 밖) | 한글 경로 회피 + ABAP 소스는 서버 저장이라 git 추적 실익 없음 |
| 90일 만료 대응 | 같은 계정으로 트라이얼 재생성 + abapGit 백업 | 연장 불가, 데이터 소멸되므로 코드 백업 필수 |
| MCP 서버 | fr0ster/mcp-abap-adt (vibing-steampunk 보류) | 서비스 키 OAuth 자동 갱신 지원. vsp는 BTP 인증이 쿠키 수동 추출 방식이라 불안정 |
| 작업 패키지 | `ZPKS_INTERN_260719` (superpackage: ZLOCAL) | 공유 시스템이라 본인 패키지로 범위 한정. CLAUDE.md에 규칙 명시 |
