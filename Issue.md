---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---

# Issue Management

* Issue HWM: 28
* Save Point: 2026-04-16 (dff889a) Feat(AppState): Issue28 fWarrange 종료 시 fWarrangeCli 메뉴바 자동 복원

# 🤔 결정사항

# 🌱 이슈후보
1. all clear test할 것. _config.yml기본 값 확인
2. 클립보드 히스토리 기능 중에서 고급 기능은 Paid 앱이 활성화 되어 있어야 실행 가능하게끔 해 줘 활성화 되어 있지 않다면 활성화 창[기존 코드 찾아서] 열게 해야함. 
   1. Paid 앱의 기능이 모듈로 구성되어 있는지 확인
3. Default 레이아웃 복구 않됨. 트리거 로그만 있음.[2026-04-13 14:32:37.131] 🐛 DEBUG: HotKeyService: 단축키 트리거 (id=4)
# 🚧 진행중

# 📕 중요

# 📙 일반
# 📗 선택

# ✅ 완료
## Issue28: fWarrange 종료 시 fWarrangeCli 메뉴바 자동 복원 (등록: 2026-04-16) (✅ 완료, dff889a) ✅
* 목적: fWarrange 앱 종료 시 fWarrangeCli 메뉴바가 숨겨진 채 방치되는 문제 해결 — 이중 방어 방식(NSWorkspace 감시 + REST 호출)으로 자동 복원
* 상세:
    - 방안1: fWarrangeCli의 AppState에 `NSWorkspace.didTerminateApplicationNotification` 감시 추가 — `kr.finfra.fWarrange` 종료 감지 시 `hideMenuBar=false` 복원 (crash 포함 모든 종료 커버)
    - 방안2: fWarrange의 `AppDelegate.applicationWillTerminate`에서 `PUT /api/v1/ui/state {hideMenuBar:false}` 동기 전송 (정상 종료 시 즉시 복원)
* 구현 명세:
    - [cli/fWarrangeCli/AppState.swift](cli/fWarrangeCli/AppState.swift): `observePaidAppTermination()` 메서드 추가 — `NSWorkspace.shared.notificationCenter`에서 `didTerminateApplicationNotification` 구독, Bundle ID `kr.finfra.fWarrange` 필터링, `hideMenuBar = false` 복원
    - [fWarrange/fWarrangeApp.swift](../fWarrange/fWarrange/fWarrangeApp.swift): `applicationWillTerminate()` 메서드 추가 — `URLSession.dataTask` + `DispatchSemaphore`로 동기 REST 호출 (타임아웃 2초)
    - 검증: fWarrangeCli Release 빌드 성공, fWarrange Debug 빌드 성공, REST API 정상 동작 확인



## Issue27: 변경 시퀀스 API 추가 — 적응형 Polling 서버 측 (등록: 2026-04-16, 해결: 2026-04-16, commit: 이전 구현 완료) ✅
* 목적: fWarrangeCli에서 데이터 변경 시 시퀀스 번호를 기록하여 fWarrange GUI가 변경 사항을 폴링으로 감지할 수 있게 함
* 상세:
    - `ChangeTracker` 클래스: 시퀀스 카운터 + 링버퍼(100건), `record()`/`changes(since:)` 구현
    - `GET /api/v2/changes?since={seq}` 엔드포인트 (RESTServer.swift routeV2)
    - 레이아웃 변경 핸들러 6곳 + 설정 PATCH 8곳 + shortcuts 1곳에서 `ChangeTracker.shared.record()` 호출
    - 이벤트 유형: `layout.created`, `layout.deleted`, `settings.changed`, `shortcuts.changed`

## Issue26: nPTiR 환경 정비 — _doc_work 구조·gitignore·settings.json 정비 (등록: 2026-04-14, 해결: 2026-04-14, commit: ad27664) ✅

