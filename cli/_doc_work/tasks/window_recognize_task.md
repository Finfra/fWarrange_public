---
name: window_recognize_task
description: 창 인식률 개선 — plan의 7 Phase를 체크리스트 단위로 분해한 실행 태스크
date: 2026-05-15
issue: Issue72
plan: cli/_doc_work/plan/window_recognize_plan.md
design: cli/_doc_design/window_recognize.md
---

# 진행 현황 (Progress)

| Phase | 이슈        | 상태                                  | 커밋·메모                                                    |
| :---: | :---------- | :------------------------------------ | :----------------------------------------------------------- |
|   1   | Issue72_1   | 🟢 코드 완료 · 베이스라인 수집 대기   | 코드 `02d2bd0` · 1.6은 1주일 실사용 데이터 수집 후 보고서 작성 |
|   2   | Issue72_2   | ⚪ 대기                                | Phase 1 베이스라인 영향 無 → 선행 가능                       |
|   3   | Issue72_3   | ⚪ 대기                                |                                                              |
|   4   | Issue72_4   | ⚪ 대기                                |                                                              |
|   5   | Issue72_5   | ⚪ 대기                                | Phase 2/3/4 후 진행                                          |
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

# Phase 2 — 데이터 수집 확장 (Track A-1)

## Task 2.1: `WindowInfo` 스키마 확장

* [ ] `cli/fWarrangeCli/Models/WindowInfo.swift`에 옵셔널 필드 추가
    - `windowOrder: Int?`
    - `displayUUID: String?`
* [ ] Codable 하위호환: 옛 YAML 로드 시 `nil` 허용
* [ ] equality 비교 시 옵셔널 필드 영향 검토

## Task 2.2: `WindowCaptureService` 데이터 수집

* [ ] `CGWindowListCopyWindowInfo`의 onscreen 정렬 순서를 `windowOrder`로 기록
* [ ] `NSScreen` 또는 `CGDirectDisplayID`에서 UUID 획득 (`CGDisplayCreateUUIDFromDisplayID`)
* [ ] 멀티 디스플레이 환경에서 각 윈도우가 어느 디스플레이에 속하는지 매핑

## Task 2.3: YAML 직렬화 검증

* [ ] 신규 캡처 YAML에 두 필드 출력 확인
* [ ] 옛 YAML(필드 없음) 로드·복구 정상 동작 확인
* [ ] `apiTestDo.sh` 캡처 검증 케이스 갱신

## Task 2.4: 테스트

* [ ] 멀티 디스플레이 환경에서 displayUUID 일관성 (캡처 두 번 → 동일 UUID)
* [ ] 디스플레이 연결/해제 후 displayUUID 변화 추적
* [ ] 동일 앱 다중 창에서 windowOrder 0,1,2,... 순차

# Phase 3 — 타이틀 정규화 (C-2)

## Task 3.1: 룰셋 파일 작성

* [ ] `cli/fWarrangeCli/Resources/title_normalize.yml` 신설
* [ ] Top 10 앱 룰 작성:
    - Safari: `strip_suffix: " — Safari"`
    - Chrome: `strip_suffix: " - Google Chrome"`
    - Firefox: `strip_suffix: " — Mozilla Firefox"`
    - Code (VSCode): `strip_suffix: " — Visual Studio Code"`, `strip_prefix: "● "`
    - Cursor: `strip_suffix: " — Cursor"`, `strip_prefix: "● "`
    - Slack: `strip_pattern: " \\(\\d+\\)"`
    - iTerm2/Terminal: `mask_pattern: ".*[/\\\\].*"` (옵션)
    - Xcode: `strip_pattern: " — .*"`
    - Finder: 경로 마스킹 옵션

## Task 3.2: `TitleNormalizer` 서비스

* [ ] `cli/fWarrangeCli/Services/TitleNormalizer.swift` 신설
* [ ] 룰셋 로드·캐시 (`NSRegularExpression` 캐싱)
* [ ] `normalize(title:appName:bundleId:) -> String` 메서드
* [ ] 매칭 우선순위: bundleId 정확 일치 > appName 일치 > 디폴트
* [ ] 핫리로드 API: 룰셋 변경 시 캐시 무효화

## Task 3.3: 캡처 시 정규화 적용

* [ ] `WindowCaptureService`에서 원본 title 별도 보존 (`windowRaw` 옵셔널 필드)
* [ ] 저장 시 정규화된 `window` + 원본 `windowRaw`
* [ ] 옛 데이터 호환 (윗 필드 없으면 정규화 비활성 또는 lazy 적용)

## Task 3.4: 복구 시 정규화 적용

* [ ] `WindowRestoreService.computeMatchScore`에서 axTitle을 `TitleNormalizer.normalize()` 통과시킨 후 target.window와 비교
* [ ] target.window는 이미 정규화 상태 (Task 3.3)

## Task 3.5: REST CRUD

* [ ] `GET /api/v2/normalize-rules` — 현재 룰셋 조회
* [ ] `PUT /api/v2/normalize-rules` — 룰셋 갱신
* [ ] 갱신 시 `TitleNormalizer` 핫리로드
* [ ] `openapi_v2.yaml` + `RestAPI_v2.md` 동기화

