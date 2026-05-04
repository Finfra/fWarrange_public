---
name: README
description: cliApp(fWarrangeCli) `_doc_design/` 인덱스 — 설계 SSOT 카탈로그
date: 2026-05-04
---

# 목적

cliApp(`fWarrangeCli`) helper daemon의 설계 문서 SSOT 인덱스. 양 앱 협업 규약은 paidApp 측 [`paid_cli_protocol.md`](../../../_doc_design/paid_cli_protocol.md)가 단일 SSOT.

# 문서 카탈로그

| 파일                                                              | 영역                  | 비고                                                                            |
| :---------------------------------------------------------------- | :-------------------- | :------------------------------------------------------------------------------ |
| [`cliApp_design.md`](./cliApp_design.md)                          | cliApp 아키텍처       | Sandbox 우회 분리 구조, helper daemon 설계                                      |
| [`cmd_design.md`](./cmd_design.md)                                | CLI 커맨드            | `fWarrangeCli capture/restore` 등 쉘 인터페이스                                 |
| [`RestAPI_v2.md`](./RestAPI_v2.md)                                | REST API v2           | port 3016, `/api/v2`. v1은 `z_old/RestAPI_v1.md` 아카이브 (410 Gone)            |
| [`menubar-icon-design.md`](./menubar-icon-design.md)              | 메뉴바 아이콘         | paidApp 상태에 따른 동적 아이콘 전환                                            |
| [`design_accessibility-prompt.md`](./design_accessibility-prompt.md) | Accessibility 권한    | 권한 요청 UX                                                                    |
| [`settings-folder-resolve.md`](./settings-folder-resolve.md)      | 설정 폴더 결정        | baseDirectory 인식 절차                                                         |
| [`validation_strategy.md`](./validation_strategy.md)              | API 검증 전략         | openapi.yaml ↔ apiTest ↔ cmdTest 교차 검증                                     |
| [`z_old/`](./z_old/)                                              | 아카이브              | `paidApp_version.md` (stub 통합), `RestAPI_v1.md` (deprecated 410 Gone)         |

# 관련 위치

* **양앱 협업 SSOT**: [`paid_cli_protocol.md`](../../../_doc_design/paid_cli_protocol.md) — paidApp 레포 측 단일 SSOT
* **메뉴 구조 SSOT**: [`menuBar_enhance.md`](../../_doc_design/menuBar_enhance.md) — `_public/_doc_design/` 직하 (pairApp `fSnippet`과 동일 구조)
* **paidApp 아키텍처**: [`ARCHITECTURE.md`](../../../_doc_design/ARCHITECTURE.md)
* **API 기계 판독**: [`api/openapi_v2.yaml`](../../api/openapi_v2.yaml)
* **이슈 산출물**: `cli/_doc_work/{plan,tasks,report}/`

# 갱신 규칙

* 신규 파일 추가 시 본 README의 "문서 카탈로그" 표에 한 줄 추가
* 폐기 시 `z_old/`로 이동하고 본 카탈로그에서 비고에 폐기 표시
* 양앱 SSOT 변경 시 paidApp 측 `paid_cli_protocol.md`만 수정 (양측 중복 정의 금지)
* `_public/.gitignore` 가 `cli/_doc_design/`를 일반 ignore하지만 본 카탈로그 문서들은 `git add -f`로 추적 중
