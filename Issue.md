---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---

* Issue HWM: 46
* Save Point: 2026-04-20 (58cd86f) Fix(Issue43): PATCH /settings/{advanced,general} effectiveLogLevel·effectiveHotkeysEnabled 추가
  - 9e9b577 (2026-04-20) - Docs: Close Issue44
  - f297278 (2026-04-20) - Fix: Close Issue45 (deploy symlink 중첩 버그 수정)
  - 65c593a (2026-04-20) - Docs: Close Issue42 (pairApp Issue52 Full Mirror — shutdown API + 호환성 필드 완결)

# 🤔 결정사항

# 🌱 이슈후보
1. Default 레이아웃 복구 않됨. 트리거 로그만 있음.[2026-04-13 14:32:37.131] 🐛 DEBUG: HotKeyService: 단축키 트리거 (id=4)

# 🚧 진행중

# 📕 중요
# 📙 일반
# 📗 선택

# ✅ 완료
## Issue46: paidApp 실행 시 cliApp MenuBarExtra 조건부 숨김 (등록: 2026.04.20) (✅ 완료, 08eadd5) ✅
* 목적: paidApp(fWarrange)이 자체 MenuBarExtra를 소유하는 구조로 복원. cliApp은 paidApp 미실행 시에만 메뉴바 아이콘 표시
* 연관 이슈: paidApp Issue201
* 상세:
    - `fWarrangeCliApp.swift`: `MenuBarExtra(isInserted:)` Binding으로 `paidAppMonitor.state == .cliOnly`일 때만 표시
    - `MenuBarView.swift`: `paidAppActive` 모드 제거 (cliOnly 단독 운영)

## Issue44: PaidAppLifecycleNotifier paidApp 방식 통일 대응 (등록: 2026.04.20) (✅ 완료, 9e9b577) ✅
* 목적: paidApp(fWarrange) PaidAppLifecycleNotifier 변경에 따라 cliApp register 엔드포인트가 client-side sessionId를 수용하도록 수정
* 상세: 
    - POST /api/v2/paidapp/register: 요청 body의 sessionId를 그대로 사용 (현재는 서버가 생성)
    - GET /api/v2/cli/version 응답에 minPaidAppVersion 필드 포함 여부 확인 및 추가
    - fSnippet cliApp(fSnippetCli)과 동일한 API 계약 유지

## Issue45: deploy symlink 중첩 버그 수정 (fwc-deploy-debug.sh, fwc-deploy-brew.sh) (등록: 2026.04.20) (✅ 완료, f297278) ✅
* 목적: cp -R로 생성된 디렉토리 잔존 시 ln -sfn이 내부에 중첩 symlink를 생성하는 버그 수정
* 상세: fwc-deploy-debug.sh: rm -f → rm -rf. fwc-deploy-brew.sh Step 7: ln -sfn 전 rm -rf 추가

## Issue43: REST API PATCH /settings/{advanced,general} effectiveLogLevel·effectiveHotkeysEnabled 응답 누락 수정 (등록: 2026-04-20) (✅ 완료, 58cd86f) ✅
* 목적: pairApp Issue196에서 추가된 `effectiveLogLevel`, `effectiveHotkeysEnabled` 필드가 GET 응답에는 있으나 PATCH 응답에 누락 — PATCH 응답에도 동일하게 포함
* 상세:
    - `RESTServer.swift` PATCH 응답 블록에 두 필드 추가
    - `/settings/advanced` PATCH 응답: `effectiveLogLevel` 추가 (`Logger.shared.currentLogLevel`)
    - `/settings/general` PATCH 응답: `effectiveHotkeysEnabled` 추가 (`!Env.hotkeysDisabled`)
* 구현 명세:
    - `cli/fWarrangeCli/Services/RESTServer.swift` — PATCH 탭별 응답 블록 (`path.hasSuffix("/advanced")` · `path.hasSuffix("/general")`) 에 effective 필드 추가 (7줄 변경)
* 연관: pairApp(fSnippetCli #25) Issue196 (신규 필드 원천), QA-C 적발

## Issue42: pairApp(fSnippetCli) Issue52 Full Mirror — paidApp 등록 응답 호환성 필드 + shutdown API (등록: 2026-04-20) (✅ 완료, 1357e3e) ✅
* 목적: fSnippetCli Issue52에서 완료된 Phase A 호환성 확장과 Phase 1 shutdown 엔드포인트를 fWarrangeCli에 동일하게 이식
* 상세:
    - `PaidAppRegisterResponse`에 `ok`, `cliVersion`, `minPaidAppVersion`, `compatible` 필드 추가 — pairApp과 응답 스키마 일치
    - `POST /api/v2/shutdown` 엔드포인트 추가 — `reason`(로그용) + `delayMs`(종료 지연) body 수락
    - `openapi_v2.yaml`: `PaidAppRegisterResponse` 스키마 확장 + `/shutdown` 경로 신규

## Issue40: `_config.yml` 번들 시드 복사 패턴 도입 (pairApp fSnippetCli 정합) (등록: 2026-04-20) (✅ 완료, 7a8b06b) ✅
* 목적: `~/Documents/finfra/fWarrangeData/_config.yml` 부재 시 앱 번들 시드 복사. pairApp fSnippetCli `copyConfigFromBundle()` 패턴 정합화.
* 상세: `SettingsService.swift` `copyConfigFromBundle()` 추가, `_config.yml` 번들 리소스 등록, logLevel: 5(critical) 기본값

## Issue41: SingleInstanceGuard getpid() 교체 + performHandoffStart() 이식 (pairApp Issue53 v1+v2) (등록: 2026.04.20) (✅ 완료, 03192bb) ✅
* 목적: NSRunningApplication.current.processIdentifier 의 -1 반환 위험 제거 + performHandoffStart() 로 open 경로 비동기 포트 충돌 해소
* 상세: 
1) SingleInstanceGuard.myPID를 NSRunningApplication.current.processIdentifier → getpid()로 교체 (AppKit 초기화 전 -1 반환 방지)
2) BrewServiceSync에 handoffInProgress 플래그 + performHandoffStart() 추가: open 경로에서 brew services start 동기 호출 → Foundation.exit(0) self-terminate → launchd-bootstrap이 primary 승계
3) onAppStop()에 handoff 억제 로직 추가 (race 차단)



## Issue39: brew services ↔ 메뉴바 앱 상태 동기화 재설계 — 4-quadrant 상태 매트릭스 기반 (등록: 2026-04-20, 재설계: 2026-04-20, 해결: 2026-04-20, commit: 3867459) ✅
* 목적: `brew services` (launchd) 와 메뉴바 GUI 앱의 수명주기를 **4-quadrant 상태 매트릭스**로 명시 정의하고, 4개 트리거(brew start / brew stop / app start / app stop) 각각에서 상대 상태를 양방향 동기화. `/opt/homebrew/var/fWarrangeCli/` 경로 원천 차단(Phase 1) 과 Bundle ID 기반 단일 인스턴스 가드(Phase 4) 를 기반으로 각 전이를 no-double-start/no-ghost-state 로 수렴.
* plan: `cli/_doc_work/plan/brew-service-menubar-sync_plan.md`
* report: `cli/_doc_work/report/brew-service-menubar-sync_issue39_report.md`
* 재설계 상태 매트릭스 (2026-04-20 사용자 결정):

    | Trigger          | 상대 상태             | 기대 동작                                            |
    | :--------------- | :-------------------- | :--------------------------------------------------- |
    | **brew start**   | 앱 실행 중             | brew state 만 `started` 로 이동 (앱 재기동 없음)       |
    | **brew start**   | 앱 정지                | 앱 시작 + brew state `started`                        |
    | **brew stop**    | 앱 정지                | brew state `stopped`                                  |
    | **brew stop**    | 앱 실행 중             | brew state `stopped` (launchctl unload, 앱 종료 동반) |
    | **app start**    | brew `started`        | 앱만 시작, brew 호출 skip                             |
    | **app start**    | brew `stopped`        | 앱 시작 + `brew services start` 호출 (state 동기화)   |
    | **app stop**     | brew `started`        | `brew services stop` 호출 + `NSApplication.terminate` |
    | **app stop**     | brew `stopped`        | `terminate` 만 (brew 호출 skip)                       |

