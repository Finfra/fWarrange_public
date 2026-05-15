---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 72
* Save Point: 2026-05-16 (Issue72_5 Phase 5 완료 — 매칭 모드 strict/normal/loose + Moom 폴백)
  - 48df335 (2026-05-16) - Feat(Issue72_5)(Phase 5): 매칭 모드 (strict/normal/loose) + Moom 스타일 폴백
  - 83cdadf (2026-05-15) - Docs(Issue72_4): Phase 4 완료 마킹 + task 진행현황 갱신 + 후속 이슈후보 등록
  - c4162f6 (2026-05-15) - Feat(Issue72_4)(Phase 4): 점수 함수 개선 — distance 가산 + areaMatch 비활성화 옵션
  - f5f8159 (2026-05-15) - Docs(Issue72_3): Phase 3 완료 마킹 + task 진행현황 갱신
  - a776be1 (2026-05-15) - Feat(Issue72_3)(Phase 3): 타이틀 정규화 룰셋 (TitleNormalizer + REST CRUD)
  - 4b67e9d (2026-05-15) - Docs(Issue72_2): Phase 2 완료 마킹 + task 진행현황 갱신
  - 1899014 (2026-05-15) - Feat(Issue72_2)(Phase 2): 데이터 수집 확장 — windowOrder + displayUUID
  - ff8811d (2026-05-15) - Docs(Issue72_1): task 진행현황 + 베이스라인 검토일 결정사항 추가
  - 8f09955 (2026-05-15) - Docs(Issue72_1): Phase 1 코드 완료 마킹 + Save Point 갱신
  - 02d2bd0 (2026-05-15) - Feat(Issue72_1)(Phase 1): 창 복구 매칭 누적 통계 인프라
  - 917f2a1 (2026-05-15) - Docs(Issue72): 창 인식률 개선 — 7-Phase 통합 작업 등록
  - 7b41337 (2026-05-08) - Fix(Restore): Issue71 — bundleId 우선 매칭으로 ownerName↔localizedName 불일치 앱 복구
  - c47bbcd (2026-05-05) - Docs: Close Issue70
  - 1a375a1 (2026-05-04) - Feat(MenuBar): Issue69 — paidApp 동작 시 About/Open Main Window 분기


# 🤔 결정사항
* `~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` 기준 진행(상위 메인 레포, paidApp앱과 연동)
* `cli/_doc_arch/menuBar_enhance.md` 기준 진행(메뉴바, 로컬 SSOT — gitignored)
* **Issue72_1 베이스라인 검토일: 2026-05-22** — 통계 인프라 가동 후 1주일(2026-05-15~22) 실사용 데이터 수집 → `cli/_doc_work/report/window_recognize_baseline.md` 보고서 작성 → Issue72_1 ✅ 완료 처리 → Phase 2~7 우선순위 데이터 기반 재조정

# 🌱 이슈후보
1. `/api/v2/settings/{tab}` 탭별 PATCH가 Bool `false` 값을 디스크에 영속화하지 않는 버그 (Phase 4 발견 — `/settings` 전체 PATCH는 정상). tabPaths filter 또는 NSNumber/Bool 변환 로직 추적 필요.


# 🚧 진행중

## Issue72: [Feat] 창 인식률 개선 — 7-Phase 통합 작업 (등록: 2026-05-15)
* 목적: "정밀 복구 실패의 원인이 ID 방식인지 윈도우명인지 이중 매칭 문제인지" 토의(이슈후보 출신)를 시발점으로, 측정 인프라부터 사용자 개입 UI까지 7개 Phase로 매칭 알고리즘을 체계적으로 개선. 베이스라인 측정 후 정량 목표 달성(매칭 성공률 +25%, exactTitle 비율 +20%, areaMatch 오탐 -90%).
* plan: `cli/_doc_work/plan/window_recognize_plan.md`
* task: `cli/_doc_work/tasks/window_recognize_task.md`
* design: `cli/_doc_arch/window_recognize.md`
* 상세:
    - 부모 이슈로 plan/task 전체 추적
    - 서브 이슈 Issue72_1~Issue72_7은 각 Phase별 독립 진행·커밋·완료
    - Phase 1(측정 인프라) 선행 필수, Phase 2/3/4 병렬 가능, Phase 5/6/7 직렬
    - 7개 서브 이슈 모두 완료 시 부모 이슈 종결

## Issue72_1: [Feat] Phase 1 — 측정 인프라 (RestoreStats + REST + 베이스라인) (등록: 2026-05-15) (✅ 코드 완료, 02d2bd0 — 베이스라인 1주일 수집 대기 중)
* 목적: 모든 후속 Phase의 효과 검증 토대 구축. 복구 매칭 결과를 누적 통계로 노출하여 인식률을 수치화.
* 상세:
    - `RestoreStats` 모델 + `RestoreStatsCollector` 서비스 신설
    - `WindowRestoreService` 매칭 결과 push (성공·실패·MatchType 분포)
    - `~/Library/Application Support/fWarrangeCli/restore-stats.json` 디스크 영속
    - `GET /api/v2/restore-stats` REST 엔드포인트
    - `openapi_v2.yaml` + `RestAPI_v2.md` 동기화 (api-rules.md 준수)
    - `apiTestDo.sh v2` 신규 케이스 추가
    - 1주일 베이스라인 수집 → `cli/_doc_work/report/window_recognize_baseline.md`
