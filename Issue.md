---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 80
* Save Point: 2026-05-18 (Issue78 종결 — /operations + op.* 이벤트 + 직렬화 enforce)
  - 609c51d (2026-06-15) - cli/_doc_arch 7문서 정합성 감사 완료 (리포트 cli/_doc_work/report/cli-doc-arch-audit_report.md, 미커밋 산출물)
  - 53f2dfe (2026-05-18) - Feat(Issue78)(REST): /operations + op.* 이벤트 + 직렬화 enforce
  - 39004f7 (2026-05-18) - Docs: Close Issue77
  - 7b2e44b (2026-05-17) - Docs: Close Issue75
  - fc33e79 (2026-05-16) - Feat(Issue74)(REST): 레이아웃 복구 응답에 실패 윈도우 상세 정보 노출



# 🤔 결정사항
* `~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` 기준 진행(상위 메인 레포, paidApp앱과 연동)
* `cli/_doc_arch/menuBar_enhance.md` 기준 진행(메뉴바, 로컬 SSOT — gitignored)
* **Issue72_1 베이스라인 검토일: 2026-05-22** — 통계 인프라 가동 후 1주일(2026-05-15~22) 실사용 데이터 수집 → `cli/_doc_work/report/window_recognize_baseline.md` 보고서 작성 → Issue72_1 ✅ 완료 처리 → Phase 2~7 우선순위 데이터 기반 재조정
* **Issue72_6 비공개 API 도입 합의 (2026-05-16)** — cliApp(non-sandbox)에서 CGSGetActiveSpace·CGSCopySpacesForWindows·CGSMainConnectionID 사용. App Store 영향 無 (cliApp은 brew 배포). macOS 업데이트 시 폐기 가능성 대비 nil 반환 안전망 보유. 상위 `_doc_arch/paid_cli_protocol.md` 차기 갱신 시 반영 권장.

# 🌱 이슈후보
1. brew remote등록
2. 앱이 비활성화될때 자동으로 레이아웃을 캡쳐하는 기능(이렇게 캡쳐된 레이아웃은 저장 기간 옵션에 따라 자동 삭제되어야 하고 paidApp에서 레이아웃 리스트에 별도의 표식이 있어야함. )

# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료
## Issue80: [REST] `/api/v2/settings/{tab}` 탭별 PATCH Bool `false` 미영속화 — 동시성 lost update 재현·수정 (등록: 2026-06-15, 완료: 2026-06-15, Hash: e62208b) ✅
* 목적: Phase 4(Issue72_4) 당시 발견된 "탭별 PATCH가 Bool false를 디스크에 영속화하지 않음(전체 `/settings` PATCH는 정상)" 후보를 검증·종결
* 조사 1차 (순차 단일 PATCH — 재현 안 됨):
    - Bool 7개 필드 전부 탭별 단일 PATCH `false` → 디스크 영속화 정상 라이브 확인 (`enableParallelRestore`·`matchAreaMatchEnabled`·`autoSaveOnSleep`·`confirmBeforeDelete`·`showInCmdTab`·`clickSwitchToMain`·`launchAtLogin`)
    - `applySettingsPatch`는 `as? Bool`로 false 정상 처리, YAML round-trip(`Bool("false")` 파싱)도 정상
* 조사 2차 (동시 PATCH — **재현됨**): 서로 다른 6개 bool 필드를 **동시(concurrent) burst**로 `false` PATCH → 3개만 persist, 나머지는 default(true)로 잔존하는 **lost update** 확정. 순차 테스트만으로는 놓치는 race
* 근본 원인: **Issue78(`53f2dfe`)** 이 settingsPatch를 OperationRegistry "동시 허용"으로 풀었으나, 핸들러는 비원자적 `load()→mutate→save()`(전체 `_config.yml` 통째 쓰기)를 수행. 동시 요청이 stale state를 로드 후 마지막에 save하면 다른 요청의 `false` write가 default(true)로 clobber됨. baseline-default가 true인 필드의 false 만 손실 → "Bool false 미영속화"로 관측됨. 전체 `/settings` PATCH가 정상이던 이유 = 단일 원자 요청이라 무경합
* 수정:
    - `SettingsService` 프로토콜에 원자적 `mutate(_:)` 추가 + 프로세스 전역 `SettingsMutationLock`(NSLock)으로 `load→transform→save` 직렬화 (`SettingsService.swift`)
    - `AppState`의 설정 read-modify-write closure 전수 라우팅 — patchSettings/updateShortcuts/excludedApps 4종/defaultLayoutName/applyApiSettings/hotkey-save (`AppState.swift`)
* 검증: Debug 빌드·배포 후 6개 필드 동시 false burst x3 라운드 → 전부 false persist (lost update 0건, PASS)
* 비고: 선행 조사가 순차 단일 PATCH만 보고 "재현 불가"로 1차 판정했으나, Issue78이 도입한 동시 허용 경로를 concurrent burst로 검증하니 race 재현. 본 종결은 그 정정

