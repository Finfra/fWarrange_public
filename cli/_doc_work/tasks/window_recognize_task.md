---
name: window_recognize_task
description: 창 인식률 개선 — plan의 7 Phase를 체크리스트 단위로 분해한 실행 태스크
date: 2026-05-15
issue: Issue72
plan: cli/_doc_work/plan/window_recognize_plan.md
design: cli/_doc_arch/window_recognize.md
---

# 진행 현황 (Progress)

| Phase | 이슈        | 상태                                  | 커밋·메모                                                    |
| :---: | :---------- | :------------------------------------ | :----------------------------------------------------------- |
|   1   | Issue72_1   | 🟢 코드 완료 · 베이스라인 수집 대기   | 코드 `02d2bd0` · 1.6은 1주일 실사용 데이터 수집 후 보고서 작성 |
|   2   | Issue72_2   | 🟢 완료                                | 커밋 `1899014` · 4-monitor UUID 4종 / windowOrder 다중창 순차 검증 |
|   3   | Issue72_3   | 🟢 완료                                | 커밋 `a776be1` · 빌트인 10개 룰 / VSCode 13창 정규화 / PUT·DELETE 사이클 |
|   4   | Issue72_4   | 🟢 완료                                | 커밋 `c4162f6` · distance 0~9점 가산 / areaMatchEnabled 옵션 / 탭 PATCH Bool false 버그 후속 이슈 |
|   5   | Issue72_5   | 🟢 완료                                | 커밋 `48df335` · 3 모드 e2e 57/57 / Moom 폴백 구현 / WindowInfo.matchMode override |
|   6   | Issue72_6   | ⚪ 대기                                | Phase 5 후 진행 (paidApp protocol 합의 필요)                 |
|   7   | Issue72_7   | ⚪ 대기                                | Phase 5 후 진행 (paidApp 별도 레포 작업 포함)                |

* 🟢 진행 완료 · 🟡 진행 중 · ⚪ 대기

# 실행 원칙

* **Phase별 별도 이슈·별도 커밋** — 본 task는 7개 Phase를 한 파일에 모으되, 등록 시 Phase별 이슈로 분리 권장
* **Phase 1 선행 필수** — 측정 인프라 없이는 Phase 2~7 효과 검증 불가
* **Phase 2/3/4 병렬 가능** — 영향 영역 분리 (캡처/정규화/점수)
* **Phase 5/6/7 직렬** — Phase 5의 모드 인터페이스가 후속 진입점
* 각 Phase 종료 시 회귀 테스트 게이트 통과 후 다음 Phase 진입
    - `bash cli/_tool/fwc-deploy-debug.sh`
    - `bash cli/_tool/apiTestDo.sh v2`
    - `bash cli/_tool/cmdTestDo.sh v2`
* **api-rules 준수**: API 추가/수정 시 `openapi_v2.yaml` + `RestAPI_v2.md` + 소스코드 3자 동기화

# 공통 검증 게이트 (각 Phase 종료 시)

* [ ] `xcodebuild -scheme fWarrangeCli -configuration Debug build -quiet` 통과
* [ ] `apiTestDo.sh v2` 전체 통과
* [ ] `cmdTestDo.sh v2` 전체 통과
* [ ] 베이스라인 통계(Phase 1 이후) 대비 회귀 없음
* [ ] 커밋 메시지 형식: `Feat/Fix/Refactor({Phase}): {요약}` (Issue번호 포함)

# Phase 1 — 측정 인프라 (C-1) — 🟢 코드 완료

> **이슈**: Issue72_1 · **커밋**: `02d2bd0` (Phase 1 코드) + `8f09955` (Issue.md Save Point)
> **남은 작업**: Task 1.6 (1주일 베이스라인 수집)

## Task 1.1: `RestoreStats` 모델 ✅

* [x] `cli/fWarrangeCli/Models/RestoreStats.swift` 신설
* [x] 필드: `totalAttempts`, `successes`, `failures`, `matchTypeCounts: [String: Int]`, `successScoreSum`/`successScoreCount`(`averageScore` 파생), `recentEvents: [RestoreEvent]`, `failureKeyCounts`, `sessionStartedAt`, `lastUpdated`
* [x] `Codable` 채택, `RestoreEvent`는 `(timestamp, app, title, score, matchType, success)` (`success` 추가 — 실패 키 분류용)
* [x] 최근 이벤트 윈도우 크기 상수화 (`recentEventsCapacity = 200`, `topFailuresLimit = 10`)
* [x] `toJSONDictionary()` REST 응답 직렬화 헬퍼