* 구현 명세:
    - Task 1.1~1.6 (task 파일 참조)
    - 검증: 5회 복구 후 통계 정확성, 재시작 후 보존, MatchType 분포 합 = 시도 수

## Issue72_2: [Feat] Phase 2 — 데이터 수집 확장 (windowOrder + displayUUID) (등록: 2026-05-15) (✅ 완료, 1899014)
* 목적: 매칭 정확도 향상을 위해 캡처 시점에 추가 시그널 수집. 본 Phase는 수집만, 매칭 로직 변경 없음.
* 상세:
    - `WindowInfo`에 옵셔널 `windowOrder: Int?`, `displayUUID: String?` 추가
    - `WindowCaptureService`에서 두 필드 채움
    - YAML 직렬화 하위호환 (구 파일 로드 가능)
* 구현 명세:
    - Task 2.1~2.4
    - 검증: 신규 캡처에 두 필드 존재, 옛 YAML 회귀 없음, 멀티 디스플레이 UUID 일관성

## Issue72_3: [Feat] Phase 3 — 타이틀 정규화 룰셋 (C-2) (등록: 2026-05-15) (✅ 완료, a776be1)
* 목적: 동적 타이틀(브라우저·에디터·터미널·채팅)로 인한 exactTitle(90점) 매칭 실패 회복.
* 상세:
    - `title_normalize.yml` 빌트인 룰셋 (Top 10 앱: Safari, Chrome, Code, Slack 등)
    - `TitleNormalizer` 서비스 — `strip_prefix`/`strip_suffix`/`strip_pattern`/`mask_pattern` 지원
    - 캡처·복구 양쪽 동일 정규화 적용
    - `GET/PUT /api/v2/normalize-rules` REST CRUD
* 구현 명세:
    - Task 3.1~3.6
    - 검증: Phase 1 통계 대비 exactTitle 비율 +20% 이상

## Issue72_4: [Feat] Phase 4 — 점수 함수 개선 (distance 가산 + areaMatch 약화) (등록: 2026-05-15) (✅ 완료, c4162f6)
* 목적: 카테고리 점수 → distance 가산 + areaMatch 비활성화 옵션으로 노이즈 매칭 감소.
* 상세:
    - `computeMatchScore`에 distance 기반 0~10점 가산 (동률 시 가까운 위치 선호)
    - `AppSettings.matchAreaMatchEnabled: Bool` 옵션 추가
    - `minimumScore` 인터페이스 정리 (Phase 5 모드 연동 준비)
* 구현 명세:
    - Task 4.1~4.4
    - 검증: areaMatch 비활성 후 오탐 감소(통계), 정상 케이스 회귀 없음

## Issue72_5: [Feat] Phase 5 — 매칭 모드 + Moom 폴백 (strict/normal/loose) (등록: 2026-05-15) (✅ 완료, 48df335)
* 목적: 사용자가 "정확히"/"비슷하게" 의도 표현. loose 모드에서 Moom 스타일 최후 폴백 활성.
* 상세:
    - `MatchMode` enum: strict(≥80), normal(≥50, 현행), loose(≥30 + 1:N + Moom 폴백)
    - `WindowInfo.matchMode: MatchMode?` 옵셔널 필드
    - Moom 폴백: 앱별 창 개수 동일 시 windowOrder 정렬로 위치 배분
    - `POST /api/v2/layouts/{name}/restore`에 `mode` 파라미터
* 구현 명세:
    - Task 5.1~5.6
    - 검증: 3개 모드 의도 거동 e2e, normal 회귀 없음

## Issue72_6: [Feat] Phase 6 — 고급 식별자 Spaces(spaceId) + PWA(originURL) (등록: 2026-05-15)
* 목적: OSS 미개척 시나리오 대응 — Spaces 분산 창·Chrome PWA 구분 매칭.
* 상세:
    - 6-1: 비공개 `CGSGetActiveSpace` PoC + `spaceId` 캡처/매칭 (cliApp non-sandbox)
    - 6-2: Chrome `--app=` 등 PWA `originURL` 어댑터 + `appMatches` 다중 식별자 일반화
    - 상위 paidApp `paid_cli_protocol.md`에 비공개 API 도입 합의 기록
* 구현 명세:
    - Task 6-1.1~6-1.4, Task 6-2.1~6-2.4
    - 검증: Space 분산 e2e, Chrome PWA vs 일반 Chrome 구분, Issue71 회귀 없음

## Issue72_7: [Feat] Phase 7 — 사용자 개입 UI (interactive REST + paidApp 다이얼로그) (등록: 2026-05-15)
* 목적: 자동 매칭이 애매할 때 paidApp 후보 선택 다이얼로그로 사용자 개입 경로 제공.
* 상세:
    - cliApp: 애매 케이스(<50점 또는 동률 다중매치) 검출, `interactive: true` 옵션, `resolve` 엔드포인트
    - paidApp(별도 레포): 후보 카드 다이얼로그, `CGWindowListCreateImage` 썸네일, 다국어
    - 선택 결과 학습 누적 (선택 항목, 1차 미포함 가능)
* 구현 명세:
    - Task 7-1.1~7-1.3, Task 7-2.1~7-2.3, Task 7-3
    - 검증: 동일 타이틀 다중 창 사용자 선택 e2e, non-interactive 자동화 회귀 없음

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료
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

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