## Issue79: [Docs/Plugin] API 문서 + LLM plugin(prj20) 최신화 — cliApp/brew 전환 반영 (등록: 2026-06-13, 완료: 2026-06-13) (Hash: 0b2536e, prj20 8ec2ade·4cfed60) ✅ (fSnippet #25 Issue166 미러)
* 목적: fWarrange 공개 문서·prj20 LLM plugin 이 paidApp GUI 기준으로 stale. cliApp(fWarrangeCli)/brew 운영 모델로 동기화
* 구현:
    - prj20 `f-claude-plugins/fWarrange/skills/fwarrange/SKILL.md` (8ec2ade): prereq `open -a fWarrange`+"Settings > API tab Enable" → `brew install/services start finfra/tap/fwarrange-cli`. date bump
    - prj20 SKILL.md health check 정정 (4cfed60): Step1 `GET /health` → `GET /` — 라이브 실행 중 `/health` 가 HTTP 404 반환 확인(`/` 는 200). 서버 기동 중에도 미기동 오판정하던 버그
    - `_public/api/README.md`·`README_kr.md` (0b2536e): Server "macOS Native App" → fWarrangeCli helper(Homebrew), 기본 상태 비활성→활성(localhost), OpenAPI 스펙 포인터에 v2(현행 전체 API) 추가·v1 레거시 표기
* 검증: fwarrangecli brew 서비스 기동 → REST 3016 GET / HTTP 200 (`app=fWarrangeCli, version 1.0.1, isRunning=true`). prereq GUI런치 0건, brew명 하이픈 정확
* 참고: README 본문 엔드포인트 일부 `/api/v1/*` 표기 — 전면 v1→v2 재작성은 본 이슈 범위 밖(별도 후보). 본 이슈는 운영 모델(cliApp/brew) + 스펙 포인터까지
## Issue78: [REST] 장기 동작 진행 상태 노출 (일반화) — `/operations` + `op.*` 이벤트 발행 (등록: 2026-05-18, 완료: 2026-05-18, commit: 53f2dfe) ✅
* 목적: capture 한정이 아니라 cliApp 모든 long-running 핸들러(capture, restore, layout.delete/rename, settings.patch, shortcuts.set, factoryReset)에 진행 상태 노출 채널을 제공. paidApp이 op type별 진행 메시지·완료 감지·행 대응을 통합 관리할 수 있게 함. 상위 SSOT(`~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` §6.7 일반화) 반영.
* depends: paidApp 측 `Issue254`가 본 이슈에 의존 (paidApp이 사용하려면 cliApp endpoint·이벤트가 먼저 가용해야 함)
* 구현 결과:
    - 신규 actor `OperationRegistry` (`cli/fWarrangeCli/Services/OperationRegistry.swift`): UUID 발급, 직렬화 enforce(capture/restore/factoryReset), op.started/finished/failed 발행
    - 신규 enum `OpType`, struct `Operation` (`cli/fWarrangeCli/Models/`)
    - `ChangeTracker.record(...)`에 `opId: String?` 옵셔널 인자 추가, ChangeEvent 직렬화에 포함
    - `GET /api/v2/operations` 라우팅 추가 (idle 시 `{"operations":[]}`, 진행 중 시 스냅샷)
    - 대상 핸들러 모두 register/complete 경로 적용 + 직렬화 위반 시 `409 Conflict`:
        * REST: handleCapture / handleRestore / handleRenameLayout / handleDeleteLayout / handleSetShortcuts / handleFactoryReset / settings PATCH(전체+탭별)
        * HotKey: AppState.handleHotKeyAction(.save) Cmd+F7 경로도 OperationRegistry 경유
* 검증 결과 (Debug 빌드 + 로컬 실행):
    - `GET /operations` idle → `{"operations":[]}`
    - 동시 두 번 `POST /capture` → 첫 200, 둘째 `409 Conflict` (`capture가 이미 진행 중입니다`)
    - `GET /changes` 응답에 `op.started(opId) → layout.created → op.finished(opId)` 순서 확인
    - 동시 `PATCH /settings/general` + `PATCH /settings/restore` → 둘 다 200 (동시 허용 OK)

## Issue77: [Logging] cliApp 로그 파일명을 `wlog_cliApp.log`로 변경 — paidApp과 명명 대칭 (등록: 2026-05-18) (✅ 완료, 39004f7) ✅
* 목적: 현재 cliApp(fWarrangeCli) 로그가 `~/Documents/finfra/fWarrangeData/logs/wlog.log`로 출력됨. paidApp(fWarrange)도 동일 데이터 폴더 공유 시 식별 어려움 → cliApp을 `wlog_cliApp.log`로 명명 분리. fSnippet Issue132와 동일 패턴(`flog_cliApp.log`) 미러링.
* 상세:
    - 현재 경로: `~/Documents/finfra/fWarrangeData/logs/wlog.log` (실시간), `wlog_YYYY-MM-DD_HH-mm-ss.log` (세션 아카이브)
    - 변경 후: `wlog_cliApp.log` (실시간), `wlog_cliApp_YYYY-MM-DD_HH-mm-ss.log` (세션 아카이브)
    - 코드 위치:
        - `cli/fWarrangeCli/Utils/Logger.swift` L68 (logFileURL), L118 + L142 (archivedLogURL)
        - `cli/fWarrangeCli/AppState.swift` L244 (REST 응답용 경로)
        - `cli/_tool/fwc-test.sh` L25, `cli/_tool/apiTestDo.sh` L26, `cli/_tool/cmdTestDo.sh` L24 (테스트 LOG_FILE)
