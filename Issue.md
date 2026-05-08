---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 71
* Save Point: 2026-04-27 (close Issue55/57/56 — API v2 문서 정합성 감사)
  - c47bbcd (2026-05-05) - Docs: Close Issue70
  - 1a375a1 (2026-05-04) - Feat(MenuBar): Issue69 — paidApp 동작 시 About/Open Main Window 분기


# 🤔 결정사항
* _doc_design/paid_cli_protocol.md 기준 진행(paidApp앱과 연동)
* _doc_design/menuBar_enhance.md 기준 진행(메뉴바)

# 🌱 이슈후보
1. 정밀하게 복구 않되는데 원인이 아이디 방식때문인지 윈도우명 때문인지 확인, 혹은 이중 메칭문제인지?


# 🚧 진행중
## Issue71: [Fix] VSCode 등 CGWindowOwnerName ↔ localizedName 불일치 앱 복구 실패 (등록: 2026-05-08)
* 목적: VSCode·Code Helper 등 `kCGWindowOwnerName` 과 `NSRunningApplication.localizedName` 이 다른 앱이 복구되지 않는 문제 해결.
* 상세:
    - 현상: REST `/api/v2/layouts/{name}/restore` 호출 시 `[복구] 'Visual Studio Code' - 성공: 0, 대기: 10` → `[조기 종료] 남은 창의 앱이 모두 미실행 상태: Visual Studio Code` 로 1회 시도 만에 종료. VSCode가 명백히 실행 중인데도 매칭 실패.
    - 근본 원인 (실측):
        - `kCGWindowOwnerName` = `"Visual Studio Code"` (yml `app` 필드에 저장)
        - `NSRunningApplication.localizedName` = `"Code"` (복구 매칭 기준)
        - 매칭 로직 `name == appName || name.hasPrefix(appName) || appName.hasPrefix(name)` 가 `"Code"` ↔ `"Visual Studio Code"` 양방향 prefix를 모두 false 로 판정 → 매칭 0건
    - 영향 범위: VSCode 외에도 `bundleURL` 표시명과 `localizedName` 이 다른 모든 앱 (예: 일부 Helper, JetBrains IDE 변형 등)
    - 관련 파일:
        - `cli/fWarrangeCli/Services/WindowRestoreService.swift` (line 110, 184, 256 — 동일 매칭 로직 3개소)
        - `cli/fWarrangeCli/Services/WindowCaptureService.swift` (line 71 — `ownerName` 사용)
* 구현 명세:
    - 1단계 — 다중 식별자 매칭 헬퍼 추가 (`WindowRestoreService.swift`):
        - 비교 후보: `localizedName`, `bundleURL.deletingPathExtension().lastPathComponent` (=Visual Studio Code), `executableURL.lastPathComponent` (=Code)
        - 모든 후보에 대해 정확 일치 / 양방향 prefix 검사
        - private `appMatches(_ app: NSRunningApplication, target: String) -> Bool` 형태
    - 2단계 — 3개소 매칭 로직 헬퍼 호출로 교체:
        - 병렬 경로(line 110): `runningApps.filter { appMatches($0, target: appName) }`
        - 순차 경로(line 184): 동일
        - 조기 종료 체크(line 256): `pendingWindows.allSatisfy { target in !runningApps.contains(where: { appMatches($0, target: target.app) }) }`
    - 3단계 — 검증:
        - VSCode 창 포함 레이아웃 캡처 → 이동 → 복구 시 `[복구] 'Visual Studio Code' - 성공: N` 로그 확인
        - Xcode 같은 정상 매칭 케이스 회귀 없음 확인
        - Release 빌드 통과
    - 비목표(별도 이슈로 분리 가능): `WindowInfo` 에 `bundleIdentifier` 추가 저장 (스키마 변경 + 마이그레이션 필요 → 본 이슈 범위 외)

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료
## Issue70: [Feat] cliApp 메뉴바 종료 항목 단축키 표시 정비 + 다국어 지원 (등록: 2026-05-04) (✅ 완료, c47bbcd) ✅
* 목적: cliApp 메뉴바의 종료 항목 단축키 표시를 종료 정책(`paid_cli_protocol.md` §3.3)과 일치시키고, 메뉴 항목 다국어 지원을 추가. paidApp Cmd+Q는 paidApp 단독 종료에만 표시되어야 하며, cliApp Quit All에는 단축키 미부여(오발화 방지).
* 상세:
    - 배경:
        - paidApp Issue239(Cmd+Q로 cliApp 동반 종료) 취소 — 정책: Cmd+Q는 paidApp 단독 종료, 메뉴바 Quit All은 cliApp 메뉴 단일 진입점
        - 현재 `_doc_design/menuBar_enhance.md`의 메뉴 구조에서 `Quit ⌘Q` 표기가 단일 항목에 부여되어 있어 정책과 불일치
        - 메뉴 항목 텍스트가 영어 하드코딩으로 추정 — 다국어 미지원
    - 관련 파일:
        - `cli/fWarrangeCli/Managers/MenuBarManager.swift` (NSMenu 구성)
        - `_doc_design/menuBar_enhance.md` (SSOT 메뉴 구조 — 본 이슈에서 수정)
        - `cli/fWarrangeCli/*.lproj/Localizable.strings` 또는 `.xcstrings` (다국어 리소스)
* 구현 명세:
    - 1단계 — `_doc_design/menuBar_enhance.md` 수정:
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
    - 관련 SSOT: 상위 paidApp 레포 `_doc_design/paid_cli_protocol.md` §3.3 "Quit All 시퀀스" — cliApp 트리거 흐름 미반영
    - 관련: paidApp 레포 Issue232 (paidApp 메뉴바 제거, 2026-05-03 완료)
* 구현 명세:
    - `MenuBarManager.swift` 또는 `MenuBarView.swift` Quit 액션 핸들러에서 paidApp 종료 신호 발송
    - 옵션 A: paidApp URL Scheme `fwarrange://command?action=quit` open
    - 옵션 B: paidApp pid 검색 후 `kill -TERM`
    - 옵션 C: REST `/api/v2/paidapp/quit` 신규 엔드포인트 추가 후 paidApp이 self-terminate
    - 옵션 결정 후 paidApp 레포 SSOT `_doc_design/paid_cli_protocol.md` §3.3 갱신 필요 (양 레포 동기 PR)
    - 검증: cliApp 메뉴바 Quit → paidApp + cliApp 모두 종료, ps에서 잔존 0개 확인


> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# ⏸️ 보류

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
