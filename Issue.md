---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 69
* Save Point: 2026-04-27 (close Issue55/57/56 — API v2 문서 정합성 감사)
  - 1a375a1 (2026-05-04) - Feat(MenuBar): Issue69 — paidApp 동작 시 About/Open Main Window 분기
  - 251036a (2026-05-03) - Feat(MenuBar): Issue68 — Quit All
  - 1b9fec7 (2026-05-02) - Fix(REST): Issue67 — pause GET / 버그 수정
  - 06939f9 (2026-05-02) - Docs: Close Issue66
  - f5fa7aa (2026-05-02) - Docs: Close Issue66
  - 4e11b5d (2026-05-02) - Feat(MenuBar): Close Issue62/63/64
  - 1d9a438 (2026-05-02) - Docs: Register Issue63
  - 732348b (2026-05-02) - Chore: launchAtLogin 기본 true(Issue228) + 문서·.gitignore 정리
  - 2a219fa (2026-05-01) - Fix(CLI): Issue60 — cmdTest v2 정합화 + delete-all/quit confirm 헤더 버그 수정


# 🤔 결정사항
* _doc_design/paid_cli_protocol.md 기준 진행(paidApp앱과 연동)
* _doc_design/menuBar_enhance.md 기준 진행(메뉴바)

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료
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