* 구현 명세:
    - Logger.swift L68: `"wlog.log"` → `"wlog_cliApp.log"`
    - Logger.swift L118, L142: `"wlog_\(sessionDateString).log"` → `"wlog_cliApp_\(sessionDateString).log"`
    - AppState.swift L244 + 테스트 스크립트 LOG_FILE 동기화
    - 기존 `wlog.log` grep으로 `.claude/`, `cli/`, README 전 영역 정리 (로컬 룰·스킬 문서 포함)
    - 검증: 재배포 후 `wlog_cliApp.log` 생성 + 기존 `wlog.log` 미갱신 확인
    - 옛 `wlog.log` 자동 마이그레이션 미적용 (사용자 수동 삭제)
* 관련: fSnippet Issue132 (대응 패턴), 향후 paidApp(fWarrange) 로그 폴더 Library/Logs 이관 이슈와 별개

## Issue75: PaidAppMonitor terminate 핸들러 — 잔존 인스턴스 무시하여 .cliOnly 오전환 (등록: 2026.05.17) (✅ 완료, 7b2e44b) ✅
* 목적: paidApp 다중/단명 인스턴스 발생 시 한 인스턴스 종료만으로 메뉴바가 cliApp 아이콘으로 잘못 복원되는 문제 해결
* 상세:
    - 현상: paidApp 활성 상태인데 메뉴바 아이콘이 cliApp 아이콘으로 표시됨
    - 재현 로그: `~/Documents/finfra/fWarrangeData/logs/wlog.log` 23:43:26~27 구간 — pid 61357 launch→terminate 직후 잔존 pid 60997 무시하고 `.cliOnly` 전환
    - 위치: `cli/fWarrangeCli/Managers/PaidAppMonitor.swift:53-67` `didTerminateApplicationNotification` 핸들러
* 구현 명세:
    - **파일**: `cli/fWarrangeCli/Managers/PaidAppMonitor.swift`
    - **변경 함수**: `startObserving(onTerminate:)` 내부 `didTerminateApplicationNotification` 클로저
    - **변경 로직**:
        - terminate 알림 수신 후 `Task { @MainActor }` 본문에서 `NSRunningApplication.runningApplications(withBundleIdentifier: self.paidAppBundleId).isEmpty` 잔존 체크 추가
        - 잔존 인스턴스 존재 시: state 유지 + `onTerminateCallback` 호출 금지 + 정보 로그만 기록 후 early return
        - 잔존 없을 때만: `state = .cliOnly` + 기존 로그 + `onTerminateCallback?(app)` 실행
    - **부가 정리**: `app.bundleIdentifier == "kr.finfra.fWarrange"` 하드코딩을 `self.paidAppBundleId` 상수 참조로 통일
    - **검증**: Release 빌드 `BUILD SUCCEEDED` 확인. cliApp 재기동 후 paidApp 살아있는 상태에서 paidApp 단명 인스턴스(launchPaidApp self-terminate 등) 발생 시 메뉴바 아이콘이 paidApp 활성 유지되어야 함



## Issue74: [REST] 레이아웃 복구 응답에 실패 윈도우 상세 정보 노출 (등록: 2026-05-16, 완료: 2026-05-16, commit: fc33e79) ✅
* 목적: paidApp Issue246(복구 실패 상세 보기) 선수 작업. `POST /api/v2/layouts/{name}/restore` 응답 `data`에 `failures` 배열을 추가하여 paidApp이 실패한 윈도우의 식별 정보·실패 사유를 표시할 수 있게 함.
* 선행 관계: 상위 paidApp Issue246의 **선수 이슈**
* plan: `cli/_doc_work/plan/restore_failures_response_plan.md`
* 구현 명세:
    - **Phase 1 — OpenAPI v2 스펙 확장 (`api/openapi_v2.yaml`)**:
        - `RestoreFailureItem` 스키마 신설 (app/title/layer/id/pos/size/reason)
        - `reason` enum: appNotRunning, windowNotFound, belowMinimumScore, axOperationFailed, other
        - `RestoreResponse.data.failures` 필드 추가
        - 예시 응답 2종 (allSuccess, partialFailure)
    - **Phase 2 — RESTServer 구현 (`cli/fWarrangeCli/Services/RESTServer.swift handleRestore`)**:
        - `results.filter { !$0.success }`로 실패 항목 추출
        - 각 항목에 `targetWindow`의 WindowInfo(app/title/layer/id/pos/size) 매핑
        - `classifyRestoreFailure` 정적 헬퍼: `NSWorkspace.shared.runningApplications` 기반으로 4 사유 분류
            - app 미실행 + `matchType==.noMatch` + `score==0` → `appNotRunning`
            - `matchType==.noMatch` 또는 `score==0` → `windowNotFound`
            - `score < minimumScore` → `belowMinimumScore`
            - 그 외 (점수 충분하지만 success=false) → `axOperationFailed`
        - 응답 `data.failures` 배열 직렬화하여 반환
* 검증:
    - `curl -X POST /api/v2/layouts/2026-05-16-6/restore | jq '.data.failures'`로 실패 윈도우 정보 확인 (`{app:"Finder", title:"animationTest", reason:"windowNotFound", ...}`)
    - `failures.count == failed` 카운트 일치 (27 total, 26 succeeded, 1 failed)
