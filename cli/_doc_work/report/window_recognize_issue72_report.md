---
name: window_recognize_issue72_report
description: Issue72 창 인식률 개선 — 7-Phase 통합 작업 완료 보고서
date: 2026-05-16
issue: Issue72
plan: cli/_doc_work/plan/window_recognize_plan.md
task: cli/_doc_work/tasks/window_recognize_task.md
design: cli/_doc_arch/window_recognize.md
---

# 요약

Issue72 "창 인식률 개선" 7-Phase 작업의 cliApp 측 구현 완료 보고. 2026-05-15 ~ 2026-05-16 양일간 18개 커밋, 7개 서브 이슈(Issue72_1~Issue72_7) 모두 처리.

* 코드 작업: ✅ 7개 Phase 모두 완료
* 베이스라인 데이터 수집: ⏳ 2026-05-22까지 진행 (Phase 1 통계 인프라 기반)
* paidApp UI: ⏳ 별도 레포 후속 (Phase 7-2)

# Phase별 결과

## Phase 1 — 측정 인프라 (Issue72_1)

* **커밋**: `02d2bd0`
* **산출물**: `RestoreStats` 모델, `JSONRestoreStatsCollector` actor, `GET/DELETE /api/v2/restore-stats`
* **영속**: `~/Library/Application Support/fWarrangeCli/restore-stats.json` (즉시 write, kill 대응)
* **검증**: 54건 누적 + 재시작 보존 + DELETE 사이클
* **베이스라인 수집**: 2026-05-22 후 `window_recognize_baseline.md` 별도 보고서 작성 예정

## Phase 2 — 데이터 수집 확장 (Issue72_2)

* **커밋**: `1899014`
* **산출물**: `WindowInfo.windowOrder`, `displayUUID` 옵셔널 필드 + 캡처 통합
* **API**: `CGDisplayCreateUUIDFromDisplayID` (공개), Cocoa↔Quartz 좌표 변환
* **검증**: 4-monitor 환경 UUID 4종 일관, 다중 창 windowOrder 순차 (Code 0~8, KakaoTalk 0~8, iTerm2 0~5)
* **알려진 한계**: Chrome PID 분기로 windowOrder=[0,0] (Phase 6에서 정리 토대)

## Phase 3 — 타이틀 정규화 (Issue72_3)

* **커밋**: `a776be1`
* **산출물**: `TitleNormalizer` 서비스 (DispatchQueue concurrent + barrier), 빌트인 10개 룰
* **빌트인 룰**: Safari, Chrome, Edge, Firefox, Code, Cursor, Slack, iTerm2, Terminal, Xcode
* **REST**: `GET/PUT/DELETE /api/v2/normalize-rules`
* **사용자 편집본**: `~/Library/Application Support/fWarrangeCli/title_normalize.yml`
* **검증**: VSCode 13창 정규화 실측 (`⚓ fWarrange — Issue.md` → `⚓ fWarrange`)
* **효과 정량**: Phase 1 베이스라인 후 exactTitle(90점) 비율 +20% 목표

## Phase 4 — 점수 함수 개선 (Issue72_4)

* **커밋**: `c4162f6`
* **산출물**: distance 0~9점 가산 (카테고리 경계 보존), `AppSettings.matchAreaMatchEnabled` 옵션
* **알고리즘**: `score > 0 && score < 100` 가드, `bonus = max(0, 9 - Int(distance/100))`
* **검증**: 빌드 + GET `/settings/restore` 노출 + 56창 회귀 없음
* **이슈후보**: 탭별 PATCH Bool false 영속화 버그 (별도 후속)

## Phase 5 — 매칭 모드 + Moom 폴백 (Issue72_5)

* **커밋**: `48df335`
* **산출물**: `MatchMode` enum + `RuntimeMatchPolicy` struct, `dryRun` 매칭 분기, Moom 폴백
* **모드 정의**:
    - strict: ≥70, 기하 폴백·1:N·Moom 차단
    - normal: 사용자 설정, 기하·area 활성
    - loose: ≥30, 1:N 매칭, Moom 폴백 (앱별 창 수 일치 + windowOrder 정렬 배분)
* **REST**: `POST /layouts/{name}/restore`에 `mode` 파라미터
* **WindowInfo.matchMode**: 개별 창 단위 override
* **검증**: 3 모드 e2e 각 57/57, MatchType 분포 ID 388 / Title(Exact) 1 / Width 1 / None 4

## Phase 6 — Spaces + PWA (Issue72_6)

* **커밋**: `dc0f36f`
* **산출물**:
    - Spaces: 비공개 `CGSCopySpacesForWindows` API + `spaceId` 캡처/매칭 +3점
    - PWA: Chromium 5종 화이트리스트 + `ps -p {pid} -o command=` → `--app=URL` 파싱