## Task 1.2: `RestoreStatsCollector` 서비스 ✅

* [x] `cli/fWarrangeCli/Services/RestoreStatsCollector.swift` 신설
* [x] **actor 채택** (계획서의 `@MainActor final class @Observable`에서 변경 — async/await 친화적 + isolation 보장)
* [x] 진입점: `record(app:title:score:matchType:success:)` + `recordBatch(_ results: [WindowMatchResult])` (계획서의 `recordMatchAttempt`에서 명명 변경)
* [x] 자주 실패하는 `(app|title)` Top 10 — `RestoreStats.topFailures` 파생 지표로 구현
* [x] 디스크 영속: `~/Library/Application Support/fWarrangeCli/restore-stats.json` (env `fWarrangeCli_stats_path` 재정의 가능)
* [x] 시작 시 `load()` (AppState.initialize에서 호출), `flush()`/`reset()` 노출
* [x] **즉시 write 정책 채택** (계획서의 "앱 종료 시 flush"에서 변경 — 5초 디바운스 도입했다가 launchd kill 시 손실 위험으로 폐기. 매칭은 빈번 작업이 아니므로 record마다 즉시 write가 안전)

## Task 1.3: `WindowRestoreService` 통계 push ✅

* [x] **`WindowManager.restoreWindows` 지점에서 push** (계획서의 `WindowRestoreService` 직접 push에서 변경 — `WindowRestoreService`가 nonisolated인 반면 actor 호출은 await 필요하므로 `@MainActor WindowManager`에서 한 번에 `recordBatch` 호출이 더 깔끔)
* [x] DI로 `RestoreStatsCollector?` 옵셔널 주입 (테스트·하위호환용)
* [x] 매칭 성공·실패·MatchType 모두 push (`recordBatch`)
* [x] `AppState`에서 `JSONRestoreStatsCollector` 인스턴스 생성·주입

## Task 1.4: REST 엔드포인트 ✅

* [x] `RESTServer.swift`에 `GET /api/v2/restore-stats` 라우팅 추가
* [x] **DELETE `/api/v2/restore-stats` 추가** (계획에 없던 reset 엔드포인트 — 베이스라인 재시작용)
* [x] `RESTServerHandlers`에 `getRestoreStats`, `resetRestoreStats` async 핸들러 추가
* [x] 응답 JSON: `{status, data: {totalAttempts, successes, failures, successRate, averageScore, matchTypeCounts, topFailures[], recentEventsCount, recentEventsCapacity, sessionStartedAt, lastUpdated}}`
* [x] `openapi_v2.yaml` 동기화 (`RestoreStats` 태그 + GET/DELETE 스키마)
* [x] `RestAPI_v2.md` §4.8 신설

## Task 1.5: 테스트 ✅

* [x] `apiTest/v2/33.v2-restore-stats.sh` 신규 (GET)
* [x] `apiTest/v2/34.v2-restore-stats-reset.sh` 신규 (DELETE + 재확인)
* [x] **검증 결과**:
    - capture 54건 → restore 54건 즉시 (모두 ID 100점 매칭)
    - `totalAttempts=54, successes=54, successRate=1, averageScore=100, matchTypeCounts={"ID":54}`
    - 디스크 파일 11,409 bytes 확인
    - DELETE 후 0 → 1회 재복구 → 54 정확 누적
    - cliApp 강제 종료(`pkill -KILL`) 후 자동 재기동 — 통계 보존 (sessionStartedAt·lastUpdated 동일)
* [x] xcodebuild Debug 통과
* [x] 컴파일·런타임 회귀 없음

## Task 1.6: 베이스라인 수집 — ⚪ 진행 대기

* [ ] 1주일 실제 사용 통계 수집 (2026-05-15 ~ 2026-05-22 예정)
* [ ] `cli/_doc_work/report/window_recognize_baseline.md` 보고서 작성
* [ ] 전체 매칭 성공률, MatchType 분포, 평균 score, Top 10 실패 패턴 기록
* [ ] Issue72_1을 ✅ 완료 섹션으로 최종 이동

## Phase 1 설계 변경 사항 요약