* 알려진 운영 메모:
    - Debug 빌드 직접 실행 시 `BrewServiceSync.onAppStart`가 `brew services start`로 위임 후 self-terminate → brew 구버전이 다시 띄워짐
    - 해결: `brew services stop fwarrange-cli` + `defaults write kr.finfra.fWarrangeCli fwc.autoStartBrewService -bool false` + DerivedData 직접 실행

## Issue73: [Bug] ChangeTracker 발행 누락 + LayoutManager SSOT 누수 — paidApp 적응형 폴링 변경 알림 결손 (등록: 2026-05-16) (✅ 완료, 0580ad8) ✅
* 목적: cliApp `ChangeTracker.record(...)` 발행 지점 누락으로 paidApp `/changes` 폴링이 일부 변경을 인지하지 못함. 또한 `LayoutManager` CRUD 메서드 자체에 `record(...)` 호출이 없어 외부 호출 경로(RESTServer 핸들러·`AppState.handleHotKeyAction`)에서만 발행 → 향후 직접 호출 추가 시 누락 위험 상시. 상위 `_doc_arch/paid_cli_protocol.md` §6 SSOT 정합화.
* 선행 관계: 상위 paidApp 레포 Issue248의 **선수 이슈** (cliApp 측 발행이 보장되어야 paidApp 측 폴링·suspend 보수화의 효과 검증 가능)
* 상세:
    - 누락된 발행 지점 (RESTServer.swift):
        - `handleRemoveWindows` (1483) — `layout.updated` 누락 → 창 일부 제거 시 paidApp 미반영
        - `handleSetDefaultLayout` (1567) — `settings.changed`(target=`defaultLayout`) 누락
        - `handleSetUIState` (1590) — 정책 결정 후 추가 검토 (선택)
    - LayoutManager SSOT 누수 — 메서드 내부에 `record` 없음:
        - `saveLayout` (79)
        - `deleteLayout` (86)
        - `deleteLayouts` (153)
        - `deleteAllLayouts` (100)
        - `renameLayout` (169)
        - `removeWindows` (107)
        - `updateWindowPositions` (117)
    - DisplaySwitchService / ScreenMoveService 일괄 좌표 갱신 시 `layout.updated` 발행 여부 미확인 (확인 후 누락 시 추가)
* 구현 명세:
    - Phase A — 누락 발행 추가 (RESTServer):
        - `handleRemoveWindows` 성공 분기 끝에 `ChangeTracker.shared.record(type: "layout.updated", target: name)`
        - `handleSetDefaultLayout` 성공 분기 끝에 `ChangeTracker.shared.record(type: "settings.changed", target: "defaultLayout")`
    - Phase B — SSOT 이관 (LayoutManager 내부 발행):
        - 각 CRUD 메서드 마지막 줄에 `ChangeTracker.shared.record(...)` 추가
        - `saveLayout` → `layout.created`/`layout.updated`(덮어쓰기 시) 판단 후 발행
        - `deleteLayouts` → 루프 내 각 name마다 `layout.deleted`
        - `renameLayout` → `layout.deleted`(oldName) + `layout.created`(newName) (SSOT §6.4 매핑 준수)
        - `removeWindows` / `updateWindowPositions` → `layout.updated`
        - RESTServer/AppState 측 중복 호출 제거 (이중 발행 방지)
    - Phase C — 폭주 방지:
        - `ChangeTracker`에 동일 (type, target) 100ms throttle 옵션 도입 (updateWindowPositions 다건 호출 시)
        - 또는 호출 측에서 단일 트랜잭션 후 1회 발행으로 묶기
    - Phase D — 디스플레이/스크린 이동:
        - `DisplaySwitchService` / `ScreenMoveService`가 LayoutManager 경유로 좌표 갱신하도록 정리되어 있는지 확인
        - 직접 storageService 호출 시 `layout.updated` 발행 추가
    - 검증:
        - `curl -X POST /api/v2/layouts/X/windows/remove` 후 `GET /api/v2/changes?since=N` 응답에 `layout.updated` 포함
        - `POST /api/v2/settings/defaultLayout` 후 `settings.changed`(target=defaultLayout) 포함
        - cliApp 메뉴바 / Cmd+F7 / REST capture 각각에서 `layout.created` 1회씩만 발행 (이중 발행 없음)
        - paidApp Issue248 검증 시나리오와 함께 end-to-end 자동 갱신 확인
* 관련:
    - 상위: paidApp 레포 Issue248 (`~/_git/__all/fWarrange/Issue.md`)
    - SSOT: `~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` §6 (변경 알림 프로토콜)
    - 기반: Issue27(시퀀스 API), Issue220(SSE 제거 → /changes 일원화)