* **WindowInfo.spaceId, originURL** 옵셔널 필드 추가
* **결정사항**: cliApp 비공개 API 도입 합의 (Issue.md 기록, paid_cli_protocol.md 차기 갱신 시 반영)
* **검증**: 56창 spaceId=1 일관, PWA 추출 코드 빌드 통과
* **한계**: Space 2개 분산·PWA 실측 환경 확보 후 e2e. `appMatches` 다중 식별자 매칭은 후속

## Phase 7-1 — Interactive REST (Issue72_7)

* **커밋**: `1d4246d`
* **산출물**: `dryRun` protocol 인자 + 3개 호출부 가드, `interactive`/`dryRun` 동의어 파싱
* **REST**: `POST /layouts/{name}/restore` body `interactive: true` → 매칭만 시뮬, 적용·Moom·재시도 스킵
* **응답**: `success=false`, `matchedTitle="(dry-run) {원본}"`, score·matchType 정상
* **검증**: dry-run 56창(succeeded=0) vs 실제 56/56
* **후속**: MatchCandidate·InteractiveSession·`/resolve` 엔드포인트 → paidApp UI 설계 시
* **paidApp 다이얼로그(Phase 7-2)**: 별도 레포 작업

# 누적 영향

## 코드 변경

| 분류 | 신규 | 수정 |
| :--- | :--- | :--- |
| 모델 (Models/) | `RestoreStats.swift`, `MatchMode.swift` | `WindowInfo.swift`, `AppSettings.swift`, `AppSettings+Patch.swift` |
| 서비스 (Services/) | `RestoreStatsCollector.swift`, `TitleNormalizer.swift` | `WindowCaptureService.swift`, `WindowRestoreService.swift`, `LayoutStorageService.swift`, `RESTServer.swift`, `SettingsService.swift` |
| 유틸 (Utils/) | — | `AXPrivateAPI.swift` (CGS* 3종 추가) |
| AppState | — | `AppState.swift` (DI 통합) |
| Manager | — | `WindowManager.swift` (mode·dryRun 인자) |
| 테스트 (apiTest/v2/) | `33`, `34`, `35`, `36`, `37`, `38` 신규 6개 | — |
| API 문서 | — | `openapi_v2.yaml`, `RestAPI_v2.md` §4.8~§4.11 |

## REST API 추가

| 메서드 | 경로 | 용도 |
| :--- | :--- | :--- |
| GET | `/api/v2/restore-stats` | 매칭 통계 스냅샷 |
| DELETE | `/api/v2/restore-stats` | 통계 리셋 (베이스라인 재시작) |
| GET | `/api/v2/normalize-rules` | 정규화 룰셋 |
| PUT | `/api/v2/normalize-rules` | 룰셋 교체 |
| DELETE | `/api/v2/normalize-rules` | 빌트인 리셋 |
| (확장) | `POST /api/v2/layouts/{name}/restore` | `mode`, `interactive`/`dryRun` 파라미터 |

## YAML 스키마 확장 (WindowInfo)

옵셔널 필드 신규 6개 — 모두 구 yml 하위호환:
* `windowOrder: Int?` (Phase 2)
* `displayUUID: String?` (Phase 2)
* `windowRaw: String?` (Phase 3, 정규화 전 원본)
* `matchMode: MatchMode?` (Phase 5, 창 단위 override)
* `spaceId: Int?` (Phase 6-1)
* `originURL: String?` (Phase 6-2, PWA)

# 알고리즘 변화

## 매칭 점수 합산 흐름 (normal 모드 기준)

```
1. computeMatchScore(target, axWindow, policy):
   a. axTitle = normalizer.normalize(rawAxTitle)        # Phase 3
   b. 카테고리 점수 결정 (100/90/80/70/60/50/40/30)      # Phase 1·5(기하 가드)
   c. distance 가산: 0~9점 (score < 100)                # Phase 4
   d. spaceId 일치 시 +3                                # Phase 6-1
   → 최종 score (상한 99)

2. findOptimalMatches:
   - score DESC, distance ASC, cgWindowId ASC 정렬
   - 전역 탐욕 할당
   - loose 모드: 1:N 매칭 허용

3. 잔여 처리:
   - 매칭 실패 → noMatch
   - loose 모드 + 모든 매칭 실패 시 Moom 폴백          # Phase 5
     (앱별 창 수 == target 수 → windowOrder 정렬 배분)

4. 통계 push (RestoreStatsCollector)                    # Phase 1
```

## 매칭 모드별 정책

| 항목 | strict | normal | loose |
| :--- | :---: | :---: | :---: |
| minimumScore | 70 | 설정값 | 30 |
| 기하 폴백 (60~30) | ❌ | ✅ | ✅ |
| areaMatch (30) | ❌ | 설정값 | ✅ |
| 1:N 매칭 | ❌ | ❌ | ✅ |
| Moom 폴백 | ❌ | ❌ | ✅ |

# 커밋 이력