* 집행 지점 (3개 코드 포인트로 매트릭스 전체 커버):
    - **SingleInstanceGuard** — `brew start` × 앱 실행 중 → 신규 프로세스가 `exit(0)`, 기존 앱 유지 + plist `keep_alive: successful_exit: false` 로 launchd 재기동 억제 → brew state 만 `started` 수렴
    - **BrewServiceSync.onAppStart** — `app start` × brew `stopped` → `brew services start` 호출. 이미 `started` 면 skip (launchctl list 검사)
    - **BrewServiceSync.onAppStop** — `app stop` × brew `started` → `brew services stop` 호출 후 terminate. 이미 `stopped` 면 skip
* 증상 (사용자 실측 2026-04-20):
    - case 2: 메뉴바 종료 후 `brew services start` → `Bootstrap failed: 5: Input/output error`. `stop` 후 `start` 하면 복구 — Phase 2 (onAppStop) 로 해결
    - case 3: `open` 으로 앱 기동 시 `brew services list` `stopped` 로 남음 — Phase 3 (onAppStart) 로 해결
    - case 4: `open` 선행 + `brew services start` → 2개 바이너리 (var 경로 vs Formula 경로) 동시 실행 — Phase 1 (var 경로 제거) + Phase 4 (SingleInstanceGuard) 로 해결
* 구현 명세:
    - Phase 1 (`cli/_tool/fwc-config.sh`, `fwc-deploy-debug.sh`, `fwc-run-xcode.sh`): DerivedData 직접 실행, `/opt/homebrew/var/fWarrangeCli/` 미생성, `_nowage_app` 심링크 갱신
    - Phase 2 (`cli/fWarrangeCli/MenuBarView.swift` 종료 액션): `BrewServiceSync.onAppStop(timeout: 2.0)` → `NSApplication.terminate`. 내부에서 launchctl 로드 상태 확인 후 조건부 `brew services stop`
    - Phase 3 (`cli/fWarrangeCli/AppState.initialize()`): `BrewServiceSync.onAppStart()` 호출. 내부에서 (a) launchd 기동 프로세스면 skip, (b) 이미 로드됐으면 skip, (c) `UserDefaults` `fwc.autoStartBrewService == false` 면 skip, (d) brew 바이너리 미존재 시 skip, 그 외 `brew services start` 비동기 호출. Formula/Debug 경로 구분 제거 — SingleInstanceGuard 가 중복 제거 담당
    - Phase 4 (`cli/fWarrangeCli/Services/SingleInstanceGuard.swift` + `fWarrangeCliApp.swift` `AppEntry.main`): **launchd-bootstrap 프로세스 우선권** 규칙 적용. `XPC_SERVICE_NAME == "homebrew.mxcl.fwarrange-cli"` 로 자기 자신이 launchd-spawned 인지 판정. launchd-spawned 면 기존 인스턴스를 `terminate()` 후 자신이 survive (brew state `started` 수렴), 아니면 기존 인스턴스 유지 + 자신 `exit(0)`. 승자 경로는 REST 포트 3016 bind 경합 방지를 위해 기존 프로세스 완전 종료까지 최대 3초 폴링 대기 포함. `CLIHandler.handleIfNeeded()` 이후, `fWarrangeCliApp.main()` 이전 시점
    - 실측 버그 (2026-04-20):
        1. `getParentPID() == 1` 으로 launchd 기동 판정 시 macOS 모든 GUI 앱 PPID=1 특성상 상시 true → `onAppStart` 무한 skip. `XPC_SERVICE_NAME` 매칭만으로 판정하도록 단순화
        2. 초기 Phase 4 구현(신규 프로세스가 무조건 exit) 에서는 open-기동분이 survive 하여 launchd 가 띄운 프로세스가 즉시 사라짐 → plist 로드됐지만 `brew services list` 는 `stopped` 로 표시. 승자 규칙 반전으로 해결
    - 검증: 8개 매트릭스 셀 사용자 실측 PASS. 상세는 report 참조
    - pairApp 이식: fSnippetCli(#25) — 본 이슈 해결 후 Full Mirror 이슈 신규 등록

## Issue38: `/run` 계열 전 경로에 brew service 존재 기반 분기 로직 도입 (등록: 2026-04-19, 해결: 2026-04-19, commit: 84a258c) ✅
* 목적: `/deploy brew local` 로 설치된 LaunchAgent 가 실행 중인 상태에서 `/run` 계열(`build-deploy`, `deploy-run`, `tcc`, `run-only`)을 호출할 때 발생하는 launchd respawn 경합 / 포트 단일 인스턴스 충돌을 제거. brew service 실행 여부에 따라 Debug 오버라이드 경로를 명시적으로 분기. pairApp(fSnippetCli #25) Issue49 에서 선행 구현·검증 완료된 구조를 Full Mirror 이식.
* 참조 원본: pairApp fSnippetCli#25 `2d4ec67` — Feat(Script)(Issue49)
* 배경:
    - Issue36(c68e70f) 완료 후 `brew services` 단일 표준 확립 → Formula `keep_alive { successful_exit: false }` 설정 (pairApp Issue46 대응)
    - pairApp 실측: `/run run-only` 호출 시 `pkill` 은 launchd 입장에서 crash 로 분류 → Cellar/Release 바이너리가 즉시 respawn → `open` 으로 요청한 Debug 바이너리와 포트 단일 인스턴스 가드 경합 발생
    - 동일 원인이 `build-deploy` / `deploy-run` / `tcc` 경로에도 존재 — 이들은 `cp -R` 로 덮어쓰기까지 진행하므로 Release 바이너리가 먼저 포트를 잡으면 Debug 기동 자체가 실패
    - fWarrangeCli 는 Issue37 Full Mirror 진행 중이므로 동일 패턴 이식 필요
* 원인 분석:
    - **원인 1 — `pkill` 의 launchd 해석**: SIGTERM/SIGKILL 로 프로세스를 죽여도 `successful_exit: false` 규칙상 launchd 는 비정상 종료로 간주. `brew services stop` 로 명시적으로 unload 해야만 재기동하지 않음
    - **원인 2 — plist 존재 기반 판정의 한계**: `~/Library/LaunchAgents/homebrew.mxcl.fwarrange-cli.plist` 는 `brew services stop` 후에도 남음. plist 존재를 기준으로 "service 있음 → restart" 분기를 하면, Debug 세션 중 `/run run-only` 가 의도치 않게 Release 바이너리를 복원시키는 오작동 발생
    - **원인 3 — Launch Services `-600`**: `pkill` 직후 같은 경로로 `open` 을 호출하면 macOS Launch Services 내부 정리 전이어서 `-600 (procNotFound)` 반환 — 앱이 기동되지 않음
* 구현 명세 (pairApp 2d4ec67 기준 Full Mirror):
    - **Phase 1 (Config)**: `fwc-config.sh` 에 `BREW_FORMULA`, `BREW_SERVICE_LABEL`, `BREW_SERVICE_PLIST`, `brew_service_running()` 헬퍼 추가
    - **Phase 2 (Run)**: `fwc-run-xcode.sh` 에 `brew_service_stop_for_debug()` 신규 + `run_app_only` 재작성 (service 실행 중: `brew services restart`, 미등록/정지: `kill + sleep 0.5 + open` 3회 retry)
    - **디스패치**: `build-deploy` / `deploy-run` / `tcc` 상단에 `brew_service_stop_for_debug` 선행 호출
* 검증 결과 (3시나리오):
    - [x] A) `brew services start` + `/run build-deploy` → stop 메시지 후 Debug 빌드/기동 정상 (exit 0)
    - [x] B) `brew services stop` + `/run run-only` → `kill + open` 분기, REST API 3016 응답 (app=fWarrangeCli, uptime=2s)
    - [x] C) `brew services start` + `/run run-only` → `brew services restart` 분기 진입 (REST uptime 연속 증가는 macOS `keep_alive` + `process_type :interactive` 특성 — pairApp 동일 동작, 별도 이슈 검토)