## Issue72: [Feat] 창 인식률 개선 — 7-Phase 통합 작업 (등록: 2026-05-15) (✅ 완료, 2026-05-16) ✅
* 목적: "정밀 복구 실패의 원인이 ID 방식인지 윈도우명인지 이중 매칭 문제인지" 토의(이슈후보 출신)를 시발점으로, 측정 인프라부터 사용자 개입 UI까지 7개 Phase로 매칭 알고리즘을 체계적으로 개선
* plan: `cli/_doc_work/plan/window_recognize_plan.md`
* task: `cli/_doc_work/tasks/window_recognize_task.md`
* design: `cli/_doc_arch/window_recognize.md`
* report: `cli/_doc_work/report/window_recognize_issue72_report.md`
* 구현 명세:
    - 7개 서브 이슈 Issue72_1~Issue72_7 모두 처리 (cliApp 측 코드 완료)
    - 18개 커밋 (Issue72 직접 16 + Save Point 1 + 리팩토링 1)
    - 신규 Swift 파일 4종 (RestoreStats, RestoreStatsCollector, TitleNormalizer, MatchMode)
    - 신규 REST 엔드포인트 5개 (`/restore-stats` GET·DELETE, `/normalize-rules` GET·PUT·DELETE)
    - 확장 파라미터: `POST /layouts/{name}/restore`에 `mode`, `interactive`/`dryRun`
    - WindowInfo 옵셔널 필드 6개 추가 (모두 구 yml 하위호환)
    - 신규 비공개 API: CGSMainConnectionID, CGSGetActiveSpace, CGSCopySpacesForWindows (cliApp non-sandbox)
    - apiTest/v2 신규 6개 (33~38)
    - openapi_v2.yaml + RestAPI_v2.md §4.8~§4.11 동기화
* 후속 작업:
    - Task 1.6 베이스라인 수집 (2026-05-22 후 `window_recognize_baseline.md`)
    - paidApp 다이얼로그·`/resolve` (별도 레포)
    - PWA 매칭 활용·이슈후보(tab PATCH false 버그)는 베이스라인 후 결정

## Issue72_1: [Feat] Phase 1 — 측정 인프라 (RestoreStats + REST) (등록: 2026-05-15) (✅ 완료, 02d2bd0) ✅
* 목적: 모든 후속 Phase의 효과 검증 토대 구축. 복구 매칭 결과를 누적 통계로 노출
* 구현 명세:
    - RestoreStats 모델 + JSONRestoreStatsCollector actor
    - WindowRestoreService 매칭 결과 push (recordBatch)
    - ~/Library/Application Support/fWarrangeCli/restore-stats.json 즉시 영속
    - GET/DELETE /api/v2/restore-stats
    - openapi_v2.yaml + RestAPI_v2.md §4.8
    - apiTest/v2/33, 34 신규
* 검증: 54건 누적·재시작 보존·DELETE 사이클 정상
* 후속: 1주일 베이스라인 수집 → window_recognize_baseline.md (2026-05-22)

## Issue72_2: [Feat] Phase 2 — 데이터 수집 확장 (windowOrder + displayUUID) (등록: 2026-05-15) (✅ 완료, 1899014) ✅
* 목적: 매칭 정확도 향상을 위해 캡처 시점에 추가 시그널 수집
* 구현 명세:
    - WindowInfo.windowOrder (PID별 onscreen 인덱스), displayUUID 옵셔널 필드
    - CGDisplayCreateUUIDFromDisplayID + Cocoa↔Quartz 좌표 변환 + squaredDistance fallback
    - YAML 하위호환
* 검증: 4-monitor 환경 UUID 4종 일관, 다중 창 windowOrder 순차 (Code 0~8, KakaoTalk 0~8)
* 한계: Chrome PID 분기로 windowOrder=[0,0] — Phase 6에서 다중 식별자 토대

## Issue72_3: [Feat] Phase 3 — 타이틀 정규화 룰셋 (등록: 2026-05-15) (✅ 완료, a776be1) ✅
* 목적: 동적 타이틀(브라우저·에디터·터미널·채팅)로 인한 exactTitle(90점) 매칭 실패 회복
* 구현 명세:
    - TitleNormalizer 서비스 (DispatchQueue concurrent + barrier write)
    - 빌트인 10개 룰 (Safari/Chrome/Edge/Firefox/Code/Cursor/Slack/iTerm2/Terminal/Xcode)
    - 사용자 편집본: ~/Library/Application Support/fWarrangeCli/title_normalize.yml
    - GET/PUT/DELETE /api/v2/normalize-rules
    - WindowInfo.windowRaw (정규화 전 원본 보존)
    - openapi_v2.yaml + RestAPI_v2.md §4.9
* 검증: VSCode 13창 정규화 실측 (`⚓ fWarrange — Issue.md` → `⚓ fWarrange`)

## Issue72_4: [Feat] Phase 4 — 점수 함수 개선 (distance 가산 + areaMatch 옵션) (등록: 2026-05-15) (✅ 완료, c4162f6) ✅
* 목적: 카테고리 점수 + distance 가산 + areaMatch 비활성화 옵션으로 노이즈 매칭 감소
* 구현 명세:
    - computeMatchScore에 distance 0~9점 가산 (score>0 && score<100 가드, 카테고리 경계 보존)
    - AppSettings.matchAreaMatchEnabled 옵션 + SettingsService yml 직렬화
    - /settings/restore 탭에 노출
* 검증: 빌드 통과, /settings/restore GET 노출, 56창 회귀 없음
* 후속 이슈후보: /settings/{tab} PATCH Bool false 영속화 버그 (전체 /settings PATCH는 정상)