## Task 3.6: 테스트·효과 검증

* [ ] Safari 페이지 이동 시나리오에서 exactTitle(90점) 매칭 회복
* [ ] Slack 알림 카운트 변경 시나리오 매칭 유지
* [ ] Phase 1 통계와 before/after 비교 (`exactTitle` 비율 +20% 목표)

# Phase 4 — 점수 함수 개선 (Track B)

## Task 4.1: distance 가산점 도입

* [ ] `WindowRestoreService.computeMatchScore` 반환 score에 distance 기반 0~10점 가산
* [ ] distance가 작을수록 가산점 큼 (예: `min(10, max(0, 10 - distance/100))`)
* [ ] 카테고리 점수와 합산 후 상한 100 클램프
* [ ] 동률 매칭에서 가까운 위치 선호 동작 확인

## Task 4.2: areaMatch 비활성화 옵션

* [ ] `AppSettings.matchAreaMatchEnabled: Bool` 추가 (기본값은 Phase 1 통계 보고 결정)
* [ ] `computeMatchScore`에서 옵션 비활성 시 areaMatch 분기 스킵
* [ ] `AppSettings+Patch.swift`에 PATCH 지원 추가
* [ ] `openapi_v2.yaml` settings 스키마 동기화

## Task 4.3: minimumScore 모드 연동 준비

* [ ] `minimumScore` 인터페이스 정리 — 호출부 L69, L95에서 모드 기반 주입 가능하게
* [ ] Phase 5에서 모드별 차등 적용 진입점 마련

## Task 4.4: 테스트·효과 검증

* [ ] 동률 매칭에서 가까운 창 선택되는지 단위 테스트
* [ ] areaMatch 비활성 후 통계: `.areaMatch` 비율 감소·오탐 감소 확인
* [ ] 정상 케이스(80점 이상)는 변동 없음 (회귀 없음)

# Phase 5 — 매칭 모드 + 최후 폴백 (C-3 + C-5)

## Task 5.1: `MatchMode` 모델

* [ ] `cli/fWarrangeCli/Models/MatchMode.swift` 신설
* [ ] `enum MatchMode: String, Codable { case strict, normal, loose }`
* [ ] 각 모드별 `minimumScore`, 기하 폴백 허용, 1:N 매칭, Moom 폴백 활성 여부 속성

## Task 5.2: `WindowInfo.matchMode` 옵셔널 필드

* [ ] `WindowInfo.swift`에 `matchMode: MatchMode?` 추가 (옵셔널, 기본 nil → normal 해석)
* [ ] YAML 직렬화 검증

## Task 5.3: `WindowRestoreService` 모드 분기

* [ ] strict 모드: score ≥ 80 만 허용, areaMatch·widthMatch·heightMatch·ratioMatch 차단
* [ ] normal 모드: 현재 동작 (Phase 4 결과)
* [ ] loose 모드: minimumScore 30 유지 + 1:N 매칭 허용 + Moom 폴백 활성

## Task 5.4: Moom 스타일 폴백 구현

* [ ] 모든 후보 점수가 minimumScore 미만일 때 폴백 트리거
* [ ] `(app, windowCount)` 동일 시 windowOrder 정렬 순으로 위치 배분
* [ ] loose 모드 한정 활성
* [ ] 폴백 사용 시 결과에 `usedFallback: true` 표시

## Task 5.5: REST API 모드 파라미터

* [ ] `POST /api/v2/layouts/{name}/restore`에 `mode` 쿼리/바디 파라미터 추가
* [ ] 우선순위: 요청 mode > WindowInfo.matchMode > normal
* [ ] `openapi_v2.yaml` + `RestAPI_v2.md` 동기화

## Task 5.6: 테스트

* [ ] strict: 타이틀 깨진 창 매칭 거부 e2e
* [ ] normal: Phase 4 결과 동일 (회귀 없음)
* [ ] loose: 타이틀 전부 깨져도 위치 배분 성공
* [ ] 모드별 통계가 분리 집계되도록 Phase 1 collector 확장

# Phase 6 — 고급 식별자: Spaces + PWA (Track A-2)

## Phase 6-1: Spaces (spaceId)

### Task 6-1.1: 비공개 API PoC

* [ ] `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces` 등 비공개 심볼 동작 확인
* [ ] cliApp non-sandbox 환경에서 호출 가능 검증
* [ ] macOS 버전별 동작 차이 매트릭스 작성

### Task 6-1.2: paidApp protocol 합의

* [ ] 상위 `fWarrange/_doc_design/paid_cli_protocol.md`에 비공개 API 도입 합의 기록
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
* [ ] `cli/_doc_design/window_recognize.md` "결정 사항" 부록 작성
* [ ] `cli/_doc_work/report/` 각 Phase별 완료 보고서

# 참고

* plan: [`cli/_doc_work/plan/window_recognize_plan.md`](../plan/window_recognize_plan.md)
* design: [`cli/_doc_design/window_recognize.md`](../../_doc_design/window_recognize.md)
* 코드 SSOT: [`WindowRestoreService.swift`](../../fWarrangeCli/Services/WindowRestoreService.swift)