| 항목 | 계획 (초안) | 실제 구현 | 사유 |
| :--- | :--- | :--- | :--- |
| Collector 격리 | `@MainActor final class @Observable` | `actor` | async/await 친화, isolation 안전 |
| Collector 진입점 | `recordMatchAttempt(target:result:score:matchType:)` | `record(...)` + `recordBatch(_:)` | API 명확성 (단건/일괄) |
| Push 위치 | `WindowRestoreService` 직접 | `WindowManager.restoreWindows` 종료 시 일괄 | `WindowRestoreService` nonisolated → actor 호출 비용. WindowManager는 @MainActor라 await 자연스러움 |
| 디스크 영속 정책 | 종료 시 flush + 시작 시 load | record마다 즉시 write + 시작 시 load | launchd kill·crash 데이터 손실 방지 |
| REST 메서드 | GET 만 | GET + DELETE | 베이스라인 재시작용 reset 필요 |
| `topFailures` 키 형식 | `(app, titlePattern)` 페어 | `"app|title"` 단일 문자열 (`Self.failureKey` 정규화) | JSON 직렬화 단순화, title 80자 트림 |

# Phase 2 — 데이터 수집 확장 (Track A-1) — 🟢 완료

> **이슈**: Issue72_2 · **커밋**: `1899014`

## Task 2.1: `WindowInfo` 스키마 확장 ✅

* [x] `cli/fWarrangeCli/Models/WindowInfo.swift`에 옵셔널 필드 추가
    - `windowOrder: Int?`
    - `displayUUID: String?`
* [x] Codable 하위호환: 옵셔널이므로 옛 yml 로드 시 `nil` 허용
* [x] equality 비교: Equatable이 옵셔널 자동 처리 — 영향 없음 확인

## Task 2.2: `WindowCaptureService` 데이터 수집 ✅

* [x] `CGWindowListCopyWindowInfo`의 onscreen 정렬 순서를 PID별 `windowOrder` 인덱스로 부여
* [x] `NSScreen.deviceDescription[NSScreenNumber]` → `CGDirectDisplayID` → `CGDisplayCreateUUIDFromDisplayID` → `CFUUIDCreateString`
* [x] 창 중심점이 속한 디스플레이 매핑 — Cocoa(y-up)↔Quartz(y-down) 좌표 변환 포함
* [x] 화면 밖 창은 `squaredDistance`로 가장 가까운 디스플레이에 fallback

## Task 2.3: YAML 직렬화 검증 ✅

* [x] `serializeToYAML`: 두 필드 존재 시에만 출력 (`if let order`, `if let uuid && !uuid.isEmpty`)
* [x] `parseYAML`: 두 필드 옵셔널 파싱 추가 (`windowOrder:` Int, `displayUUID:` 인용 문자열)
* [x] 신규 캡처 YAML에 두 필드 출력 확인
* [x] 옛 yml (필드 없음 — 2026-05-15-1.yml) 로드 정상: 55창 응답 `status=ok`

## Task 2.4: 테스트 ✅

* [x] 4-monitor 환경에서 캡처 → `displayUUID` **4종 일관 사용** (서로 다른 모니터 = 서로 다른 UUID)
* [x] 동일 앱 다중 창 `windowOrder` 순차 부여 검증:
    - Code: [0,1,2,3,4,5,6,7,8]
    - KakaoTalk: [0~8]
    - iTerm2: [0~5]
    - Finder: [0,1,2]
    - Microsoft Edge: [0,1,2]
* [x] xcodebuild Debug 통과
* [ ] 디스플레이 연결/해제 후 displayUUID 변화 추적 — 본 세션에서 검증 불가 (하드웨어 토폴로지 조작 필요). Phase 4·6 진행 중 자연스럽게 검증 예정

## Phase 2 알려진 한계

| 한계 | 원인 | 후속 처리 |
| :--- | :--- | :--- |
| Google Chrome: `windowOrder = [0, 0]` | Chrome이 helper 프로세스로 창을 별도 PID로 띄움 → PID별 카운터가 각각 0부터 시작 | Phase 6 PWA 다중 식별자에서 정리 |

## Phase 2 설계 변경 사항

| 항목 | 계획 | 실제 | 사유 |
| :--- | :--- | :--- | :--- |
| windowOrder 카운터 키 | "동일 앱 내" | "동일 PID 내" | Chrome PWA·헬퍼 프로세스 케이스. ownerPID는 정확하지만 ownerName으로 묶으면 다른 PID도 동일 키 — 모호. PID 기반 + Phase 6에서 다중 식별자로 보완하는 게 안전 |
| displayUUID 좌표 변환 | 명시 안 함 | Cocoa↔Quartz 변환 추가 | NSScreen.frame은 Cocoa(y-up), CGWindow bounds는 Quartz(y-down) — 비교 전 변환 필수 |
| 화면 밖 창 fallback | 명시 안 함 | squaredDistance로 최근접 디스플레이 | 멀티 디스플레이 환경에서 화면 가장자리 창이 어디에도 contains 안 될 가능성 대응 |