## Issue72_5: [Feat] Phase 5 — 매칭 모드 + Moom 폴백 (strict/normal/loose) (등록: 2026-05-15) (✅ 완료, 48df335) ✅
* 목적: 사용자 "정확히"/"비슷하게" 의도 표현. loose 모드에서 Moom 스타일 최후 폴백
* 구현 명세:
    - MatchMode enum + RuntimeMatchPolicy struct (모드별 정책 빌더 팩토리)
    - strict(≥70, 기하 차단) / normal(설정값) / loose(≥30 + 1:N + Moom)
    - WindowInfo.matchMode 창 단위 override
    - Moom 폴백: 앱별 창 수 == target 수 → windowOrder 정렬 배분
    - POST /api/v2/layouts/{name}/restore에 mode 파라미터
    - openapi + RestAPI_v2.md §4.10
* 검증: 3 모드 e2e 각 57/57, MatchType 분포 ID 388 / Title(Exact) 1 / Width 1 / None 4

## Issue72_6: [Feat] Phase 6 — Spaces(spaceId) + PWA(originURL) (등록: 2026-05-15) (✅ 완료, dc0f36f) ✅
* 목적: OSS 미개척 시나리오 — Spaces 분산 창·Chrome PWA 구분 매칭 토대
* 구현 명세:
    - 6-1: 비공개 CGSCopySpacesForWindows + WindowInfo.spaceId + 매칭 +3점 가산
    - 6-2: Chromium 5종 화이트리스트 + ps -p {pid} -o command= → --app=URL 파싱 + WindowInfo.originURL
    - AXPrivateAPI.swift에 CGSMainConnectionID/CGSGetActiveSpace/CGSCopySpacesForWindows 바인딩
    - Issue.md 결정사항에 cliApp 비공개 API 도입 합의 기록
* 검증: 56창 spaceId=1 일관 추출, PWA 코드 빌드 통과
* 한계: Space 분산·PWA 실측 환경 후속. appMatches 다중 식별자 매칭 활용은 별도 후속

## Issue72_7: [Feat] Phase 7-1 — Interactive REST dry-run (등록: 2026-05-15) (✅ cliApp PoC 완료, 1d4246d) ✅
* 목적: 매칭 시뮬레이션(dry-run) — paidApp 후보 선택 다이얼로그 사전 조회
* 구현 명세:
    - WindowRestoreService에 dryRun: Bool 인자 추가 (3 호출부 + Moom 가드)
    - POST /api/v2/layouts/{name}/restore body의 interactive 또는 dryRun (동의어, OR)
    - 응답: success=false, matchedTitle="(dry-run) {원본}", score/matchType 정상
    - openapi + RestAPI_v2.md §4.11
    - apiTest/v2/38
* 검증: dry-run 56창(succeeded=0) vs 실제 56/56
* 후속 (별도 레포): paidApp 다이얼로그(7-2), /resolve 엔드포인트, MatchCandidate/InteractiveSession, 학습(7-3)

## Issue71: [Fix] VSCode 등 CGWindowOwnerName ↔ localizedName 불일치 앱 복구 실패 (등록: 2026-05-08) (✅ 완료, 7b41337) ✅
* 목적: VSCode·Code Helper 등 `kCGWindowOwnerName` 과 `NSRunningApplication.localizedName` 이 다른 앱이 복구되지 않는 문제를 근본 해결.
* 상세:
    - 현상: REST `/api/v2/layouts/{name}/restore` 호출 시 `[복구] 'Visual Studio Code' - 성공: 0, 대기: 10` → `[조기 종료] 남은 창의 앱이 모두 미실행 상태: Visual Studio Code` 로 1회 시도 만에 종료. VSCode가 명백히 실행 중인데도 매칭 실패.
    - 근본 원인 (실측):
        - `kCGWindowOwnerName` = `"Visual Studio Code"` (yml `app` 필드에 저장)
        - `NSRunningApplication.localizedName` = `"Code"` (복구 매칭 기준)
        - 기존 매칭 로직 `name == appName || name.hasPrefix(appName) || appName.hasPrefix(name)` 가 `"Code"` ↔ `"Visual Studio Code"` 양방향 prefix 모두 false → 매칭 0건
    - 영향 범위: bundleURL 표시명과 localizedName 이 다른 모든 앱 (이름 기반 매칭의 구조적 한계)
* 구현 명세 (해결 방식 — 단순 매칭 강화가 아닌 식별자 자체를 안정화):
    - WindowInfo 모델에 `bundleId: String?` 옵셔널 필드 추가 (CFBundleIdentifier — OS·언어·표시명 변경 무관)
    - WindowCaptureService: `kCGWindowOwnerPID` → NSRunningApplication.bundleIdentifier 매핑 후 저장
    - LayoutStorageService: YAML 직렬화·파싱에 `bundleId:` 라인 추가 (구 yml 호환 — 없으면 nil)
    - WindowRestoreService 매칭 헬퍼 `appMatches(_:targetApp:targetBundleId:)`:
        - 1순위: bundleIdentifier 정확 일치
        - 2순위: 다중 이름 후보(localizedName, bundleURL `.app` 제거 형식, executableURL) 정확/양방향 prefix
        - 3개소(병렬 경로·순차 경로·조기 종료 체크) 헬퍼 호출 통일
    - RESTServer.windowInfoToDict: bundleId 응답 포함 (옵셔널)
    - OpenAPI v2 WindowInfo 스키마 동기화