| 커밋 | 날짜 | 내용 |
| :--- | :--- | :--- |
| `917f2a1` | 2026-05-15 | Issue72 등록 + plan/task/design 산출물 |
| `02d2bd0` | 2026-05-15 | Phase 1 코드 — RestoreStats 인프라 |
| `8f09955` | 2026-05-15 | Phase 1 Save Point |
| `ff8811d` | 2026-05-15 | Phase 1 진행현황 + 베이스라인 검토일 |
| `1899014` | 2026-05-15 | Phase 2 코드 — windowOrder + displayUUID |
| `4b67e9d` | 2026-05-15 | Phase 2 마킹 |
| `a776be1` | 2026-05-15 | Phase 3 코드 — TitleNormalizer + REST CRUD |
| `f5f8159` | 2026-05-15 | Phase 3 마킹 |
| `c4162f6` | 2026-05-15 | Phase 4 코드 — distance 가산 + area 옵션 |
| `83cdadf` | 2026-05-15 | Phase 4 마킹 + 후속 이슈후보 |
| `8547d06` | 2026-05-16 | Save Point WIP |
| `623c18b` | 2026-05-16 | `_doc_design` → `_doc_arch` 리팩토링 (외부 이슈) |
| `48df335` | 2026-05-16 | Phase 5 코드 — MatchMode + Moom 폴백 |
| `4650842` | 2026-05-16 | Phase 5 마킹 |
| `dc0f36f` | 2026-05-16 | Phase 6 코드 — Spaces + PWA |
| `1eab541` | 2026-05-16 | Phase 6 마킹 |
| `1d4246d` | 2026-05-16 | Phase 7-1 코드 — dry-run |
| `376647a` | 2026-05-16 | Phase 7-1 마킹 |

총 18개 커밋 (Issue72 직접 16개 + Save Point 1개 + 리팩토링 1개).

# 후속 작업

## 즉시 후속 (1주일 이내)

* **Task 1.6 베이스라인 수집** (2026-05-22): `window_recognize_baseline.md` 작성
    - 1주일 실사용 데이터 → MatchType 분포, 평균 score, Top 10 실패 패턴
    - Phase 3 정규화 효과 정량 비교
    - Phase 4 areaMatch 비활성 결정 데이터

## 환경 확보 시 후속

* **Space 2개 분산 e2e**: Phase 6-1 spaceId 매칭 검증
* **Chrome PWA 실측**: Phase 6-2 originURL 추출 검증
* **strict/loose 모드 동적 환경 검증**: 정규화 깨진 타이틀 + 모드별 거동 차이

## 별도 레포 (paidApp)

* **Phase 7-2 paidApp 다이얼로그**: SwiftUI 후보 카드 + `CGWindowListCreateImage` 썸네일 + 다국어
* **`/resolve` 엔드포인트**: paidApp UI 설계와 동시 도입
* **`MatchCandidate`·`InteractiveSession` 토큰 관리**: 동

## 후속 이슈후보 (등록됨)

* `/api/v2/settings/{tab}` 탭별 PATCH Bool false 영속화 버그 (Phase 4 발견)
    - 전체 `/settings` PATCH는 정상
    - tabPaths filter 또는 NSNumber/Bool 변환 추적 필요

## 매칭 활용 확장 (베이스라인 후)

* PWA originURL 다중 식별자 매칭 — Phase 6-2 후속
* 모드별 통계 분리 집계 — Phase 1 collector 확장
* Phase 7 학습 (선택) — 매칭 자동화가 충분하면 불필요

# 정량 목표 추적

| 지표 | 베이스라인 (Phase 1) | 목표 (Phase 3 후) | 목표 (Phase 5 후) | 측정 시점 |
| :--- | :--- | :--- | :--- | :--- |
| 전체 매칭 성공률 | 수집 중 | +15% | +25% | 2026-05-22 |
| exactTitle(90) 비율 | 수집 중 | +20% | +20% | 2026-05-22 |
| areaMatch(30) 비율 (오탐 의심) | 수집 중 | -50% | -90% | 2026-05-22 |
| 매칭 실패율 | 수집 중 | -10% | -20% | 2026-05-22 |

베이스라인 1주일 수집 후 비교 보고서 (`window_recognize_baseline.md`)로 정량 검증.

# 참고

* design SSOT: [`cli/_doc_arch/window_recognize.md`](../../_doc_arch/window_recognize.md)
* plan: [`cli/_doc_work/plan/window_recognize_plan.md`](../plan/window_recognize_plan.md)
* task: [`cli/_doc_work/tasks/window_recognize_task.md`](../tasks/window_recognize_task.md)
* RestAPI SSOT: [`cli/_doc_arch/RestAPI_v2.md`](../../_doc_arch/RestAPI_v2.md) §4.8~§4.11
* openapi: [`api/openapi_v2.yaml`](../../../api/openapi_v2.yaml)