# Phase 3 — 타이틀 정규화 (C-2) — 🟢 완료

> **이슈**: Issue72_3 · **커밋**: `a776be1`

## Task 3.1: 룰셋 — ✅ (코드 내장 채택)

* [x] **빌트인 룰셋을 코드 내장으로 변경** (계획서의 `Resources/title_normalize.yml`에서 변경)
    - 사유: XcodeGen 리소스 번들링 복잡도 회피. 사용자 편집본은 별도 외부 경로 유지
* [x] Top 10 빌트인 룰 (`FileTitleNormalizer.builtInRules`):
    - Safari (bundleId `com.apple.Safari`): `stripPattern: " — Safari$"`
    - Chrome (`com.google.Chrome`): `stripPattern: " - Google Chrome$"`
    - Microsoft Edge (`com.microsoft.edgemac`): `stripPattern: " - Microsoft.+$"`
    - Firefox (`org.mozilla.firefox`): `stripPattern: " — Mozilla Firefox$"`
    - Code/VSCode (`com.microsoft.VSCode`): `stripPrefix: "● "`, `stripPattern: " — .+$"`
    - Cursor (`com.todesktop.230313mzl4w4u92`): 동일 패턴
    - Slack (`com.tinyspeck.slackmacgap`): `stripPattern: " \\(\\d+\\)$"`
    - iTerm2 (`com.googlecode.iterm2`): `stripPattern: " — .+$"`
    - Terminal (`com.apple.Terminal`): `stripPattern: " — .+$"`
    - Xcode (`com.apple.dt.Xcode`): `stripPattern: " — .+$"`
* [x] 사용자 편집본 위치: `~/Library/Application Support/fWarrangeCli/title_normalize.yml` (env `fWarrangeCli_normalize_path`로 재정의)

## Task 3.2: `TitleNormalizer` 서비스 ✅

* [x] `cli/fWarrangeCli/Services/TitleNormalizer.swift` 신설
* [x] `TitleNormalizeRule` 모델 (`Codable, Equatable`)
* [x] `FileTitleNormalizer` 구현체 (DispatchQueue concurrent + barrier write)
* [x] `NSRegularExpression` 캐시 (`regexCache: [String: NSRegularExpression]`)
* [x] `normalize(title:bundleId:app:) -> String` 메서드 (계획서 시그니처와 인자 순서 다름 — bundleId 우선 매칭 일관성)
* [x] 매칭 우선순위: bundleId 정확 일치 > app 정확 일치
* [x] `updateRules(_:)` 호출 시 regex 캐시 무효화 + 디스크 영속

## Task 3.3: 캡처 시 정규화 적용 ✅

* [x] `WindowInfo.windowRaw: String?` 옵셔널 필드 추가
* [x] `CGWindowCaptureService(titleNormalizer:)` DI 주입
* [x] 정규화 결과가 원본과 다를 때만 `windowRaw` 보존 (`window: 정규화값`, `windowRaw: 원본`)
* [x] LayoutStorageService에 windowRaw serialize/parse 추가 (구 yml 호환)

## Task 3.4: 복구 시 정규화 적용 ✅

* [x] `AXWindowRestoreService(titleNormalizer:)` DI 주입
* [x] `computeMatchScore`에서 axTitle을 정규화 후 target.window와 비교
* [x] target.window는 캡처 시점에 정규화된 상태 (Task 3.3)
* [x] normalizer 미주입 시 원본 비교 (Phase 1·2 호환)

## Task 3.5: REST CRUD ✅

* [x] `GET /api/v2/normalize-rules` — 룰셋 + 카운트
* [x] **`PUT /api/v2/normalize-rules`** — 룰셋 전체 교체 (rules: null 시 리셋)
* [x] **`DELETE /api/v2/normalize-rules`** — 빌트인 리셋 (계획에 없던 추가)
* [x] `updateRules` 호출 시 regex 캐시 자동 무효화 (핫리로드)
* [x] `openapi_v2.yaml`: NormalizeRules 태그 + paths 3종 + NormalizeRule 스키마
* [x] `RestAPI_v2.md` §4.9 신설