* 검증:
    - 신 yml(bundleId 포함) 47/47 복구 성공 (VSCode 10/10 포함)
    - 구 yml(2026-05-08-3, bundleId 없음) VSCode 10/10 — 이름 기반 fallback 정상 동작
    - REST `/capture` 응답에 `bundleId='com.microsoft.VSCode'`, `'com.apple.dt.Xcode'` 노출 확인
    - Release 빌드·brew local 재배포·헬스체크 OK

## Issue70: [Feat] cliApp 메뉴바 종료 항목 단축키 표시 정비 + 다국어 지원 (등록: 2026-05-04) (✅ 완료, c47bbcd) ✅
* 목적: cliApp 메뉴바의 종료 항목 단축키 표시를 종료 정책(`paid_cli_protocol.md` §3.3)과 일치시키고, 메뉴 항목 다국어 지원을 추가. paidApp Cmd+Q는 paidApp 단독 종료에만 표시되어야 하며, cliApp Quit All에는 단축키 미부여(오발화 방지).
* 상세:
    - 배경:
        - paidApp Issue239(Cmd+Q로 cliApp 동반 종료) 취소 — 정책: Cmd+Q는 paidApp 단독 종료, 메뉴바 Quit All은 cliApp 메뉴 단일 진입점
        - 현재 `cli/_doc_arch/menuBar_enhance.md`의 메뉴 구조에서 `Quit ⌘Q` 표기가 단일 항목에 부여되어 있어 정책과 불일치
        - 메뉴 항목 텍스트가 영어 하드코딩으로 추정 — 다국어 미지원
    - 관련 파일:
        - `cli/fWarrangeCli/Managers/MenuBarManager.swift` (NSMenu 구성)
        - `cli/_doc_arch/menuBar_enhance.md` (SSOT 메뉴 구조 — 본 이슈에서 수정)
        - `cli/fWarrangeCli/*.lproj/Localizable.strings` 또는 `.xcstrings` (다국어 리소스)
* 구현 명세:
    - 1단계 — `cli/_doc_arch/menuBar_enhance.md` 수정:
        - "Quit ⌘Q" 단일 항목을 정책 기반 2~1항목 구조로 분리:
            - paidApp 활성(`paidAppStatus = started`): `Quit fWarrange ⌘Q` + `Quit All` (단축키 없음)
            - paidApp 비활성(`stopped`/`notInstall`): `Quit fWarrangeCli` (cliApp 단독, 단축키 없음)
        - 단축키 표시 규칙: ⌘Q는 **paidApp 활성 시 paidApp 단독 종료 항목에만** 표시
        - 메뉴 텍스트는 다국어 키 참조 형식: `menu.quit.fwarrange`, `menu.quit.all`, `menu.quit.fwarrangecli`
    - 2단계 — `MenuBarManager.swift` 구현:
        - paidApp 상태 분기로 종료 항목 구성
        - paidApp 활성: `Quit fWarrange`(⌘Q, paidApp 단독) + `Quit All`(단축키 없음, 통합 종료)
        - paidApp 비활성: `Quit fWarrangeCli` 단일 항목, 단축키 없음
        - paidApp 단독 종료 액션: `PaidAppLauncher.terminate()` 호출 (cliApp은 잔존)
        - Quit All 액션: 기존 `quitApp()` 시퀀스 (Issue68/Issue236 — 3단 폴백)
    - 3단계 — 다국어 리소스 추가:
        - 신규 키: `menu.quit.fwarrange`, `menu.quit.all`, `menu.quit.fwarrangecli`
        - 지원 언어 매트릭스는 `localization/` 기존 정책 따름 (en/ko 최소 + 기타 기존 지원 언어 동기화)
        - About 항목 등 기존 다국어 미적용 메뉴 항목도 동시 정비 (선택적, 발견 시)
    - 4단계 — 검증:
        - paidApp 활성 시 메뉴 열기: `Quit fWarrange ⌘Q` + `Quit fWarrangeCli`(단축키 없음) 노출 확인
        - paidApp 비활성 시 메뉴 열기: `Quit fWarrangeCli` 단일 항목, 단축키 없음 확인
        - paidApp 단독 종료 후 cliApp 잔존(`pgrep fWarrangeCli`) 확인
        - Quit All 시 paidApp + cliApp 모두 종료 확인
        - 시스템 언어 변경 시 메뉴 텍스트 즉시 반영 확인 (en/ko)

## Issue69: [Feat] 메뉴바 paidApp 연동 일관성 — About 분기 + Open Main Window URL Scheme (등록: 2026-05-03) (✅ 완료, 1a375a1) ✅
* 목적: paidApp 동작 상태에 따라 메뉴 표기·동작이 자연스러워지도록 정비함. 두 증상은 같은 패턴(paidApp 활성 시 paidApp을 우선시해야 함)이라 묶어 처리.
    1. About 메뉴: paidApp 동작 중일 때 "About fWarrangeCli"가 아니라 "About fWarrange"가 표시되어야 하고, About 창 내용도 paidApp 정보로 바뀌어야 함.
    2. "Open Main Window" 메뉴: 클릭 시 paidApp이 활성화는 되지만 메인 창이 열리지 않음. 핫키 경로는 URL Scheme(`fwarrange://command?action=main`)을 쓰는데 메뉴 경로는 `NSWorkspace.shared.open(url)`만 호출해서 LSUIElement 모드 paidApp의 메인 창을 띄우지 못함.
