# SAP BTP 인턴 학습 프로젝트

SAP BTP(Business Technology Platform) 기반 ABAP 학습 프로젝트.

## ⚠️ 핵심 전제 및 개발 환경

**이 프로젝트는 SAP BTP Trial 기준으로 진행한다.** 상세 내용은 아래 문서 참고:

- [핵심 전제 및 개발 환경](docs/project-premise.md)

## ABAP 작업 규칙 (MCP)

- ABAP MCP(`abap-trial`)로 조회·생성·수정할 때 기준 패키지는 **`ZPKS_INTERN_260719`** — 트라이얼은 공유 시스템이라 다른 사용자 오브젝트가 대량으로 검색되므로, 특별한 지시가 없으면 이 패키지 안의 오브젝트만 대상으로 한다.
- 새 오브젝트 생성 시에도 이 패키지에 생성하고, 이름에는 고유 접미사를 붙인다 (공유 시스템 전역 유일 제약).

## 작업 단위 규칙 (git/폴더)

- 구분되는 작업은 **전용 폴더**(`N_작업명/`) + **전용 브랜치**(`work/N-영문슬러그`)로 진행하고, 작업 종료 시에만 `--no-ff`로 main에 merge한다 (merge 후 브랜치 보존).
- 새 작업 시작 시 브랜치 생성부터. 상세 규칙(네이밍·merge 방식·예외): [작업 단위 규칙](docs/workflow-rules.md)

## 폴더 구조

```
SAP_BTP_인턴/
├── CLAUDE.md          # 이 파일 — 프로젝트 전제 및 구조
├── README.md          # 프로젝트 소개
├── docs/              # 프로젝트 문서
│   ├── project-premise.md   # 핵심 전제 및 개발 환경
│   ├── setup-guide.md       # BTP Trial + Eclipse/ADT + abapGit + MCP 세팅 절차·트러블슈팅
│   ├── research-notes.md    # 조사·의사결정 기록 (환경/도구를 왜 선택했는가)
│   └── workflow-rules.md    # 작업 단위 규칙 (폴더 + 브랜치 운용)
└── 1_사전공부/         # 학습 자료 링크와 학습 순서 (README.md 참고)
```

새 폴더를 추가하면 위 구조에 반영할 것.