* 목적: nPTiR 체계 원활 운용을 위해 잘못된 _doc_work 위치 정리, .gitignore 보완, settings.json 하드코딩 경로 제거
* plan: `cli/_doc_work/plan/start-nPTiR_plan.md`
* task: `cli/_doc_work/task/start-nPTiR_task.md`
* 상세:
    - `_doc_work/` 루트 파일 3개 `cli/_doc_work/`로 이동 및 빈 폴더 삭제
    - `cli/_doc_work/tasks/` → `task/` 단수형 리네임
    - `cli/_doc_work/_rlease/`, `z_done/` 빈 폴더 처리
    - `.gitignore`에 `_doc_work/` 루트 항목 추가
    - `Issue.md` gitignore에서 제거 (tracked 상태 유지)
    - `settings.json` 하드코딩 DerivedData·fSnippet 경로 제거

## Issue25: testDo 스크립트 개선 — run.sh 사전 실행, 로그 확인, 결과 저장 (등록: 2026-04-14, 해결: 2026-04-14, commit: 24aa888) ✅

* 목적: apiTestDo.sh / cmdTestDo.sh 에 run.sh 사전 실행·로그 확인·결과 저장 기능 추가
* 상세:
    - --run / --log / --report 옵션 추가 (기존 인자 호환 유지)
    - _doc_work/plan/, _doc_work/tasks/, _doc_work/report/ 구조 도입

## Issue24: v1 제거 대비 v2 슈퍼셋 업데이트 (등록: 2026-04-13, 해결: 2026-04-13, commit: 5db488e) ✅

* 목적: v2 API/CLI/테스트가 v1의 모든 기능을 커버하도록 확장하여 향후 v1 제거에 대비
* 상세:
    - openapi_v2.yaml에 v1 전체 엔드포인트(layouts, capture, restore, windows, cli, ui, system) 추가
    - CLIHandler.swift baseURL을 `/api/v1`에서 `/api/v2`로 변경 (apiVersion 파라미터 제거)
    - apiTest/v2/에 v1 커버리지 스크립트 14개(19~32, E03~E04) 추가
    - cmdTest/v2/에 v1 CLI 커맨드 커버리지 스크립트 17개(18~32, E03~E04) 추가
    - RESTServer.swift의 /api/v2 → /api/v1 경로 치환 폴백으로 서버 사이드는 이미 지원됨
    - Release 빌드 검증 완료

## Issue23: v2 API 구현 최종 검증 및 Issue22 완료 처리 (등록: 2026-04-13, 해결: 2026-04-13, commit: 21a5229) ✅

* 목적: Issue22에서 구현된 v2 API 전체를 검증 레포트 기준으로 최종 확인하고 Issue22를 완료 처리한다
* 상세:
    - 검증 기준 레포트: 2026-04-13 세션에서 생성된 v2 apiTest 검증 결과 (19 PASS, 1 SKIP)
    - 확인1: `apiTest v2` 전체(00~18 + E01~E02) 재실행 및 PASS 확인
    - 확인2: `cmdTest v2` 전체(00~17 + E01~E02) 실행 및 PASS 확인
    - 확인3: `CLIHandler.swift` v2 확장 구현 확인 (`baseURLV2`, `handleV2`, `handleV2Settings`, `handleV2ExcludedApps`, `handleV2Shortcuts`)
    - 확인4: `apiTest_plan_v2.md` 번호 재배정(00=health, 01~18) 반영 확인
    - 완료: Issue22를 `✅ 완료` 섹션으로 이동하고 커밋 해시 기록
* 구현 명세:
    - `CLIHandler.swift` `handleV2`에서 중복 `args.removeFirst()` 버그 수정 — `handle(command:args:)`에서 "v2"가 이미 소비되므로 재차 제거 불필요
    - `18.v2-factory-reset.sh`, `17.v2-factory-reset.sh` SKIP 메시지 경로 수정 (37→정확한 번호)
    - cmdTest v2 전체 PASS 검증 완료

## Issue22: REST API v2 구현 (Settings 화면 전체 엔드포인트) (등록: 2026-04-13, 해결: 2026-04-13, commit: dde4cf6, ab2c302, 21a5229) ✅