## Task 3.6: 테스트·효과 검증 ✅

* [x] `apiTest/v2/35.v2-normalize-rules.sh` (GET) 신규
* [x] `apiTest/v2/36.v2-normalize-rules-reset.sh` (DELETE) 신규
* [x] **VSCode 13창 정규화 실측 확인**:
    - 예: `⚓ fWarrange — Issue.md` → `⚓ fWarrange` (워크스페이스 부분만 유지)
    - 효과: 같은 워크스페이스 내 다른 파일 열어도 exactTitle(90점) 매칭 가능
* [x] PUT 1개 룰 → 사용자 편집본 디스크 작성 (42 bytes) → DELETE → 파일 삭제·빌트인 10개 복원
* [x] xcodebuild Debug 통과
* [ ] **Phase 1 통계 before/after 비교** — 베이스라인 1주일 수집 후 검증 (Task 1.6 의존)

## Phase 3 설계 변경 사항

| 항목 | 계획 | 실제 | 사유 |
| :--- | :--- | :--- | :--- |
| 빌트인 룰셋 위치 | `Resources/title_normalize.yml` | 코드 내장 (`FileTitleNormalizer.builtInRules`) | XcodeGen 리소스 번들링 복잡도. 사용자 편집본 경로는 외부 유지 |
| 정규화 진입점 시그니처 | `normalize(title:appName:bundleId:)` | `normalize(title:bundleId:app:)` | bundleId 매칭 우선이므로 인자 순서도 우선순위 반영 |
| REST 메서드 | GET + PUT | GET + PUT + **DELETE** | DELETE = 빌트인 리셋 — UX 단순화 |
| Concurrency | 명시 안 함 | DispatchQueue concurrent + barrier write | nonisolated computeMatchScore에서 호출 필요 → actor 대신 큐 |
| stripPattern 형태 | suffix/prefix 별도 | regex 통합 `" — Safari$"` 등 | 더 유연. 빌트인은 거의 모두 정규식으로 통일 |

# Phase 4 — 점수 함수 개선 (Track B) — 🟢 완료

> **이슈**: Issue72_4 · **커밋**: `c4162f6`

## Task 4.1: distance 가산점 도입 ✅

* [x] `WindowRestoreService.computeMatchScore` 반환 score에 distance 기반 0~9점 가산
* [x] 가산 공식: `max(0, 9 - Int(distance / 100))` (거리 0px→+9, 900px+→0)
* [x] **카테고리 경계 보존**: score>0 && score<100 케이스만 가산 (windowID 100·noMatch 0 제외)
    - 예: exactTitle 90 + 9 = 99 < 100=ID — 카테고리 우선순위 유지
* [x] 동률 매칭에서 가까운 위치 우선 — 코드 분기 완료 (즉시 복구 시나리오에서 거리 0이라 효과 가시화는 베이스라인 후)

## Task 4.2: areaMatch 비활성화 옵션 ✅

* [x] `AppSettings.matchAreaMatchEnabled: Bool?` 추가 (기본 true)
* [x] `AXWindowRestoreService(titleNormalizer:areaMatchEnabled:)` DI 주입
* [x] `computeMatchScore`의 areaMatch(30) 분기에 `areaMatchEnabled` 가드 추가
* [x] `AppSettings+Patch`: `fullSettingsDict` + `applySettingsPatch` Bool 캐스팅
* [x] `SettingsService.save/load` yml 직렬화·역직렬화 추가
* [x] `RESTServer.tabPaths /settings/restore` fields 배열에 추가
* [x] GET 응답에 노출 확인 (`/settings/restore` → `matchAreaMatchEnabled: true`)
* [ ] **알려진 한계**: tab별 PATCH에서 Bool `false` 값이 디스크 영속화 안 됨 → 이슈후보 등록 (별도 추적)

## Task 4.3: minimumScore 모드 연동 준비 ✅

* [x] `restoreWindows(minimumScore:)` 시그니처 그대로 유지 — Phase 5에서 모드별 값을 외부에서 주입 가능
* [x] AppState에서 settings.matchAreaMatchEnabled를 init 시점에 주입 — Phase 5 mode 선택 시 동일 패턴으로 확장 가능

## Task 4.4: 테스트·효과 검증 ✅

