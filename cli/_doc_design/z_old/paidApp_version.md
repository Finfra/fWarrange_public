---
name: paidApp_version
description: 본 문서의 내용은 paidApp 측 _doc_design/paid_cli_protocol.md(SSOT)로 통합됨
date: 2026-04-26
---

# 통합 안내

cliApp의 paidApp 인식·실행 절차, Free/Paid 기능 경계, Bundle ID 규약, paidAppSearchPaths, observePaidAppTermination 등은 모두 paidApp 측 [`_doc_design/paid_cli_protocol.md`](../../../../_doc_design/paid_cli_protocol.md)로 통합되었음 (2026-04-26).

> ⚠️ paidApp 레포(`_public/`의 상위)에 위치한 통합 SSOT임에 유의. cliApp 단독 작업 시에도 본 stub의 링크를 따라 SSOT를 참조할 것.

# 섹션 매핑 (SSOT 기준)

| 주제                                                                | SSOT 섹션                                                                                                                                                                       |
| :------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Free vs Paid 기능 경계                                              | [§0.5](../../../../_doc_design/paid_cli_protocol.md#05-free-vs-paid-기능-경계)                                                                                                     |
| Bundle ID 규약 (`kr.finfra.fWarrange` / `kr.finfra.fWarrangeCli`)   | [§0.3 아키텍처 스냅샷](../../../../_doc_design/paid_cli_protocol.md#03-아키텍처-스냅샷)                                                                                            |
| paidApp 감지 (`detectPaidApp`, `paidAppSearchPaths`)                | [§2.1 공통 API — 경로 우선 + LaunchServices 병용](../../../../_doc_design/paid_cli_protocol.md#21-공통-api--경로-우선--launchservices-병용)                                        |
| cliApp → paidApp 설치 확인                                          | [§2.2](../../../../_doc_design/paid_cli_protocol.md#22-cliapp--paidapp-설치-확인)                                                                                                  |
| paidApp 미감지 시 알림 (`showPaidOnlyAlert`)                        | [§2.5](../../../../_doc_design/paid_cli_protocol.md#25-paidapp-미감지-시-알림-showpaidonlyalert)                                                                                   |
| cliApp → paidApp URL Scheme 호출                                    | [§1.2](../../../../_doc_design/paid_cli_protocol.md#12-cliapp--paidapp-url-scheme)                                                                                                 |
| 종료 실시간 감시 (`observePaidAppTermination`)                      | [§3.3 종료 감지 (강제 종료 포함)](../../../../_doc_design/paid_cli_protocol.md#33-종료-감지-강제-종료-포함)                                                                        |
| 시작 시 자동 실행 흐름 (Issue10)                                    | [§4.3 cliApp 시작 시 paidApp 자동 실행 흐름](../../../../_doc_design/paid_cli_protocol.md#43-cliapp-시작-시-paidapp-자동-실행-흐름-issue10)                                        |
| cliApp → paidApp 수동 기동                                          | [§4.2](../../../../_doc_design/paid_cli_protocol.md#42-cliapp--paidapp-수동-기동)                                                                                                  |
| 메뉴바 시간적 배타성 (paidApp 우선)                                 | [§7.2.1](../../../../_doc_design/paid_cli_protocol.md#721-메뉴바-시간적-배타성)                                                                                                    |
| 메뉴바 버튼 연동 (`tryLaunchPaidFeature`)                           | [§7.2.2](../../../../_doc_design/paid_cli_protocol.md#722-메뉴바-버튼-클릭-처리-trylaunchpaidfeature)                                                                              |
| UI 소유권 매트릭스                                                  | [§7.3](../../../../_doc_design/paid_cli_protocol.md#73-ui-소유권-매트릭스)                                                                                                         |
| cliApp Entitlements                                                 | [§8.1](../../../../_doc_design/paid_cli_protocol.md#81-cliapp-entitlements)                                                                                                        |
| Homebrew 배포                                                       | [§8.5](../../../../_doc_design/paid_cli_protocol.md#85-homebrew-배포)                                                                                                              |

# 관련 소스 파일

cliApp 측 구현체:

* `cli/fWarrangeCli/AppState.swift` — `detectPaidApp()`, `paidAppSearchPaths`, `observePaidAppTermination()`
* `cli/fWarrangeCli/fWarrangeCliApp.swift` — 시작 시 자동 실행 흐름 (Issue10)
* `cli/fWarrangeCli/MenuBarView.swift` — 메뉴바 시간적 배타성, `tryLaunchPaidFeature`
* `cli/project.yml` — Bundle ID SSOT (XcodeGen)