* 목적: 설정 화면(General/Restore/API/Advanced) 기능을 REST API v2로 구현하여 fWarrange GUI에서 원격 제어 가능하게 함
* 상세:
    - `api/openapi.yaml` → `api/openapi_v1.yaml` 리네임, 신규 `api/openapi_v2.yaml` 작성
    - `AppSettings` 모델 확장: `restServerEnabled`, `allowExternalAccess`, `allowedCIDR`, `dataDirectoryPath`, `autoSaveOnSleep`, `maxAutoSaves`, `restoreButtonStyle`, `confirmBeforeDelete`, `showInCmdTab`, `clickSwitchToMain`, `theme`
    - `YAMLSettingsService` 파서/직렬화에 신규 필드 반영
    - `RESTServer.swift`: `apiV2BasePath` 상수, `routeV2()` 신규 — v2 설정 엔드포인트 처리, 그 외는 v1으로 폴백
    - v2 엔드포인트:
        - `GET/PATCH /api/v2/settings` (전체)
        - `GET/PATCH /api/v2/settings/{general,restore,advanced}`
        - `GET/PATCH /api/v2/settings/api` (포트/CIDR 변경 시 서버 자동 재시작)
        - `GET/PUT/POST/DELETE /api/v2/settings/restore/excluded-apps` + `/reset`
        - `POST /api/v2/settings/factory-reset` (`X-Confirm: true`)
        - `GET/PUT /api/v2/settings/shortcuts`
    - `AppState.swift`: `fullSettingsDict`/`applySettingsPatch` 헬퍼 + `applyApiSettings`가 포트/CIDR 변경 시 `RESTServer` 자동 재시작
    - 문서/규칙 참조 경로 `openapi.yaml` → `openapi_v1.yaml` 일괄 갱신 (`api/README*`, `manual/*`, `cli/README*`, `.claude/rules/api-rules.md`, `.wiki-compiler.json`)
    - Debug 빌드 검증 완료 (BUILD SUCCEEDED)
    - apiTest v2 스크립트 전체 커버리지 추가 (00~18 + E01~E02) — commit: dde4cf6
    - CLIHandler.swift v2 확장: `baseURLV2`, `handleV2`, `handleV2Settings`, `handleV2ExcludedApps`, `handleV2Shortcuts`
    - cmdTest v2 전체(00~17 + E01~E02) PASS 검증 완료 — commit: 21a5229

## Issue21: 단축키 설정 REST 동기화 엔드포인트 추가 (등록: 2026-04-12, 해결: 2026-04-13, commit: 76bb041) ✅

* 목적: fWarrange GUI(Sandbox) 설정창에서 단축키를 변경해도 `_config.yml`에 반영되지 않고 CLI 데몬의 `HotKeyService`도 재등록되지 않던 문제 해결
* 상세:
    - GUI Shortcuts 탭은 로컬 저장만 수행하고 `fWarrangeCli`로 전파되지 않음
    - CLI 데몬은 기동 시 한 번만 `_config.yml` 읽어 `CarbonHotKeyService.register(...)` 호출
    - OpenAPI 명세에 shortcut 업데이트 엔드포인트 부재
* 구현 명세:
    - [api/openapi.yaml](api/openapi.yaml): `PUT /settings/shortcuts` 경로 및 `ShortcutsUpdateRequest` / `ShortcutsUpdateResponse` 스키마 추가
    - [cli/fWarrangeCli/Services/RESTServer.swift](cli/fWarrangeCli/Services/RESTServer.swift):
        - `RESTServerHandlers.updateShortcuts: ([String: Any]) -> [String: String]` 필드 추가
        - `Notification.Name.fWarrangeCliShortcutsUpdated` 정의
        - `PUT /api/v1/settings/shortcuts` 라우팅 및 `handleSetShortcuts` 핸들러 추가
    - [cli/fWarrangeCli/AppState.swift](cli/fWarrangeCli/AppState.swift):
        - `updateShortcuts` 클로저 — `settingsService.load()` → 키별 병합(문자열=설정, NSNull=해제, 누락=유지) → `save()` → `.fWarrangeCliShortcutsUpdated` 알림 발송
        - `initialize()` 에서 해당 알림 관찰 → `settings` 재로딩 + `hotKeyService.register(...)` 재호출
    - 바디 규칙: `saveShortcut`, `restoreDefaultShortcut`, `restoreLastShortcut`, `showMainWindowShortcut`, `showSettingsShortcut` 키 지원