* [x] xcodebuild Debug 통과
* [x] GET `/settings/restore`에 `matchAreaMatchEnabled` 노출 확인
* [x] 즉시 캡처+복구 55건 회귀 없음 (ID 100점 매칭 유지)
* [ ] **distance 가산 효과 통계 비교** — 베이스라인(Task 1.6) 후 측정
* [ ] **areaMatch 비활성 시 오탐 감소 통계** — 베이스라인 후 측정

## Phase 4 알려진 한계 / 설계 변경 사항

| 항목 | 계획 | 실제 | 사유 |
| :--- | :--- | :--- | :--- |
| distance 가산 범위 | 0~10점 | 0~9점 | 가산 후 100 미만 보장 (windowID 경계) |
| 가산 적용 조건 | `score > 0` | `score > 0 && score < 100` | windowID(100)에 가산 후 99로 떨어지면 ID 매칭이 약화됨 — 100은 제외 |
| 탭별 PATCH Bool false 버그 | — | 후속 이슈 분리 | tabPaths filter 또는 NSNumber/Bool 변환 추적 필요. Phase 4 핵심 가치(코드 분기)는 정상 동작 |

# Phase 5 — 매칭 모드 + 최후 폴백 (C-3 + C-5) — 🟢 완료

> **이슈**: Issue72_5 · **커밋**: `48df335`

## Task 5.1: `MatchMode` 모델 ✅

* [x] `cli/fWarrangeCli/Models/MatchMode.swift` 신설
* [x] `enum MatchMode: String, Codable, CaseIterable, Sendable { case strict, normal, loose }`
* [x] `MatchMode.parse(_:)` 옵셔널 String → enum (대소문자 무시, 잘못된 값 → .normal)
* [x] **`RuntimeMatchPolicy` 구조체 신설** (계획서엔 enum 속성으로 표현 — 실제는 별도 struct로 분리해 정책 빌더 패턴 적용)
    - `minimumScore`, `geometricFallbackEnabled`, `areaMatchEnabled`, `allowMultipleAssignments`, `moomFallbackEnabled`
    - `RuntimeMatchPolicy.from(mode:settingsMinimumScore:areaMatchSettingEnabled:)` 팩토리

## Task 5.2: `WindowInfo.matchMode` 옵셔널 필드 ✅

* [x] `WindowInfo.swift`에 `matchMode: MatchMode?` 추가 (옵셔널, 기본 nil → 호출 시점 모드 사용)
* [x] LayoutStorageService serialize/parse 양방향 호환 (matchMode 명시된 창만 출력)
* [x] **창 단위 override 의미**: 호출 시점 mode + 개별 WindowInfo.matchMode가 normal이 아니면 그 창 한정 override

## Task 5.3: `WindowRestoreService` 모드 분기 ✅

* [x] strict (minimumScore=70): containsTitle 이상만 허용, 기하 폴백 차단(geometricFallbackEnabled=false, areaMatchEnabled=false)
* [x] normal: 현재 동작 + Phase 4 distance 가산. settings의 minimumMatchScore + matchAreaMatchEnabled 반영
* [x] loose (minimumScore=30): 1:N 매칭(allowMultipleAssignments) + Moom 폴백 활성
* [x] **시그니처 변경**: protocol method에 `mode: MatchMode` 추가 + 모든 호출처 갱신 (WindowManager + AppState 2곳 + RESTServer)
* [x] computeMatchScore(target:axWindow:policy:) — policy 가드로 기하 분기 비활성
* [x] findOptimalMatches(... policy:) — 1:N 매칭 분기

## Task 5.4: Moom 스타일 폴백 구현 ✅

* [x] 모든 매칭 시도 후 pendingWindows 잔여 + `moomFallbackEnabled` 활성 시 트리거
* [x] 앱별 그룹핑 → 실행 중 앱 매칭 → AX 창 수집
* [x] **앱별 창 개수 == target 개수** 일 때만 배분 (개수 불일치 스킵)
* [x] target은 windowOrder 오름차순 정렬 → AX 창은 onscreen 순서로 배분
* [x] 결과에 `matchedTitle: "(moom-fallback)"` 표시 (계획의 `usedFallback: true` 대신)
* [x] loose 모드 전용 — strict/normal에선 비활성

## Task 5.5: REST API 모드 파라미터 ✅

* [x] `POST /api/v2/layouts/{name}/restore` body의 `mode` 필드 파싱 (`MatchMode.parse`)
* [x] 우선순위: **요청 mode → 호출 시점 정책으로 변환** → 각 창의 WindowInfo.matchMode가 normal이 아니면 그 창 한정 override
* [x] `openapi_v2.yaml`: MatchMode 태그 + RestoreRequest.mode 스키마 + enum
* [x] `RestAPI_v2.md` §4.10 신설