* 치환 규칙 (pairApp → fWarrangeCli):
    - 포트: `3015` → `3016`
    - Formula: `fsnippet-cli` → `fwarrange-cli`
    - Prefix: `fsc-` → `fwc-`
    - Bundle ID: `kr.finfra.fSnippetCli` → `kr.finfra.fWarrangeCli`
* 연관: Issue37(Full Mirror 이식)의 Phase 2(Run) 보완 — Issue37 진행 중 본 이슈가 pairApp Issue49 선행으로 식별됨. 동시 처리 완료

## Issue37: pairApp(fSnippetCli) 검증 완료된 deploy/run 스크립트 구조 Full Mirror 이식 (등록: 2026-04-19, 해결: 2026-04-19, commit: f7b4233, d8eec73, 98caea9, 20c054d) ✅
* 목적: pairApp(fSnippetCli #25)에서 리팩터링 + 안전성 테스트 완료된 `fsc-*.sh` 6종 구조를 `fwc-*.sh` 로 Full Mirror 이식 — prefix/Bundle ID/포트(3015→3016)/Formula명만 치환, 로직·함수·단계 번호 100% 일치시켜 양 프로젝트 구조 수렴 지속
* plan: `cli/_doc_work/plan/deploy-run-sync-from-pairapp_plan.md`
* task: `cli/_doc_work/tasks/deploy-run-sync-from-pairapp_task.md`
* 상세:
    - pairApp 2026-04-19 17:22 기준 `fsc-config.sh`(21줄), `fsc-run-xcode.sh`(250줄), `fsc-deploy-brew.sh`(521줄), `fsc-deploy-debug.sh`(87줄), `kill.sh`(30줄) 를 소스 오브 트루스로 삼음
    - 이식 제외: `send_right_cmd.py`, `testBoard.txt`, ZTest 9단계 (스니펫 전용 TDD — cliApp 비대상)
    - 현재 cliApp 고유 설계 보존: `apiTestDo.sh` + `cmdTestDo.sh` 호출 구조, `api/openapi_v2.yaml` 병행
* 배경:
    - Issue33(cc29453) — `fwc-run-xcode.sh` 자기완결 build 패턴 전환 (Phase A 완료)
    - Issue34(7a582c2, fb48173) — `/deploy brew` 서브커맨드 + kebab-case package 표준
    - Issue35 — `brew services` 단일 표준 채택
    - Issue36(c68e70f) — 앱 내부 SMAppService 경로 제거
    - 본 이슈: Issue33~36 누적 성과를 pairApp 최신 구조와 최종 동기화
* 구현 명세 (Phase별 완료 해시):
    - **Phase 1-3 (Core/Run/Debug)** `f7b4233` — fwc-config.sh 확장, kill.sh 조건부 stop, fwc-run-xcode.sh 전면 교체(tcc 서브커맨드·reset_tcc_accessibility·xcode_run_stop), fwc-deploy-debug.sh 심링크+skip_copy
    - **Phase 4 (Brew)** `d8eec73` — fwc-deploy-brew.sh 521줄 mirror (Step 2 bootout / Step 7 심링크 / Step 8 services start / Step 9 포트 3016 헬스체크), Formula heredoc `service do` 블록(class FwarrangeCli, keep_alive successful_exit: false)
    - **Phase 5 (nPTiR 정리)** `98caea9` — `cli/_tool/Issue22_verify_report.md` → `_doc_work/report/issue22_verify_report.md`
    - **Phase 4 부산물** `20c054d` — xcodeproj 메인 타겟 Release 코드사인 설정 동반 적용 (CODE_SIGN_IDENTITY/STYLE, DEVELOPMENT_TEAM, PROVISIONING_PROFILE_SPECIFIER)
* 검증 결과:
    - [x] `fwc-*.sh` 6개 파일 pairApp 대비 diff 0 (Issue 번호·주석 역참조·desc 의도된 차이만)
    - [x] `/deploy brew local` 9단계 전부 exit 0 — Cellar 설치, services Running, REST 3016 `app=fWarrangeCli`
    - [x] `brew services start fwarrange-cli` LaunchAgent 등록 + 자동 기동
    - [x] `/run tcc` 경로 동작 (tccutil 자체는 macOS 25.5.0에서 Usage 반환 — pairApp 원본과 동일, 별도 OS 호환 이슈 후보)
    - [x] `cli/_tool/` 루트 .md 파일 0개
    - [x] `_public/` git status 깔끔 + "Refactor(Issue37)" 커밋 메시지
* 연관: pairApp(fSnippetCli #25) Issue43/45/46/47/48 동일 설계 원천. pairApp `_public/Issue.md` 이슈후보 #2 (fsc-test.sh 역이식)은 본 이슈 분석 중 발견 — 범위 밖으로 pairApp 측 별도 트랙. Issue38 (pairApp Issue49 Full Mirror)과 함께 완료

## Issue36: 앱 내부 SMAppService 기반 Login Item 등록 차단 — brew services 배타 원칙 준수 (등록: 2026-04-19) (✅ 완료, c68e70f) ✅
* 목적: `AppState.syncLaunchAtLogin()` 이 `SMAppService.mainApp.register()` 로 Login Item 을 자동 추가하는 동작을 제거하여 Issue35 의 `brew services` 배타 원칙을 앱 내부까지 완전 준수
* 상세:
    - `AppState.init()` 말미에서 `syncLaunchAtLogin(settings.launchAtLogin ?? false)` 호출 제거
    - `syncLaunchAtLogin(_:)` 을 no-op + 경고 로그로 전환 (SMAppService 호출 전면 제거)
    - `setLaunchAtLogin(_:)` 및 API v2 `launchAtLogin` 필드는 유지 (backward compat, silent no-op)
    - pairApp(fSnippetCli #25) Issue47 과 pair 대응
* 배경:
    - Issue34(commit 7a582c2) — `/deploy brew local` 서브커맨드로 `brew services` 기반 배포 인프라 구축
    - Issue35(진행중) — Formula `service do` 블록 + `brew services` 단일 표준 채택 선언
    - Issue35 구현 명세에 **"`brew services`(LaunchAgent) 단일 표준 — Login Item/SMAppService/수동 등록과 동시 사용 금지"** 명문화
    - 그러나 Issue35 커밋 범위는 **배포 스크립트/Formula 레벨**에만 적용 → 앱 내부 `AppState.syncLaunchAtLogin()` (SMAppService 기반) 는 잔존
    - pairApp(fSnippetCli #25) Issue47 동일 패턴 선행 등록 (2026-04-19) — 본 이슈는 fWarrangeCli 측 pair 대응
* 원인 분석:
    - **원인 1 — `AppState.syncLaunchAtLogin()` SMAppService 호출**: `cli/fWarrangeCli/AppState.swift` L458-477 이 `SMAppService.mainApp.register()` 호출 → macOS 가 "Login Item Added" 시스템 알림 표시 + 시스템 설정 > 로그인 항목 목록에 추가
    - **원인 2 — `AppState.init()` 진입점**: L428 `syncLaunchAtLogin(settings.launchAtLogin ?? false)` 호출 → autoStart 가 `true` 이면 기동 시마다 재등록
    - **원인 3 — `setLaunchAtLogin()` 경유**: MenuBarView 토글 → `AppState.setLaunchAtLogin(true)` → `syncLaunchAtLogin(true)` → SMAppService 등록
    - **구조적 배경**: Issue34 이전에는 앱 내부 SMAppService 기반 Login Item 과 `brew services` LaunchAgent 가 동일 목적(로그인 시 자동 기동)을 이중 관리. Issue35 에서 배포 스크립트 경로만 제거 → 앱 내부 경로는 배타 원칙 위배 상태로 방치
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5-C "배타 원칙"
    - LaunchAgent(brew services) 와 SMAppService 는 **동일 바이너리 이중 등록** 형태가 되어 launchd 가 예측 불가능한 타이밍으로 프로세스 2회 기동 시도
    - 오픈소스 배포 표준은 `brew services` 이므로 SMAppService 경로는 제거가 원칙
* 해결 전략:
    - **전략 A (no-op + 유지)**: `AppState.syncLaunchAtLogin()` 내부를 no-op 로 변경 + `init()` 호출부 제거. API v2 `launchAtLogin` prefs 는 backward compat 유지 (읽기/쓰기는 prefs 값만 단순 저장, 실 등록은 안 함)
    - **전략 B (전면 제거)**: `launchAtLogin` 프로퍼티 + API 필드 전체 삭제
    - **채택**: 전략 A (최소 침습 + backward compat + API v2 호환 유지). 전략 B 는 API 클라이언트 breaking change 유발
    - pairApp Issue47 과 동일 전략
* 구현 명세:
    - `cli/fWarrangeCli/AppState.swift`:
        - L428 `init()` 말미 `syncLaunchAtLogin(settings.launchAtLogin ?? false)` 호출 제거
        - L458-477 `syncLaunchAtLogin(_:)` 내부 SMAppService 호출 전부 제거 → no-op + 경고 로그 "Issue36: brew services 배타 원칙, SMAppService 경로 obsolete"
        - L479-483 `setLaunchAtLogin(_:)` 은 유지 (prefs 저장 + syncLaunchAtLogin no-op 호출)
        - 함수 상단에 obsolete 주석 추가
    - `cli/fWarrangeCli/MenuBarView.swift`: 수정 없음 (토글 UI 유지, silent no-op)
    - `cli/fWarrangeCli/Models/AppSettings.swift`: 수정 없음 (`launchAtLogin: Bool?` 프로퍼티 유지)
    - API v2 `launchAtLogin` 필드 및 `SettingsService` 영속화 유지 (backward compat)
* 설계 원칙:
    - **배타 원칙 완전 이행**: 앱 내부까지 `brew services` 일원화
    - **최소 침습**: API/Settings 시그니처 변경 없음 → v2 클라이언트 호환
    - **이력 보존**: `syncLaunchAtLogin` 함수 유지 + obsolete 사유 주석
* 검증:
    - [ ] Release 빌드 성공 (`xcodebuild -scheme fWarrangeCli -configuration Release build`)
    - [ ] `/deploy brew local` 재설치 후 `brew services start fwarrange-cli` 기동
    - [ ] 시스템 설정 > 일반 > 로그인 항목에 **fWarrangeCli 가 추가되지 않음** 확인 (기존 항목은 사용자가 수동 제거)
    - [ ] macOS "Login Item Added" 시스템 알림 미노출 확인
    - [ ] API `GET /api/v2/settings` 응답에 `launchAtLogin` 필드 존재 (backward compat)
    - [ ] API `PUT /api/v2/settings` 로 `launchAtLogin=true` 설정 후에도 실제 등록 안 됨 (silent no-op)
* 관련 파일:
    - `cli/fWarrangeCli/AppState.swift` (L428 호출 제거 + L458-477 no-op 전환)
    - `cli/fWarrangeCli/MenuBarView.swift` (수정 없음, 참고)
    - `cli/fWarrangeCli/Models/AppSettings.swift` (수정 없음, 참고)
    - `cli/fWarrangeCli/Services/RESTServer.swift` (수정 없음, 참고)
* 참조:
    - Issue34 (/deploy brew 서브커맨드 확장)
    - Issue35 (brew services 자동 시작 + 배타 원칙 선언)
    - pairApp Issue47 (fSnippetCli 동일 패턴, 2026-04-19 등록)
    - homebrew_tap_deploy.md §7-5-C 배타 원칙

## Issue33: fwc-run-xcode.sh 구조를 pairApp 자기완결 패턴으로 수렴 (등록: 2026-04-18) (✅ 완료, cc29453) ✅
* 목적: `xcode_build()` 내부에서 `xcode_stop()` 을 선행 호출하도록 재편하여 dispatcher 단순화 + build 진입 시 stop 누락 가능성 원천 차단
* 배경: 2026-04-18 run_diff_pairApp 레포트로 양쪽 구조 비교 결과, pairApp은 자기완결 build, cliApp은 dispatcher 선행 stop 패턴. 실제 "stop 없는 build" 사용 케이스가 없으므로 자기완결이 실무상 유리
* report:
    - 배경 비교: `cli/_doc_work/report/run_diff_pairApp.md`
    - 구현 보고: `cli/_doc_work/report/fwc-run-self-contained_issue33_report.md`
* 상세:
    - `fwc-run-xcode.sh`:
        * `xcode_stop()` 진입부에 `open_project` 호출 추가 (단독 실행 안전성 확보)
        * `xcode_build()` 진입부에서 `xcode_stop` 함수 호출로 변경 (기존 dispatcher 선행 호출 대체)
        * dispatcher `build` case: `xcode_stop` 선행 호출 제거 → `xcode_build` 단독
        * dispatcher `build-deploy` case: `xcode_stop` 선행 호출 제거 → `xcode_build` → `deploy` → `run_app`
    - pairApp(Issue41)와 동일 설계 — 차이점은 pairApp이 inline AppleScript 중복을 가지고 있어 본 이슈 수렴 형태가 양 레포 최종 표준이 됨
* 구현 명세:
    - DRY 원칙: stop AppleScript는 `xcode_stop()` 한 곳에만 존재
    - `xcode_stop`은 외부 `/run stop` 서브커맨드 + `xcode_build` 내부 호출 양쪽에서 공유
    - `pkill -f xcodebuild` 재도입 절대 금지 (2026-04-18 수정 합의 유지)
    - 상단 주석에 workspace document 한정 stop 설계 의도 명시 (pkill 전역 종료 금지 사유 포함)
* 검증:
    - [x] `/run` (build-deploy) REST 3016 정상 응답 (status=ok, version=1.0.0, uptime=6s)
    - [x] `/run kill` → fWarrangeCli만 종료 (post-kill REST 3016 응답 없음 확인)
    - [x] `bash cli/_tool/fwc-run-xcode.sh stop` 단독 실행 → xcodeproj 로드 상태에서 정상 종료 (open_project idempotent)
    - [ ] `bash cli/_tool/fwc-test.sh` 전체 통과 (별도 세션 필요, 시간 소요)

## Issue32: run.sh 완전 제거 + fwc- 접두어 네이밍 전환 (등록: 2026-04-18) (✅ 완료, 9d48324) ✅
* 목적: Issue31 후속 정리 — `run.sh` 래퍼를 완전히 제거하고 pairApp(fSnippetCli #25) 패턴과 동일한 `fwc-` 접두어 네이밍으로 통일
* 배경: Issue31은 제목("run.sh 스크립트 제거")과 구현("래퍼로 교체")이 불일치한 상태로 완료됨. pairApp은 이미 `run.sh`를 완전 제거하고 `fsc-config.sh`/`fsc-run-xcode.sh`/`fsc-test.sh` 3개로 분리함. 본 이슈는 동일 패턴을 fWarrangeCli에 적용
* 상세:
    - Rename: `cli/_tool/config.sh` → `fwc-config.sh`, `run-xcode.sh` → `fwc-run-xcode.sh`
    - 신규: `cli/_tool/fwc-test.sh` — 기존 `run.sh` full 모드(All Clear Test 8단계) 로직 이관
    - 삭제: `cli/_tool/run.sh`, `cli/_tool/run.sh_old`
    - 삭제: `.claude/commands/run.md` — 커맨드 자체 제거 (사용자가 `fwc-run-xcode.sh`, `fwc-test.sh` 직접 호출)
    - 참조 수정: `cli/_tool/cmdTestDo.sh:81`, `apiTestDo.sh:81` Pre-flight → `fwc-run-xcode.sh build-deploy`
    - SCAR 수정(로컬, gitignore 대상): `.claude/agents/build.md`, `.claude/skills/dev/SKILL.md` Debug 빌드 섹션
* 검증:
    - [x] `bash cli/_tool/fwc-run-xcode.sh build-deploy` 빌드 + 배포 + 실행 성공 (REST API status=ok, uptime 확인)
    - [ ] `bash cli/_tool/fwc-test.sh` All Clear Test 통과 (별도 세션, 시간 소요)
    - [ ] `bash cli/_tool/apiTestDo.sh --run all` Pre-flight 정상 동작 (별도 세션)

## Issue31: run.sh 스크립트 제거 후 Xcode 기반 빌드 단일화 (등록: 2026-04-18) (✅ 완료, 6872be0) ✅
* 목적: 현재 스크립트 기반 빌드의 TCC 문제 해결, Xcode 기반 빌드로 단일화 — 자동화는 유지하되 빌드 프로세스만 AppleScript 기반으로 제어
* 상세:
    - **문제**: `xcodebuild` 기반 빌드·배포 후 앱 **실행 시점에** TCC(Transparency, Consent, and Control) 권한 재요청 발생 (Accessibility 추정, 근본 원인 진단은 별도 이슈 예정)
    - **원인 가설**: Xcode GUI 빌드와 CLI 빌드의 권한 컨텍스트(서명 identifier·배포 경로·TCC 캐시) 차이
    - **목표**: Xcode GUI를 AppleScript로 제어하여 빌드 수행 → TCC 문제 제거 + 자동 배포 유지
    - **범위**: fWarrangeCli만 적용. pairApp(fWarrange)·fSnippetCli(#25)는 별도 이슈로 분리 (본 이슈 완료 후 동기화 예정)
* 실무 방침 (POC 중 확인된 AppleScript 제약 반영):
    - **Debug 빌드 + Applications 배포 + 실행**: `run-xcode.sh` 필수 (TCC 이슈 지점)
    - **Release 빌드 + Applications 배포** (`/deploy`, `/brew-apply`): xcodebuild 유지 — Xcode AppleScript scheme class에 `configuration` 속성 없음 → 동적 전환 불가. Release 경로 TCC 재현 여부는 **별도 이슈로 분리**
    - **빌드만 (`/build`, `/verify`)**: xcodebuild 유지 (실행 없음 → TCC 무관)
    - **`xcodebuild -showBuildSettings`**: 유지 (메타 조회, TCC 무관)
* 실제 수정 대상 파일:
    - Script (신규): `cli/_tool/run-xcode.sh`, `cli/_tool/config.sh`
    - Script (교체): `cli/_tool/run.sh` (기존은 `run.sh_old`로 보존)
    - Command: `.claude/commands/run.md`
    - Agent: `.claude/agents/build.md` (Debug 빌드 섹션)
    - Skill: `.claude/skills/dev/SKILL.md` (Debug 빌드 섹션)
    - Settings: `.claude/settings.local.json` (`Bash(osascript:*)`, `Bash(open:*)` 추가)
    - Config: `.gitignore` (`_tool/.last_build_path` 추가)
* 유지 파일 (xcodebuild Release/메타 조회 — TCC 무관):
    - Command: `build.md`, `deploy.md`, `verify.md`, `refactor.md`, `issue-fix.md`, `brew-apply.md`
    - Agent: `build-doctor.md`, `verify.md`, `deployment.md`, `refactor.md`
    - Rule: `coding-rules.md`, `deploy-rules.md`, `path-rules.md`
* 구현 명세:
    - **Step 0: 프로젝트 사전 오픈** (AppleScript 오류 예방)
        * Xcode 미실행·프로젝트 미오픈 상태에서 `tell application "Xcode" to ...` 호출 시 AppleScript 오류 발생
        * CLI: `open -a Xcode cli/fWarrangeCli.xcodeproj` (또는 AppleScript `tell application "Xcode" to open POSIX file "..."`)
        * 이미 열려 있으면 idempotent — 중복 오픈 없이 통과
        * Xcode 실행·프로젝트 로드 완료까지 polling 대기 (`osascript -e 'application "Xcode" is running'` 등)
    - Step 1: Xcode 빌드 제어
        * 기존 빌드 중단: `osascript -e 'tell application "Xcode" to stop'` + `pkill -f xcodebuild` (보조)
        * 빌드 시작: `build workspace document` (AppleScript)
        * 빌드 완료 대기: `scheme action result.completed` 폴링, `status`/`error message` 판정
        * **제약 (수용)**: 외부에서 소스 파일을 수정한 직후 Xcode가 "Revert/Keep Xcode Version" 다이얼로그를 띄우면 AppleScript가 `-1728 (Can't get scheme action result id)` 에러로 실패. 사용자가 Xcode 창에서 수동으로 "Revert" 클릭 후 재실행하면 정상 동작 (스크립트에서 안내 메시지 출력)
    - Step 2: 빌드 완료 후 자동 배포
        * 빌드 경로 동적 계산 (또는 `_tool/.last_build_path` 캐시)
        * 바이너리 타임스탬프 비교로 변경 감지
        * `/Applications/_nowage_app/fWarrangeCli.app`으로 복사
    - Step 3: `/run run-only` 최적화
        * `/Applications/_nowage_app` 앱과 `$BUILD_DIR` 앱의 바이너리 MD5/타임스탬프 비교
        * 동일하면 바로 실행, 다르면 재배포 후 실행
    - Step 4: 설정 추상화 (다중 프로젝트 확장 대비)
        * `_tool/config.sh`: 프로젝트명, Bundle ID, Scheme, 배포 경로, `.xcodeproj` 경로 정의
        * `_tool/run-xcode.sh` (신규): 공용 로직 (사전 오픈 → 빌드 → 배포 → 캐싱)
        * `.gitignore` 추가: `_tool/.last_build_path`
    - Step 5: 대상 파일 업데이트 (실무 방침에 따라 축소)
        * Debug 빌드 SCAR (`agents/build.md`, `skills/dev/SKILL.md`): Debug 빌드 섹션을 `run-xcode.sh` 경로로 안내 추가
        * `settings.local.json`: `Bash(osascript:*)`, `Bash(open:*)` 추가 (`Bash(xcodebuild:*)` 유지 — Release/메타 조회 용도)
        * Release 빌드 SCAR는 수정 없음 (TCC 무관, 또는 별도 이슈로 분리)
* 검증:
    - [x] Xcode 실행 중 상태에서 `run-xcode.sh build-deploy` 실행 → 빌드 + 배포 성공 (2026-04-18 POC)
    - [x] `/run` 실행 후 앱 기동 시 TCC 재요청 없음 (2026-04-18 실측 — 설계 유효)
    - [x] 기존 `_tool/run.sh` 이동 확인(`_tool/run.sh_old`)
    - [x] Debug 빌드 SCAR (`agents/build.md`, `skills/dev/SKILL.md`)에 `run-xcode.sh` 안내 반영
    - [x] `settings.local.json`에 `Bash(osascript:*)` 권한 추가 (`xcodebuild`·`open`은 기존 허용)
    - [x] `run-xcode.sh build` 재검증 → `[build] ✅ 빌드 성공` + REST API `status: ok`
    - [ ] Xcode 미실행 상태에서 `/run` 실행 → 자동 프로젝트 오픈 → 빌드 + 배포 성공 (향후 실사용 중 검증)
    - [ ] `/run full` 실행 → All Clear Test 통과 (테스트 인프라 소요 시간 때문에 별도 세션)
    - [ ] Release 빌드 경로(`/deploy`, `/brew-apply`) TCC 재현 여부는 별도 이슈로 분리 등록
* 구현 명세:
    - **신규**: `cli/_tool/run-xcode.sh` (171 lines) — Xcode GUI를 AppleScript로 제어하는 빌드·배포·실행 스크립트. 명령: `open/stop/build/build-deploy/deploy-run/run-only/kill`
    - **신규**: `cli/_tool/config.sh` — 프로젝트 변수 분리 (fSnippetCli 동기화 시 값만 교체)
    - **교체**: `cli/_tool/run.sh` — 기존 파일을 `run.sh_old`로 보존하고, `run-xcode.sh`를 래핑하는 진입점으로 재작성. `full` 모드(9단계 All Clear Test)는 기존 로직 유지하되 "빌드·배포·실행" 단계를 `bash run-xcode.sh build-deploy` 한 줄로 축약
    - **수정**: `.gitignore` — `cli/_tool/.last_build_path` 캐시 제외
    - **수정**: `.claude/commands/run.md` — `run.sh` 래퍼 구조 설명 + Xcode Revert 다이얼로그 대응 안내 추가
    - **수정**: `.claude/agents/build.md` — Debug 빌드 섹션을 `run-xcode.sh` 경로로 전환 (Release는 xcodebuild 유지)
    - **수정**: `.claude/skills/dev/SKILL.md` — 빌드 명령 예시를 `run-xcode.sh` + xcodebuild 병행 표기
    - **수정**: `.claude/settings.local.json` — `Bash(osascript:*)` 권한 추가
    - **핵심 기술**:
        * 사전 오픈: `loaded of workspace document` 폴링 (idempotent)
        * 빌드 완료 감지: `scheme action result.completed` 루프 + `status` 판정
        * Revert 다이얼로그 충돌: `-1728 (Can't get scheme action result id)` 에러 시 사용자 안내
        * mtime 비교: `date -r file +%s` 사용 (GNU stat 간섭 회피)
    - **제약** (추후 개선 과제):
        * AppleScript `scheme` class는 `name`/`id`만 노출 → Configuration(Debug/Release) 동적 전환 불가
        * Release 빌드 경로는 xcodebuild CLI 유지 (별도 이슈로 분리)

## Issue30: paidApp_version.md 설계 문서 정합성 개선 (등록: 2026-04-18) (✅ 완료, 0713f46) ✅
* 목적: `cli/_doc_design/paidApp_version.md` 설계 문서를 실제 `AppState.swift` 구현 및 프로젝트 규칙과 일치하도록 정비
* 관련 파일: `cli/_doc_design/paidApp_version.md`, `cli/fWarrangeCli/AppState.swift`
* 연계 이슈: paidApp `Issue191` (paidApp 측 참조 링크 정비)
* 상세:
    - `isPaidAppRunning` 섹션(문서 L189-196)이 실제 `AppState.swift`에 구현되어 있지 않음 — "향후 활용 가능"만 기재되어 오해 소지
    - `observePaidAppTermination` 예제 코드(L120-132)가 실제 구현(`[weak self]` + `Task { @MainActor in ... }`, L437-454)과 달리 단순화됨
    - Free 기능 테이블 마지막 행(L29-30 "화면 이동"/"자동 실행 관리")의 셀 폭이 다른 행들과 불일치 — `md-rules.md` Table 정렬 규칙 위반
    - API 엔드포인트 표기(L24, L26)가 `/api/v1`만 언급 — 현재 v1/v2 공존 구조(`.claude/rules/api-rules.md`) 미반영
    - Issue9/10/11 상태 기록(L216-220)이 현재 Issue.md와 동기화되어 있는지 재확인 필요
* 구현 명세:
    - `isPaidAppRunning` 섹션: 미구현 상태 명시("현재 미구현, 필요 시 추가") 또는 섹션 제거
    - `observePaidAppTermination` 예제: 실제 구현 그대로 반영하거나 "의사 코드" 명시
    - Free 기능 테이블: 모든 행을 열 최대 너비로 재정렬
    - API 표기: "v1 (v2에서도 제공)" 또는 "v1/v2 공존" 형태로 보강
    - 이슈 상태 표: 현재 Issue.md와 재동기화 (Issue9/10/11 최종 상태 확인)

## Issue29: /run full All Clear Test 통합 테스트 파이프라인 (등록: 2026-04-17, 해결: 2026-04-17, commit: 77fabbd) ✅
* 목적: project 25의 /run full 패턴을 참고하여 fWarrangeCli의 빌드→배포→_config.yml 기본값 검증→API/CMD 전체 테스트→로그 검사를 자동화하는 통합 테스트 파이프라인 구현
* 상세:
    - `cli/_tool/run.sh`에 `full` 모드 추가 (10단계 자동 검증)
    - Step 0: 프로세스 종료 → Step 1: _config.yml 백업 & 삭제 → Step 2: Debug 빌드 & 배포 → Step 3: 앱 실행 → Step 4: REST API 헬스 체크 (10초 대기) → Step 5: _config.yml 기본값 검증 (19개 필드 + excludedApps + 단축키) → Step 6: API 테스트 all (v1+v2, 62개) → Step 7: CMD 테스트 all (v1+v2, 62개) → Step 8: 로그 ERROR/CRITICAL 검사 → Step 9: _config.yml 복원 & 재시작
    - `.claude/commands/run.md` 문서에 full 옵션 추가
    - 검증: ALL CLEAR 6 PASS / 0 FAIL

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
* task: `cli/_doc_work/tasks/start-nPTiR_task.md`
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

* 목적: `paidApp_version.md` 설계 문서 기준으로 불필요한 Paid 관련 코드 정리
* 구현 명세:
    - `paidApp_version.md`: 관련 소스 파일 테이블에서 실제 미존재 함수 `isPaidAppRunning` 참조 삭제
    - Swift 소스에는 삭제 대상 없음 (모든 함수가 실제 사용 중)
    - 번들ID `kr.finfra.*` 단독 표준 확인 (레거시 prefix는 폐기, 2026-04-19 재확인)
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
## Issue35: brew services 자동 시작 — Formula service 블록 + /deploy brew autostart 서브커맨드 (등록: 2026-04-19)
* 목적: `/deploy brew local`로 설치된 `fWarrangeCli.app`을 **`brew services`(launchd LaunchAgent)** 경로로 사용자 로그인 시 자동 기동하도록 Formula `service do` 블록 + 배포 CLI 통합 구현
* 관계: **Issue34의 선수 이슈** — `brew local` 완료 후 자동 시작 흐름이 완성되려면 본 이슈 구현 필요
* 배경:
    - `brew install`만으로는 앱이 기동되지 않음 — 로그인 후 매번 수동 `open` 필요 → 헬퍼 데몬 성격과 맞지 않음
    - fWarrangeCli는 REST 서버(port 3016) + Accessibility API(창 캡처/복구) 기반 **헬퍼 데몬** — GUI 세션 전용 기능(CGEventTap 등) 없음 → `brew services`(launchd LaunchAgent) 경로 적합 가능성
    - Homebrew 관행상 `service do` 블록 + `brew services start <formula>`가 표준 자동 시작 수단
    - **심링크 엔트리 포인트 활용**: Issue34에서 확립한 `/Applications/_nowage_app/fWarrangeCli.app` 심링크는 Cellar 경로 교체와 무관하게 유지됨. `brew services`의 `run` 경로로 `opt_prefix` 사용 시 동일한 안정성 확보 (opt_prefix도 Cellar 경로를 심링크로 가리킴)
* 표준 채택 (2026-04-19 설계 번복):
    - SSOT(`homebrew_tap_deploy.md §7-5`)가 **`brew services` 단일 표준**으로 번복 (2026-04-19)
    - pairApp(fSnippetCli #25) Issue44가 선행 채택한 Login Item 방식은 **obsolete 처리**됨 — pairApp도 후속 이슈에서 `brew services`로 이관 예정
    - 본 이슈(Issue35)는 **표준 구현 사례**로 먼저 완성. Login Item 대안/fallback 고려는 제거 (obsolete 규칙)
    - Accessibility API는 daemon에서도 동작 가능 (LaunchAgent + `LSUIElement=YES` + `.accessory` 정책). TCC 재요청 발생 시 `/run tcc` 사용
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5 "자동 시작 등록" (확장 필요)
    - Homebrew 공식 `service do` 블록 패턴
    - `launchctl` LaunchAgent 원리: `~/Library/LaunchAgents/homebrew.mxcl.<formula>.plist` 자동 생성·로드
    - 로그인 시 자동 기동: LaunchAgent의 `RunAtLoad` + `KeepAlive`
* 구현 명세:
    - **Formula `service do` 블록** (`cli/_tool/fwc-deploy-brew.sh` cmd_local의 임시 Formula 생성부):
        ```ruby
        service do
          run [opt_prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli"]
          keep_alive true
          log_path var/"log/fwarrange-cli.log"
          error_log_path var/"log/fwarrange-cli.err.log"
        end
        ```
    - `fwc-deploy-brew.sh` `cmd_local` Step 통합:
        - Step 8 (신규): `brew services start fwarrange-cli` — 환경변수 `FWC_AUTOSTART=1` 또는 `/deploy brew local --autostart` 옵션 지정 시 자동 수행
        - 기본값은 **안내만 출력** (사용자 실수 방지 — 암묵적 시스템 변경 금지 원칙)
        - 옵트인 원칙 (암묵적 시스템 변경 금지 — SSOT §7-5-C)
    - `fwc-deploy-brew.sh` `cmd_uninstall` 통합: `brew services stop fwarrange-cli` 자동 호출 (등록된 경우만) — 이미 구현됨
    - `fwc-deploy-brew.sh` `cmd_status` 통합: `brew services info fwarrange-cli` 섹션 추가
    - 신규 서브커맨드 `/deploy brew autostart`:
        - `enable`: `brew services start fwarrange-cli`
        - `disable`: `brew services stop fwarrange-cli`
        - `status`: `brew services info fwarrange-cli`
    - `cli/Formula/fWarrangeCli.rb` (원본, 원격 배포용)에도 `service do` 블록 추가 (Phase B publish 시 동일 구조 유지)
* 설계 원칙:
    - **`brew services`(LaunchAgent)** 단일 표준 — Login Item/SMAppService/수동 등록과 **동시 사용 금지** (중복 기동)
    - SMAppService는 서명된 Release·App Store 배포본 전용 (Homebrew 배포본은 `brew services`)
    - LaunchAgent 등록 실패 시 `brew services info`로 진단, `~/Library/LaunchAgents/homebrew.mxcl.fwarrange-cli.plist` 검증
    - TCC 재요청: daemon 프로세스로 전환 시 Accessibility 권한이 사용자 앱 세션 권한과 별도로 관리될 수 있음 → `/run tcc` 안내 병행
* Phase 구분:
    - Phase A (Formula service 블록 + 수동 start/stop): 🚧 착수 예정
        * Formula에 `service do` 추가
        * `fwc-deploy-brew.sh` autostart 서브커맨드 신설
        * 수동 `brew services start/stop/info` 래퍼
    - Phase B (opt-in 자동 통합 + 검증): 미착수
        * `FWC_AUTOSTART=1` 환경변수 또는 `--autostart` 플래그
        * 실측: 로그아웃 → 재로그인 시 자동 기동 + REST 3016 응답 + Accessibility 동작 확인
        * TCC 재요청 발생 여부 기록
* 검증:
    - [ ] `brew services list` 에 `fwarrange-cli` 항목 표시 (`brew local` 후)
    - [ ] `brew services start fwarrange-cli` → `~/Library/LaunchAgents/homebrew.mxcl.fwarrange-cli.plist` 자동 생성
    - [ ] `brew services info fwarrange-cli` → `Running: ✔`, PID 표시
    - [ ] 로그아웃 → 재로그인 시 자동 기동 + REST 3016 응답 + 메뉴바 아이콘 표시
    - [ ] Accessibility(창 캡처/복구) 동작 확인 — TCC 재요청 없거나 1회만
    - [ ] `brew services stop fwarrange-cli` → LaunchAgent unload
    - [ ] `/deploy brew uninstall` → `brew services stop` 선행 호출 확인
    - [ ] `/deploy brew status` → `brew services` 섹션 노출
    - [ ] `brew services` 실패 시 진단 경로 문서화 (plist 검증, 권한 안내) — Login Item fallback은 **obsolete**
* 관련 파일:
    - `cli/_tool/fwc-deploy-brew.sh` (cmd_local Formula 생성부 + autostart 서브커맨드 신설)
    - `cli/Formula/fWarrangeCli.rb` (원본, `service do` 블록 추가)
    - `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5-A "`brew services` 경로" — 표준 규칙 SSOT
    - 연계: pairApp `fSnippet/_public` Issue44 (과거 Login Item 채택, **2026-04-19 obsolete** — 후속 이슈에서 `brew services` 이관 예정)

## Issue34: /deploy brew 서브커맨드 확장 (local/publish/status/uninstall + TCC 안내, pairApp 패턴 수렴) (등록: 2026-04-19)
* 목적: `/deploy brew` 단독 호출 금지, 4개 서브커맨드로 분기하고 brew 재설치 후 TCC 권한 꼬임 가능성을 `/run tcc` 안내로 유도. pairApp(fSnippetCli #25 Issue43) 패턴과 수렴하여 원격 tap repo 생성 전/후 모두 단일 커맨드로 운용
* 선수: **Issue35 (brew services 자동 시작)** — `brew local` 완료 후 사용자 로그인 시 자동 기동 흐름이 완성되려면 Issue35 구현 필요. 2026-04-19 SSOT 설계 번복 이후 `brew services`가 양 프로젝트 단일 표준 (pairApp Issue44 Login Item 방식은 obsolete)
* 배경:
    - 현재 `/deploy`는 로컬 복사만 수행 — 원격 tap 반영/상태 조회/정리 기능이 섞여 있지 않아 확장성 부족
    - brew 재설치 후 새 서명 바이너리로 TCC Accessibility 권한이 꼬일 가능성 (Release 서명 분리, Issue31 실무 방침 참조)
    - `fwc-run-xcode.sh tcc` 서브커맨드로 `tccutil reset Accessibility kr.finfra.fWarrangeCli` 자동화 완료 (사용자 별도 수정)
    - pairApp(#25)은 이미 `fsc-deploy-debug.sh` + `fsc-deploy-brew.sh` 라우터 분리 아키텍처로 정착 → Issue34에서 동일 패턴 적용
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7 "내부 배포 CLI 커맨드 설계 원칙" SSOT
    - §7-1 표준 서브커맨드 셋 (local/publish/status/uninstall 4종)
    - §7-2 단독 호출 차단 규칙 (암시적 기본값 불가, 🚫 이모지 + 사유 명시)
    - §7-3 로컬 재설치 권장 절차 (9-step, 양 프로젝트 공통)
    - §7-4 공통 산출물 경로 규약 (tap/Formula/심링크/tarball)
    - §7-5 TCC 재설정 (`/run tcc` 연동)
    - §7-6 체크리스트 (양 프로젝트 수렴 지표)
    - 자동화: `dawidd6/action-homebrew-bump-formula` GitHub Action (Phase B 구현 시)
* 서브커맨드 스펙:

    | 서브커맨드                | 동작                                                                                        | 상태        |
    | :------------------------ | :------------------------------------------------------------------------------------------ | :---------- |
    | `/deploy brew local`      | Release 빌드 + 로컬 tap(`finfra/tap`) 재설치 + 심링크 + 앱 실행 (9단계)                     | ✅ Phase A   |
    | `/deploy brew publish`    | 원격 `finfra/homebrew-tap` 저장소 생성/푸시, 태그 기반 Formula 업데이트                     | 🚧 Phase B  |
    | `/deploy brew status`     | brew list, brew --prefix, 로컬/원격 tap, 심링크, 프로세스·REST 상태 조회                    | ✅ Phase A   |
    | `/deploy brew uninstall`  | brew uninstall + 심링크 + 로컬 tap Formula + tarball 정리                                   | ✅ Phase A   |
* Phase A (local/status/uninstall + Usage 강제, pairApp 수렴): ✅ 구현 완료 (`7a582c2`, `ddc56c1`)
    - 신규: `cli/_tool/fwc-deploy-debug.sh` — `/deploy debug` 및 Debug 배포용 유틸
    - 신규: `cli/_tool/fwc-deploy-brew.sh` — `brew` 서브커맨드 라우터 (case dispatcher)
    - `.claude/commands/deploy.md` 얇은 디스패처로 재작성 (type/sub 이중 파싱, 4 type: debug/release/brew/dmg)
    - `§7-6` 체크리스트 9/9 항목 일치 (단독 호출 차단, 4종 구현, 🚫 이모지, LOCAL_VERSION, PIPESTATUS, REST 10초 대기, /run tcc 안내, 공통 경로 규약)
    - **양 프로젝트 공통 — 심링크 전략**: `/Applications/_nowage_app/fWarrangeCli.app` → `$(brew --prefix fwarrange-cli)/fWarrangeCli.app`. pairApp(fSnippetCli #25)도 **Issue44에서 동일 채택** — 사유는 **Cellar 경로 stale 문제 회피**(brew reinstall 시 `1.0.0/_0/` → `1.0.0/_1/` 식으로 바뀌어 `open` 실패). 안정적 엔트리 포인트 확보 목적. fWarrangeCli는 본 전략을 먼저 도입했고 pairApp이 역채택
    - **우리 고유 유지**: status에서 원격 tap 등록 체크 (`publish` 준비 가시성)
* Phase B (publish 구현): 🚧 미착수
    - GitHub 태그 + Release 자동 생성 (`gh release create cli-v<ver> --generate-notes`)
    - `cli/Formula/fWarrangeCli.rb` 원격용 Formula 복원 (GitHub Release URL + SHA256, `version`)
    - 원격 `finfra/homebrew-tap` 레포 푸시 스크립트
    - 사전 조건:
        * 원격 `github.com/finfra/homebrew-tap` public repo 생성
        * `gh` CLI 인증 (`gh auth login`)
        * `HOMEBREW_TAP_TOKEN` (tap 레포 write 권한 fine-grained PAT)
    - 자동화 옵션: `dawidd6/action-homebrew-bump-formula@v4` GitHub Action (태그 push 시 자동 bump)
* 구현 명세:
    - Phase A만 먼저 완료·검증·커밋 (단계 분리, pairApp Issue43 패턴 동일)
    - Phase B는 별도 커밋으로 진행
    - TCC 안내는 로그·출력에 한국어로 표시, `/run tcc` 커맨드를 해결책으로 제시
    - 원본 `cli/Formula/fWarrangeCli.rb`는 GitHub URL 유지 (Phase B에서 실사용), 로컬 재설치는 `$TAP_FORMULA` 로컬 tap 내부 Formula만 갱신 (원본 오염 방지)
    - 심링크 갱신: `brew local` Step 7에서 `ln -sfn`, `brew uninstall`에서 `rm -rf`
* 검증:
    - [x] `/deploy brew` 단독 → Usage 출력 + exit 1 (경량 검증 확인)
    - [x] `/deploy brew status` → brew/tap/심링크/프로세스/REST 한눈에 조회 (실측 확인)
    - [x] `/deploy brew publish` → 🚧 TODO 메시지 + 향후 구현 가이드 링크 (실측 확인)
    - [ ] `/deploy brew local` → 9단계 실측 (Release 빌드 + brew install + 심링크 + REST 헬스) — 별도 세션 (수 분 소요)
    - [ ] `/deploy brew uninstall` → brew uninstall + 심링크 + Formula + tarball 정리 — local 완료 후 검증
    - [x] 문서에 `/run tcc` 안내 명시 확인 (deploy.md + fwc-deploy-brew.sh `tcc_notice()`)
* 관련 파일:
    - `cli/_tool/fwc-deploy-debug.sh` (신규, Debug 배포)
    - `cli/_tool/fwc-deploy-brew.sh` (신규, brew 서브커맨드 라우터)
    - `.claude/commands/deploy.md` (얇은 디스패처, type/sub 이중 파싱)
    - 참고: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7 SSOT
    - 연계: pairApp `fSnippet/_public` Issue43 (동일 패턴 선행 구현)

# 📜 참고