## Issue20: CLI `capture` 인자 생략 시 날짜별 시퀀스 이름으로 저장 (등록: 2026-04-12, 해결: 2026-04-12, commit: 4c6fcb1) ✅

* 목적: `$CLI capture`(인자 없음) 실행 시 고정된 이름("default" 또는 이전 `-hotkey`)으로 저장되어 덮어쓰던 문제를 해결하고, `cmd+F7` 단축키 저장과 동일한 명명 규칙(`YYYY-MM-DD-{n}`)을 사용하도록 통일
* 상세:
    - `LayoutManager.nextDailySequenceName()` 헬퍼 추가 (오늘 날짜 prefix의 최대 번호+1 산출)
    - `AppState.handleHotKeyAction(.save)`가 헬퍼 재사용 → 중복 로직 제거
    - `RESTServer.handleCapture`에서 `name` 누락/빈 문자열 시 `handlers.nextDailySequenceName()` 호출
    - `CLIHandler` `capture` 커맨드: 인자 없으면 `name` 필드 자체를 전송하지 않음
* 구현 명세:
    - [cli/fWarrangeCli/Managers/LayoutManager.swift](cli/fWarrangeCli/Managers/LayoutManager.swift)
    - [cli/fWarrangeCli/Services/RESTServer.swift](cli/fWarrangeCli/Services/RESTServer.swift)
    - [cli/fWarrangeCli/CLIHandler.swift](cli/fWarrangeCli/CLIHandler.swift)
    - [cli/fWarrangeCli/AppState.swift](cli/fWarrangeCli/AppState.swift)

## Issue19: 단축키 저장 파일명 날짜별 시퀀스 번호로 변경 (등록: 2026-04-12, 해결: 2026-04-12, commit: aa7fd85) ✅

* 목적: 단축키(cmd+7) 저장 시 매번 같은 파일명(`YYYY-MM-DD-hotkey.yml`)으로 덮어쓰던 문제 수정
* 상세:
    - 원인: `AppState.handleHotKeyAction(.save)`에서 파일명을 `\(date)-hotkey` 고정값으로 생성
    - 수정: 같은 날짜 prefix 기존 레이아웃을 스캔하여 다음 번호(`YYYY-MM-DD-1`, `-2`, …)로 저장