## Task 5.6: 테스트 ✅

* [x] `apiTest/v2/37.v2-restore-modes.sh` 신규 (3 모드 일괄 검증)
* [x] **3 모드 e2e 검증 (4-monitor 56창 캡처 → 즉시 복구)**:
    - strict: 57/57 매칭 (즉시 복구라 ID 100점 매칭만 성공 — strict가 기하 차단해도 ID 매칭은 통과)
    - normal: 57/57 (회귀 없음)
    - loose: 57/57 (1:N·Moom 폴백 트리거 없음 — 모두 정상 매칭)
* [x] **MatchType 분포 검증** (3 모드 누적 통계): ID 388 / Title(Exact) 1 / Width 1 / None 4
    - 다양한 분기 도달 확인
    - 정규화(Phase 3) 효과로 Title(Exact) 매칭 1건 발생
    - Width 매칭 1건은 기하 폴백 도달
    - None 4건은 Moom 폴백 직전 noMatch (실패 케이스 — 후속 폴백 검증 필요)
* [ ] **모드별 통계 분리 집계** — Phase 1 collector 확장 미적용 (후속 작업)
* [x] xcodebuild Debug 통과
* [x] 모드별 의도 거동 — 즉시 복구 시나리오로는 차이 가시화 어려움. 베이스라인(Task 1.6) 후 동적 환경에서 추가 검증

## Phase 5 설계 변경 사항

| 항목 | 계획 | 실제 | 사유 |
| :--- | :--- | :--- | :--- |
| 모드 속성 표현 | enum case별 속성 | `RuntimeMatchPolicy` 별도 struct + `from()` 팩토리 | 정책 빌더 패턴, AppSettings 의존성 주입 용이 |
| strict minimumScore | ≥80 | ≥70 (containsTitle 포함) | exactTitle만 허용은 과도. containsTitle도 식별자 신뢰 가능 |
| normal minimumScore | 50 | 사용자 설정값 (`settings.minimumMatchScore`, 기본 30) | 기본값 변경은 회귀 위험. Phase 4와 일관 |
| Moom 폴백 표시 | `usedFallback: true` 필드 | `matchedTitle: "(moom-fallback)"` 텍스트 | WindowMatchResult 스키마 변경 회피 |
| 모드별 통계 분리 집계 | 포함 | 후속 작업으로 분리 | collector 확장 범위 큼. Phase 5 핵심은 매칭 로직 |
| 우선순위 | 요청 mode > WindowInfo.matchMode > normal | 요청 mode → policy → 창별 matchMode가 normal이 아닐 때만 override | 더 명확한 의도. normal로 override = 의도 없음 |

# Phase 6 — 고급 식별자: Spaces + PWA (Track A-2)

## Phase 6-1: Spaces (spaceId)

### Task 6-1.1: 비공개 API PoC

* [ ] `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces` 등 비공개 심볼 동작 확인
* [ ] cliApp non-sandbox 환경에서 호출 가능 검증
* [ ] macOS 버전별 동작 차이 매트릭스 작성

### Task 6-1.2: paidApp protocol 합의

* [ ] 상위 `fWarrange/_doc_arch/paid_cli_protocol.md`에 비공개 API 도입 합의 기록
* [ ] App Store 영향 없음(cliApp non-sandbox) 명시
* [ ] 폐기 가능성 대비 fallback 명시

### Task 6-1.3: 모델·캡처·매칭 통합

* [ ] `WindowInfo.spaceId: Int?` 옵셔널 추가
* [ ] `WindowCaptureService`에서 spaceId 기록
* [ ] `WindowRestoreService`: spaceId 일치 시 가산점 (예: +5점), 비공개 API 실패 시 nil로 통과

### Task 6-1.4: 테스트

* [ ] Space 2개에 분산된 동일 앱 창 캡처·복구 e2e
* [ ] 풀스크린 창 캡처·복구
* [ ] spaceId 필드 누락(옛 데이터)에서 회귀 없음

## Phase 6-2: PWA (originURL)

### Task 6-2.1: 앱별 어댑터 설계

* [ ] Chrome: `--app=` 명령행 인자 파싱 (`ps -p {pid} -o command`)
* [ ] Edge: 동일 구조
* [ ] Safari PWA: AX 속성 또는 별도 식별
* [ ] 어댑터 인터페이스 정의 (`OriginURLExtractor` 프로토콜)

