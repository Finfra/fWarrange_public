---
title: fWarrangeCli TDD 재생목록
description: prj26 fWarrangeCli 의 TDD 목표를 재생 순서로 나열한 목록 (prj6#Issue16)
date: 2026.09.26
---

# 무엇을 지키나

창 레이아웃 캡처와 복구 REST, 설정 영속성, brew 서비스 기동, 권한 상실 감지가 조용히 실패하지 않게 지킨다

* 기존 러너: `bash cli/_tool/fwc-test.sh (8단계 통합) / bash cli/_tool/apiTestDo.sh v2 / bash cli/_tool/cmdTestDo.sh v2 / XCTest 타깃 cli/fWarrangeCliTests`
* 목표 13개 중 기존 테스트로 덮인 것 5개 · 신규 8개 (prj5#Issue99 · Issue101 · Issue104, 2026.09.27)
* 최종 실행: **jma** — XCTest 84/84 passed (Issue101 이후)(`xcodebuild test`, test plan 격리) · `fwc-test.sh` ALL CLEAR 6 PASS / 0 FAIL
* 테스트 호스트 격리: [fWarrangeCli.xctestplan](cli/fWarrangeCli.xctestplan) 이 `fWarrangeCli_config`·`FWARRANGE_DISABLE_HOTKEYS`·`FWARRANGE_PORT` 를 주입 — 실데이터 폴더·사용자 단축키·3016 포트를 건드리지 않는다

# 재생목록

위에서 아래로 돈다 — 빠르고 기초적인 것이 먼저, 통합·E2E 가 뒤다. 앞 항목이 깨지면 뒤 항목의 실패는 원인이 아니라 결과일 수 있다.

| # | id | 목표 | 근거 | 실행 | 상태 |
| :- | :- | :- | :- | :- | :- |
| 1 | `api-version-smoke` | REST 서버 API 버전 상수가 기대값이고, 테스트 호스트 번들이 로드된다 | cli/fWarrangeCliTests/FWarrangeCliSmokeTests.swift | `cli/fWarrangeCliTests/FWarrangeCliSmokeTests.swift` | ✅ 기존 |
| 2 | `brew-label-recognition` | brew 서비스 라벨을 sh.brew.*·homebrew.mxcl.*·formula 접미사 규약으로 모두 인식하고, 관계없는 라벨과 nil은 거부해서 self-handoff 무한 루프가 생기지 않는다 | Issue95(sh.brew.* 규약 변경으로 무한 self-handoff), cli/fWarrangeCliTests/ServiceLabelAndPermissionTests.swift | `cli/fWarrangeCliTests/ServiceLabelAndPermissionTests.swift` | ✅ 기존 |
| 3 | `dead-key-removed` | showInCmdTab 죽은 키가 settings 응답에 없고, PATCH로 보내도 무시된다. 이웃 advanced 키는 남아 있다 | Issue94(showInCmdTab 죽은 키 제거), ServiceLabelAndPermissionTests.swift testDeadSettingKey* | `cli/fWarrangeCliTests/ServiceLabelAndPermissionTests.swift` | ✅ 기존 |
| 4 | `paidapp-state-store` | paidApp 등록·상태·해제 사이클과 상태 로그 기록이 올바르게 동작한다 | cli/fWarrangeCliTests/PaidAppStateStoreTests.swift·PaidAppRouterTests.swift·PaidAppStateLoggerTests.swift, Issue75(terminate 핸들러 .cliOnly 오전환) | `cli/fWarrangeCliTests/PaidAppStateStoreTests.swift` | ✅ 기존 |
| 5 | `runtime-permission-loss` | 운영 중 접근성 권한이 없어지면 창 조작 액션이 이를 감지하고 사용자에게 안내한다(조용히 실패하지 않는다) | Issue96(권한을 AppState.swift:467 시작 시에만 확인함, 운영 중 제거되면 단축키가 조용히 죽음). 테스트는 권한 요구 매핑(testWindowActionsRequireAccessibility)만 있음 | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testWindowAction*) | ✅ 신규 |
| 6 | `tab-patch-bool-false` | /api/v2/settings/{tab} PATCH로 보낸 Bool false 값이 디스크에 저장되고, 동시에 PATCH해도 lost update가 생기지 않는다 | Issue80(탭별 PATCH Bool false 미영속화, 동시성 lost update) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testTabPatchBoolFalseIsPersisted·testConcurrentTabPatchesDoNotLoseUpdates) | ✅ 신규 |
| 7 | `change-tracker-records` | LayoutManager CRUD 경로마다 ChangeTracker.record가 호출되어 /changes 폴링에 변경이 잡힌다 | Issue73(ChangeTracker 발행 누락 + LayoutManager SSOT 누수) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testLayoutCrudPathsRecordChanges) | ✅ 신규 |
| 8 | `owner-name-mismatch-restore` | CGWindowOwnerName과 localizedName이 다른 앱(VSCode 등)도 레이아웃 복구 때 맞게 매칭된다 | Issue71(VSCode 등 이름 불일치 앱 복구 실패) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (AppMatcher 4건 — 빈 저장명 와일드카드 버그 수정 포함) | ✅ 신규 |
| 9 | `config-defaults-e2e` | _config.yml을 지운 뒤 기동하면 기본값 19개 필드가 생성되고, API·CMD 테스트 전체가 통과하며, 로그에 ERROR가 없다 | cli/_tool/fwc-test.sh (Step 1~7), CLAUDE.md 테스트 섹션 | `bash cli/_tool/fwc-test.sh` + `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testMissingConfigIsSeededWithDefaults) | ✅ 기존 |
| 10 | `version-label-match` | brew 패키지 라벨 버전, 앱 번들 버전, VERSION 파일이 서로 같다 | Issue89(brew 라벨 1.1.0 vs 번들 1.0.2 배포 사고), Issue91 | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testVersionSourcesAgree) | ✅ 신규 |
| 11 | `test-host-isolation` | XCTest 호스트(앱 바이너리 자체)가 실데이터 폴더 `~/Documents/finfra/fWarrangeData` 를 해석하지 않고, 글로벌 단축키를 등록하지 않는다 | prj5#Issue99 1차 라운드 발견(테스트 실행 중 Logger·PaidAppStateLogger 가 사용자 실데이터 폴더에 기록) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (testTestHost*) + `cli/fWarrangeCli.xctestplan` | ✅ 신규 |
| 12 | `rest-listener-lifecycle` | 프로세스당 AppState 는 1개이고, RESTServer 가 해제·재시작·중지되면 listener 도 닫혀 포트를 쥔 채 무응답이 되지 않는다 | Issue101(jma 3016 연결 accept 후 무응답 — AppState 이중 생성 + 고아 NWListener) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (RESTListenerLifecycleTests) | ✅ 신규 |
| 13 | `accessibility-boot-listing` | 미승인으로 부팅한 새 프로세스는 시스템 권한 요청을 정확히 1회 보내 손쉬운 사용 목록에 올라가고, 승인 상태로 부팅하면 아무것도 묻지 않는다 | Issue104(jma 에서 목록 미등록 → 수동 추가. 낡은 ad-hoc 서명 전제 정정) | `cli/fWarrangeCliTests/TDDPlaylistTests.swift` (AccessibilityBootListingTests) | ✅ jma |

# 규약

* **목표는 «검증 가능한 성질»** 이다 — *"잘 동작한다"* 는 목표가 아니다
* 새 버그를 고치면 **재현 테스트를 먼저** 여기 한 줄로 올리고(⬜), 테스트가 생기면 실행 열을 채워 ✅ 로 바꾼다
* 실패를 삼키는 패턴(`2>/dev/null || true` 등)을 테스트 안에 쓰지 않는다 — 실패는 실패로 드러나야 한다
* 판정 출처: prj6 `_doc_work/report/tdd-coverage_report.md` (이 프로젝트가 왜 TDD 대상인가)