* 구현 명세:
    - 파일: [cli/fWarrangeCli/AppState.swift](cli/fWarrangeCli/AppState.swift#L180-L190)
    - `layoutManager.layouts`에서 `\(datePrefix)-` prefix 필터 → `Int(suffix)` 파싱 → `max() + 1`

## Issue18: logLevel 설정이 info로 덮어써지던 버그 수정 (등록: 2026-04-12, 해결: 2026-04-12, commit: f127709) ✅

* 목적: `_config.yml`에 `logLevel: 5`(critical)로 설정해도 실제로는 info 레벨 로그가 `wlog.log`에 기록되던 버그 수정
* 상세:
    - 원인1: `AppState.initialize()`의 fallback이 `?? 1`(debug)로 되어 있어 `settings.logLevel`이 nil일 때 debug로 떨어짐
    - 원인2: Logger 초기화 시 직접 YAML을 파싱하는 로직이 사용자 가독성용 주석 라인(`# logLevel: 0=verbose...`)을 먼저 매칭해 파싱 실패 후 Release 기본값(info)으로 fallback
    - 사용자가 숫자만 보고 레벨을 알기 어려운 UX 문제도 함께 해결
* 구현 명세:
    - `AppState.swift`: `settings.logLevel ?? 1` → `?? 5`로 fallback 통일
    - `SettingsService.swift`: `_config.yml` 저장 시 `logLevel` 라인 위에 `# logLevel: 0=verbose, 1=debug, 2=info, 3=warning, 4=error, 5=critical` 주석 자동 삽입
    - `Logger.swift`: `_config.yml` 파싱 시 `#`로 시작하는 주석 라인을 스킵하고 `logLevel:`로 시작하는 실제 설정 라인만 매칭
* 검증:
    - Release 빌드 성공, `/Applications/_nowage_app/`에 배포
    - `_config.yml` 삭제 후 재기동 → 주석 포함된 새 config 생성 확인
    - `logLevel: 5` 적용 시 `wlog.log` 파일 자체가 생성되지 않음 (info 이하 로그 완전 차단) 확인
    - REST API `http://localhost:3016/` 정상 응답 확인

 에러 메시지 한국어 통일 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: REST API 및 CLI의 영어 에러 메시지를 한국어로 통일
* 구현 명세:
    - `RESTServer.swift`: `methodNotAllowed()` 에러 메시지 "Method Not Allowed" → "허용되지 않는 HTTP 메서드입니다"
    - `CLIHandler.swift`: `exitError()` prefix "Error:" → "오류:"
    - 기타 에러 메시지는 이미 한국어 (13개 핸들러 확인 완료)
* 검증:
    - Release 빌드 성공, API 테스트 15개 엔드포인트 전체 PASS

## Issue16: 존재하지 않는 레이아웃 삭제 시 HTTP 404 응답 표준화 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: `DELETE /layouts/{name}` 호출 시 해당 레이아웃이 존재하지 않으면 HTTP 404를 반환하도록 표준화
* 구현 명세:
    - `RESTServer.swift`: `handleDeleteLayout`에서 `getLayouts().contains` 사전 검사 후 `.notFound()` 반환
    - `openapi.yaml`: DELETE /layouts/{name} 경로에 404 응답 코드 + ErrorResponse 스키마 명세
    - `E03.layout-delete-404.sh`: 존재하지 않는 레이아웃 삭제 시 404 검증 에러 테스트
* 검증:
    - API 테스트 PASS

## Issue15: 기본 레이아웃 관리 API 추가 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: 기본 레이아웃을 지정/조회하는 REST API 엔드포인트 추가
* 구현 명세:
    - `RESTServer.swift`: `GET /settings/default-layout` + `PUT /settings/default-layout` 라우팅 및 핸들러
    - `RESTServerHandlers`: `getDefaultLayoutName`, `setDefaultLayoutName` 클로저
    - `AppState.swift`: `settingsService` 기반 실제 저장/로드 연결
    - `openapi.yaml`: 엔드포인트 명세
    - `12.default-layout.sh`: GET/PUT 테스트 + 원복
* 검증:
    - API 테스트 PASS

## Issue14: API/CLI 기본 레이아웃 이름 불일치 통일 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: API/CLI 모두 기본 레이아웃 이름을 `default`로 통일
* 구현 명세:
    - `RESTServer.swift`: `handleCapture` 기본값 `"default"`
    - `CLIHandler.swift`: capture 커맨드 기본값 `"default"`
    - `openapi.yaml`: CaptureRequest 스키마에 `defaults to "default"` 명시
    - `validation_strategy.md`: 양쪽 `default` 통일 완료 기록
* 검증:
    - API/CLI 양쪽 기본값 일치 확인

## Issue13: Paid 버전 관련 불필요 코드 삭제 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: `paid_version.md` 설계 문서 기준으로 불필요한 Paid 관련 코드 정리
* 구현 명세:
    - `paid_version.md`: 관련 소스 파일 테이블에서 실제 미존재 함수 `isPaidAppRunning` 참조 삭제
    - Swift 소스에는 삭제 대상 없음 (모든 함수가 실제 사용 중)
    - `com.finfra` 레거시 번들ID 없음 확인
* 검증:
    - Release 빌드 성공

## Issue9: 메뉴바 Settings/Management Window/About 버튼 추가 — Paid 버전 연동 (등록: 2026-04-08, 해결: 2026-04-09, commit: TBD) ✅

* 목적: 메뉴바에 Settings, Management Window, About 3개 버튼을 추가하고 paid 버전 설치 여부에 따라 기능 분기
* 구현 명세:
    - `MenuBarView.swift`: Settings / Management Window / About 3개 버튼 UI, `tryLaunchPaidFeature()` 호출, `showPaidOnlyAlert()` (App Store/Locate/Cancel), `bundleIdentifier == "kr.finfra.fWarrange"` 검증
    - `AppState.swift`: `detectPaidApp()` 경로 기반 감지 + `launchPaidApp()` 실행 + `tryLaunchPaidFeature()` 안내 알림
* 검증:
    - 3개 버튼 동작 확인, Bundle ID `kr.finfra` 올바름

## Issue12: CLI 커맨드 테스트 스크립트 체계 구축 (등록: 2026-04-08, 해결: 2026-04-08, commit: TBD) ✅

* 목적: apiTest와 동일한 체계로 CLI 커맨드 테스트 가능하게 함
* 구현 명세:
    - `cli/_tool/cmdTestDo.sh`: 전체/개별/에러 테스트 실행기
    - `cli/_tool/cmdTest/`: 정상 18개 + 에러 7개 테스트 스크립트
    - 시나리오 테스트 (API + CLI): 레이아웃 CRUD + 복구 + 실패 검증 9/9 PASS
* 검증:
    - API 시나리오 9/9 PASS, CLI 시나리오 9/9 PASS
    - 리포트: `cli/_doc_work/report/check_api_cmd_report.md`

## Issue10: 앱 시작 시 Paid 버전 감지 → fWarrange 실행 후 메뉴바에서 제거 (등록: 2026-04-08, 해결: 2026-04-08, commit: d78b046) ✅

* 목적: fWarrangeCli 시작 시 fWarrange(Paid) 감지되면 fWarrange를 실행하고 fWarrangeCli는 메뉴바에서 제거
* 구현 명세:
    - `AppState.swift`: terminate() 제거 → `hideMenuBar` 플래그로 메뉴바만 숨김, REST 서버 유지
    - `fWarrangeCliApp.swift`: `MenuBarExtra(isInserted:)` 바인딩으로 동적 제어
    - `detectPaidApp()`: `NSWorkspace` bundleID 검색 제거, `/Applications/` 명시적 경로만 검색 (~/Library 제외)
    - Paid 앱 실행 성공 시에만 메뉴바 숨김, 실패 시 메뉴바 유지
* 검증:
    - Paid 앱 미실행 시: 메뉴바 아이콘 표시, REST API 정상
    - Paid 앱 실행 성공 시: 메뉴바 숨김, REST API 정상 유지

## Issue11: 메뉴바 아이콘 대각선 클리핑 적용 (등록: 2026-04-08, 해결: 2026-04-08, commit: c4bd7a1) ✅

* 목적: 메뉴바 아이콘을 대각선으로 잘라서 아래 부분을 숨김 처리
* 구현 명세:
    - fWarrangeCliApp.swift: `makeMenuBarIcon()` 정적 메서드 추가
    - `rectangle.3.group` SF Symbol에 `NSBezierPath` 클리핑 적용 (왼쪽 하단 ~ 오른쪽 40% 높이 대각선)
    - `MenuBarExtra` label을 커스텀 `Image(nsImage:)` 방식으로 변경
* 검증:
    - Debug 빌드 및 실행 확인

## Issue6: CLI 커맨드 인터페이스 구현 (등록: 2026-04-08, 해결: 2026-04-08, commit: 584819e) ✅

* 목적: 터미널에서 `fWarrangeCli <command>` 형태로 직접 명령 실행 가능하게 함
* 구현 명세:
    - CLIHandler.swift: CLI 커맨드 파싱 및 REST API 호출 핸들러
    - fWarrangeCliApp.swift: ProcessInfo 기반 CLI/GUI 모드 분기
    - REST API 1:1 대응 — 내부적으로 localhost REST API 호출
* 검증:
    - 설계 문서 대비 전체 커맨드 구현 확인 (정보/레이아웃/창/시스템)
    - 공통 옵션 (--port, --host, --pretty, -q) 구현 확인

## Issue8: 서비스 관리 방식 전환 — LaunchAgent/brew service → 앱 내 LoginItem (등록: 2026-04-08, 해결: 2026-04-08, commit: 7ae9a38) ✅

* 목적: OS 시작 시 자동 실행을 외부 서비스(LaunchAgent, brew services) 대신 앱 내 SMAppService(LoginItem)로 관리
* 구현 명세:
    - cli/service/ 전체 삭제 (LaunchAgent plist, install.sh, uninstall.sh)
    - Formula service 블록 제거 (Homebrew는 설치만 담당)
    - AppSettings.launchAtLogin 필드 추가
    - AppState: SMAppService 기반 syncLaunchAtLogin/setLaunchAtLogin
    - MenuBarView: "로그인 시 자동 시작" 토글 추가
    - README 문서 업데이트
* 검증:
    - Debug 빌드 성공 확인

## Issue7: 단축키 설정 human-readable 형식 지원 (등록: 2026-04-08, 해결: 2026-04-08, commit: e3510da) ✅

* 목적: _config.yml의 단축키 설정을 사용자가 직접 수정할 수 있는 형식으로 변경
* 구현 명세:
    - AppSettings.swift: `KeyboardShortcutConfig.from(displayString:)` 역매핑 메서드 추가
    - SettingsService.swift: 저장 시 `"⌘F7"` 형식, 파싱 시 레거시(`98:1048576`) + human-readable 양쪽 지원
* 검증:
    - Debug 빌드 성공 확인
    - _config.yml 형식 변환 확인 (`98:1048576` → `"⌘F7"`)

## Issue4: GET /settings 엔드포인트 추가 (등록: 2026-04-08, 해결: 2026-04-08, commit: f953436) ✅

* 목적: 현재 앱 설정값과 데이터 경로를 REST API로 조회 가능하게 함
* 구현 명세:
    - RESTServer.swift: `GET /api/v1/settings` 라우트 + 핸들러 추가
    - openapi.yaml: `/settings` 엔드포인트 정의, 미사용 `/locale` 제거
* 검증:
    - `01.settings.sh` 테스트 스크립트 실행 확인

## Issue3: openapi.yaml 기반 API 테스트 스크립트 구현 (등록: 2026-04-07, 해결: 2026-04-08, commit: 67cd061) ✅

* 목적: apiTest_plan.md에 정의된 18개 엔드포인트 테스트 스크립트를 모두 생성하고, apiTestDo.sh로 순차/개별 실행 가능하게 함
* 구현 명세:
    - Shell: cli/_tool/apiTest/ 내 18개 정상 + 7개 에러 테스트 스크립트 생성
    - apiTestDo.sh 전체/개별 실행 래퍼 추가
* 검증:
    - apiTestDo.sh로 전체 실행 테스트

## Issue5: Homebrew service 방식 fWarrangeCli 서비스 관리 (등록: 2026-04-08, 해결: 2026-04-08, commit: 5fd0601) ✅

* 목적: `brew services start/stop/restart fWarrangeCli` 명령으로 fWarrangeCli 데몬을 관리 가능하게 함
* 구현 명세:
    - Formula/fWarrangeCli.rb: pre-built .app 설치 + brew services 지원
    - cli/service/fWarrangeCli.plist: LaunchAgent plist 생성
    - cli/service/install.sh: plist 설치 스크립트
    - cli/service/uninstall.sh: plist 제거 스크립트
* 검증:
    - brew install/services start/stop/restart/info 동작 확인
    - 로컬 tap (finfra/tap) 테스트 완료

## Issue2: 환경변수 fWarrangeCli_config 기반 데이터 경로 설정 (등록: 2026-04-07, 해결: 2026-04-07, commit: 13fc324) ✅

* 목적: 환경변수 fWarrangeCli_config로 데이터 디렉토리 경로를 외부에서 지정 가능하게 함
* 상세:
    - 환경변수 미설정 시 ~/Documents/finfra/fWarrange/ 기본값 사용
    - 기존 기본 경로 fWarrangeData → fWarrange 변경
* 구현 명세:
    - LayoutStorageService.swift: resolveDefaultBaseDirectory()에 환경변수 우선 확인 로직 추가
    - Logger.swift: 로그 디렉토리 경로도 동일 환경변수 로직 적용

## Issue1: health 엔드포인트에 기본 정보 추가 (등록: 2026-04-07, 해결: 2026-04-07, commit: 748eaf2) ✅

* 목적: GET / health 응답에 layout_count, uptime_seconds 필드 추가
* 구현 명세:
    - RESTServer.swift handleHealthCheck에 uptime_seconds, layout_count 추가
    - apiTest.sh 테스트 스크립트 생성

# ⏸️ 보류

# 🚫 취소

# 📜 참고