### Task 6-2.2: 모델·캡처

* [ ] `WindowInfo.originURL: String?` 옵셔널 추가
* [ ] `WindowCaptureService`에서 어댑터 호출, 실패 시 nil

### Task 6-2.3: `appMatches` 다중 식별자 확장

* [ ] 기존 `appMatches(_:targetApp:targetBundleId:)`를 `appMatches(_:target:)` 일반화
* [ ] 매칭 우선순위: bundleId + originURL > bundleId > localizedName > ownerName
* [ ] Issue71 회귀 없음 검증

### Task 6-2.4: 테스트

* [ ] Chrome PWA(WhatsApp Web 등) vs 일반 Chrome 창 구분 복구
* [ ] originURL 누락 시 일반 Chrome 매칭으로 폴백
* [ ] Issue71 시나리오(VSCode 등) 회귀 없음

# Phase 7 — 사용자 개입 UI (C-4)

## Phase 7-1: cliApp 측

### Task 7-1.1: 애매 매칭 검출

* [ ] 매칭 score < 50 또는 동률 다중 매치 케이스 검출 로직
* [ ] 후보 리스트 데이터 구조: `MatchCandidate { axElement, title, score, matchType }`

### Task 7-1.2: interactive REST API

* [ ] `POST /api/v2/layouts/{name}/restore`에 `interactive: true` 옵션
* [ ] interactive 모드에서 애매 케이스를 즉시 적용하지 않고 응답에 후보 포함
* [ ] `POST /api/v2/layouts/{name}/restore/resolve` — 사용자 선택 결과 수신·적용
* [ ] non-interactive (기본): 자동 매칭 (자동화 안정성)
* [ ] paidApp 미실행 시 normal 모드 fallback

### Task 7-1.3: openapi·문서 동기화

* [ ] `openapi_v2.yaml` interactive 옵션·resolve 엔드포인트 추가
* [ ] `RestAPI_v2.md` 5.x 섹션 갱신

## Phase 7-2: paidApp 측 (별도 레포 작업)

### Task 7-2.1: cliApp 응답 수신·렌더링

* [ ] `RESTCLIClient`에 interactive 모드 응답 파싱
* [ ] candidates 포함 시 다이얼로그 표시 진입

### Task 7-2.2: 후보 선택 다이얼로그

* [ ] SwiftUI 다이얼로그: 후보 N개 카드 표시
* [ ] 후보별 썸네일 (`CGWindowListCreateImage`로 미리보기)
* [ ] 선택 → `RESTCLIClient.resolveMatch(layoutName:targetIdx:windowIdx:)` 호출

### Task 7-2.3: 다국어·접근성

* [ ] `Localizable.xcstrings` 키 추가
* [ ] VoiceOver 라벨

## Phase 7-3: 학습 (선택, 1차 미포함 가능)

* [ ] cliApp 측: `(app, normalizedTitle, 선택) → 가중치` 매핑 누적
* [ ] 다음 복구 시 같은 패턴 자동 매칭 (학습된 결과로 score 가산)
* [ ] 학습 데이터 초기화 REST API

## Phase 7 테스트

* [ ] 동일 타이틀 다중 창 시나리오에서 사용자 선택 후 정확 복구
* [ ] non-interactive 자동화 시나리오 회귀 없음
* [ ] paidApp 미실행 e2e (다이얼로그 띄울 수 없음 → 자동 매칭 fallback)

# 완료 기준 (전체)

* [ ] 7개 Phase 모두 완료
* [ ] Phase 1 베이스라인 vs Phase 5 종료 시점 측정 지표 비교
    - 전체 매칭 성공률 +25% 이상
    - exactTitle(90) 비율 +20% 이상
    - areaMatch(30) 비율 -90% 이상
    - 매칭 실패율 -20% 이상
* [ ] 회귀 테스트 0건
* [ ] `cli/_doc_arch/window_recognize.md` "결정 사항" 부록 작성
* [ ] `cli/_doc_work/report/` 각 Phase별 완료 보고서

# 참고

* plan: [`cli/_doc_work/plan/window_recognize_plan.md`](../plan/window_recognize_plan.md)
* design: [`cli/_doc_arch/window_recognize.md`](../../_doc_arch/window_recognize.md)
* 코드 SSOT: [`WindowRestoreService.swift`](../../fWarrangeCli/Services/WindowRestoreService.swift)