* 상세:
    - About 메뉴 타이틀은 paidApp 미동작 시 "About fWarrangeCli", 동작 중 시 "About fWarrange" (en/ko/ja 동시 적용)
    - About 창: paidApp 모드 시 paidApp 번들 아이콘·이름·버전 표시, App Store 링크 추가
    - Open Main Window 메뉴 액션을 `state.openPaidApp(action: "main")`(URL Scheme)으로 변경, `openSettings()`와 일관 패턴
* 구현 명세:
    - `cli/fWarrangeCli/Utils/LocalizedStringManager.swift`: `menu.about.cli`, `menu.about.paid` 키 추가 (en/ko/ja). 기존 `menu.about`는 호환용으로 유지 또는 제거.
    - `cli/fWarrangeCli/Managers/MenuBarManager.swift`:
        + `buildMenuItems`에서 `appState?.paidAppMonitor.state == .paidAppActive` 여부에 따라 About 메뉴 타이틀 분기
        + `openMainWindow()`에서 `_ = state.launchPaidApp()` → `state.openPaidApp(action: "main")` 변경
    - `cli/fWarrangeCli/Managers/AboutWindowManager.swift`:
        + `showAbout(isPaidActive: Bool)` 시그니처로 변경 (호출 측에서 paidApp 상태 전달)
        + `AboutView`를 `isPaidActive` 분기로 두 가지 컨텐츠 렌더링
        + paidApp 모드: 타이틀 "About fWarrange", paidApp 번들 아이콘/이름/버전 표시 (NSRunningApplication.bundleURL 또는 PaidAppLauncher.detect()), App Store 링크 추가 (`macappstore://apps.apple.com/app/fwarrange/id6744105753`)
    - 검증: paidApp 미실행 / 실행 두 상태 모두 메뉴 타이틀·About 창 내용·Open Main Window 동작 확인. Release 빌드 통과.

## Issue68: [Refactor] 메뉴바 Quit → paidApp 통합 종료 (Quit All) (등록: 2026-05-03) (✅ 완료, 251036a) ✅
* 목적: cliApp 메뉴바 Quit 클릭 시 cliApp만 종료되고 paidApp(`fWarrange`)이 잔존하는 현상(2026-05-03 재현 확인). paidApp 측 Cmd+Q는 정상 동작하므로 본 이슈는 **cliApp 측 작업**임. paidApp 레포 Issue232에서 paidApp `MenuBarExtra` 제거 후 cliApp 메뉴바가 유일한 paidApp 종료 트리거가 되어야 하나 미연결 상태.
* 상세:
    - 현상: cliApp 메뉴바 → Quit → cliApp 프로세스만 종료, paidApp(`/Applications/_nowage_app/fWarrange.app`) 프로세스는 좀비처럼 잔존
    - 관련 SSOT: 상위 paidApp 레포 `_doc_arch/paid_cli_protocol.md` §3.3 "Quit All 시퀀스" — cliApp 트리거 흐름 미반영
    - 관련: paidApp 레포 Issue232 (paidApp 메뉴바 제거, 2026-05-03 완료)
* 구현 명세:
    - `MenuBarManager.swift` 또는 `MenuBarView.swift` Quit 액션 핸들러에서 paidApp 종료 신호 발송
    - 옵션 A: paidApp URL Scheme `fwarrange://command?action=quit` open
    - 옵션 B: paidApp pid 검색 후 `kill -TERM`
    - 옵션 C: REST `/api/v2/paidapp/quit` 신규 엔드포인트 추가 후 paidApp이 self-terminate
    - 옵션 결정 후 paidApp 레포 SSOT `_doc_arch/paid_cli_protocol.md` §3.3 갱신 필요 (양 레포 동기 PR)
    - 검증: cliApp 메뉴바 Quit → paidApp + cliApp 모두 종료, ps에서 잔존 0개 확인


> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# ⏸️ 보류
## Issue76: paidApp 실행 감지 시 메뉴바 아이콘 즉시 전환 (등록: 2026-05-17, 보류: 2026-05-17) ⏸️
* 보류 사유: 실측 결과 기존 메커니즘(PaidAppMonitor launch 핸들러 → AppState `startObservingMenuBarIcon` → MenuBarManager `observeIcon`)이 정상 동작 확인. 지연/누락 없음. 진행 불필요.
* 재개 조건: 추후 launch 감지 지연 또는 아이콘 미전환 사례 재현 시 본 이슈 재활성화
* depends: Issue75 (terminate 측 잔존 보호와 동일 모니터 경로)
* 원 목적: paidApp launch 시 메뉴바 아이콘 즉시 전환 보장
* 참조:
    - `cli/fWarrangeCli/Managers/PaidAppMonitor.swift:39-51`
    - `cli/fWarrangeCli/AppState.swift:504-526`
    - `cli/fWarrangeCli/Managers/MenuBarManager.swift:29-67`

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
