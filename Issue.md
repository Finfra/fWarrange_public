---
name: Issue
description: fWarrangeCli 이슈 관리
date: 2026-04-07
---
# Issue Management
* Issue HWM: 72
* Save Point: 2026-05-16 (Issue72 종결 — 창 인식률 개선 7-Phase cliApp 측 완료)
  - 4be2c7a (2026-05-16) - Docs(Issue72): 창 인식률 개선 7-Phase 통합 종결 + 보고서 작성
  - 376647a (2026-05-16) - Docs(Issue72_7): Phase 7-1 cliApp PoC 완료 마킹 + task 진행현황 갱신
  - 1d4246d (2026-05-16) - Feat(Issue72_7)(Phase 7-1): interactive dry-run 매칭 시뮬레이션 (cliApp 측)
  - 1eab541 (2026-05-16) - Docs(Issue72_6): Phase 6 완료 마킹 + task 진행현황 갱신
  - dc0f36f (2026-05-16) - Feat(Issue72_6)(Phase 6): Spaces(spaceId) + PWA(originURL) 식별자 도입
  - 4650842 (2026-05-16) - Docs(Issue72_5): Phase 5 완료 마킹 + task 진행현황 갱신
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
* **Issue72_6 비공개 API 도입 합의 (2026-05-16)** — cliApp(non-sandbox)에서 CGSGetActiveSpace·CGSCopySpacesForWindows·CGSMainConnectionID 사용. App Store 영향 無 (cliApp은 brew 배포). macOS 업데이트 시 폐기 가능성 대비 nil 반환 안전망 보유. 상위 `_doc_arch/paid_cli_protocol.md` 차기 갱신 시 반영 권장.

# 🌱 이슈후보
1. `/api/v2/settings/{tab}` 탭별 PATCH가 Bool `false` 값을 디스크에 영속화하지 않는 버그 (Phase 4 발견 — `/settings` 전체 PATCH는 정상). tabPaths filter 또는 NSNumber/Bool 변환 로직 추적 필요.


# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

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

# 🚫 취소

> 종결된 이슈는 [`z_old/old_issue.md`](z_old/old_issue.md)로 이관됨.

# 📜 참고
