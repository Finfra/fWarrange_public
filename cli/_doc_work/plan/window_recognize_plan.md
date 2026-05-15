---
name: window_recognize_plan
description: 창 인식률 개선 — 측정 인프라부터 사용자 개입 UI까지 7단계 Phase 실행 계획
date: 2026-05-15
issue: Issue72
design: cli/_doc_design/window_recognize.md
task: cli/_doc_work/tasks/window_recognize_task.md
---

# 배경 및 목표

## 배경

* 현재 매칭 알고리즘은 카테고리 점수(100/90/80/.../30) 선택형으로, 한 가지 강한 신호로 결정되어 다른 신호가 무시됨
* CGWindowID(100점)는 세션 휘발성으로 실전 복구 시 거의 항상 폴백 — 사실상 타이틀(90점) 이하가 기본선
* 동적 타이틀(브라우저·에디터·터미널·채팅), 멀티 디스플레이 변경, Spaces, PWA 등 인식률 저하 케이스 다수 존재
* 측정 지표가 없어 어떤 변경이 효과 있는지 검증 불가

## 목표

1. **측정 가능한 인식률 기반 구축** — 모든 후속 작업의 효과 검증 토대
2. **흔한 실패 케이스 우선 해결** — 동적 타이틀(정규화), 멀티 창(windowOrder), 멀티 디스플레이(displayUUID)
3. **사용자 의도 표현 수단 제공** — strict/normal/loose 모드
4. **고급 시나리오 대응** — Spaces(Q3), PWA(Q2) 차별점 확보
5. **자동화 한계 도달 시 사용자 개입 경로** — paidApp 후보 선택 UI

## 비목표 (Out of Scope)

* 실시간 추적(Swindler 스타일) — 우리는 시점 간 매칭
* 윈도우 이미지 스냅샷 해시 — 비용 대비 효과 불명, 본 plan에서 제외
* yabai 스타일 정적 타일링 룰 — 동적 매칭과 다른 문제 영역

# 영향 범위

| 영역                   | 파일                                                                                                                                                                                    |
| :--------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 매칭 코어              | [`cli/fWarrangeCli/Services/WindowRestoreService.swift`](../../fWarrangeCli/Services/WindowRestoreService.swift), [`Models/MatchType.swift`](../../fWarrangeCli/Models/MatchType.swift) |
| 캡처                   | [`cli/fWarrangeCli/Services/WindowCaptureService.swift`](../../fWarrangeCli/Services/WindowCaptureService.swift)                                                                        |
| 데이터 모델            | [`cli/fWarrangeCli/Models/WindowInfo.swift`](../../fWarrangeCli/Models/WindowInfo.swift)                                                                                                |
| REST API               | [`cli/fWarrangeCli/Services/RESTServer.swift`](../../fWarrangeCli/Services/RESTServer.swift), [`cli/api/openapi_v2.yaml`](../../api/openapi_v2.yaml)                                    |
| 스토리지               | [`cli/fWarrangeCli/Services/LayoutStorageService.swift`](../../fWarrangeCli/Services/LayoutStorageService.swift)                                                                        |
| 정규화 룰셋            | (신규) `cli/fWarrangeCli/Resources/title_normalize.yml`                                                                                                                                 |
| API 문서               | [`cli/_doc_design/RestAPI_v2.md`](../../_doc_design/RestAPI_v2.md)                                                                                                                      |
| paidApp UI (별도 레포) | `fWarrange/fWarrange/Views/...` (Phase 7 한정)                                                                                                                                          |

# 전제조건

* cliApp이 빌드·실행 가능 상태 (`fwc-deploy-debug.sh` 통과)
* `apiTestDo.sh v2` 전체 통과 (베이스라인 회귀 방지)
* paidApp 측 `paid_cli_protocol.md` 변경이 필요한 항목은 Phase 시작 전 상위 레포 합의

# Phase 1 — 측정 인프라 (C-1, 선결조건)

## 목표

현재 인식률을 수치로 노출하여 이후 Phase의 효과 검증 토대 마련.

## 산출물

* `GET /api/v2/restore-stats` REST 엔드포인트 (cliApp)
* 복구 1회당 누적 로그 → 메모리 누적 + 디스크 영속 (`~/Library/Application Support/fWarrangeCli/restore-stats.json`)
* 메트릭: 전체 target 수, 성공 수, 실패 수, MatchType 분포, 평균 score, 자주 실패하는 `(app, titlePattern)` Top 10

## 작업 단계

1. `RestoreStats` 모델 신설 — `Codable`, 누적 카운터 + 최근 N개 이벤트 윈도우
2. `WindowRestoreService` 매칭 결과를 `RestoreStatsCollector`에 push (기존 `logD` 호출 위치)
3. `LayoutStorageService` 패턴 차용해 디스크 영속 (앱 종료 시 flush, 시작 시 load)
4. `RESTServer`에 `GET /api/v2/restore-stats` 라우팅 추가
5. `openapi_v2.yaml` + `RestAPI_v2.md` 동기화 (api-rules.md 준수)
6. `apiTestDo.sh v2`에 신규 케이스 추가

## 검증

* [ ] 5회 복구 후 `curl http://localhost:3016/api/v2/restore-stats` 응답에 누적값 정확
* [ ] cliApp 재시작 후에도 통계 보존
* [ ] MatchType 분포 합 = 전체 매칭 시도 수
* [ ] `apiTestDo.sh v2` 전체 통과

## 완료 조건

베이스라인 통계 1주일 수집 → 현재 인식률 보고서 작성 → 이후 Phase의 before 데이터로 사용.

# Phase 2 — 데이터 수집 확장 (Track A-1)

## 목표

차후 매칭 정확도를 위해 캡처 시점에 추가 시그널 수집. 본 Phase는 **수집만**, 매칭 로직은 변경 없음.

## 산출물

* `WindowInfo` 스키마 v2 — 옵셔널 필드 `windowOrder`, `displayUUID` 추가
* YAML 직렬화·역직렬화 하위호환 (구 YAML 로드 가능)
* 캡처 시 두 필드 채움

## 작업 단계

1. `WindowInfo.swift`에 옵셔널 `windowOrder: Int?`, `displayUUID: String?` 추가
2. `WindowCaptureService.swift`:
    - `CGWindowListCopyWindowInfo`의 onscreen 순서를 windowOrder로 기록
    - `NSScreen` 또는 `CGDirectDisplayID`에서 UUID 획득
3. YAML 직렬화: 구 형식 파일 로드 시 두 필드 `nil` 허용
4. `apiTestDo.sh` 캡처 결과 검증 케이스 갱신

## 검증

* [ ] 새 YAML 파일에 두 필드 존재
* [ ] 기존 YAML 파일 로드·복구 정상 (하위호환)
* [ ] 멀티 디스플레이 환경에서 displayUUID 일관성

## 완료 조건

신규 캡처 100% 두 필드 포함, 기존 데이터 회귀 없음.

# Phase 3 — 타이틀 정규화 (C-2)

## 목표

동적 타이틀로 인한 90점(exactTitle) 매칭 실패를 회복.

## 산출물

* `cli/fWarrangeCli/Resources/title_normalize.yml` — Top 10 앱 빌트인 룰
* `TitleNormalizer` 서비스 — `strip_prefix`, `strip_suffix`, `strip_pattern`, `mask_pattern` 지원
* 캡처·복구 양쪽에서 동일 정규화 적용
* `GET /api/v2/normalize-rules`, `PUT /api/v2/normalize-rules` REST (paidApp 편집용)

## 룰 대상 (초기 Top 10)

| 앱                      | 패턴                                                          |
| :---------------------- | :------------------------------------------------------------ |
| Safari, Chrome, Firefox | ` — Safari` / ` - Google Chrome` suffix 제거                  |
| Code (VSCode), Cursor   | ` — Visual Studio Code` suffix, `● ` prefix(미저장 표시) 제거 |
| Slack                   | ` \(\d+\)` 알림 카운트 제거                                   |
| iTerm2, Terminal        | 디렉토리 경로 마스킹 옵션                                     |
| Xcode                   | `— project_name` suffix                                       |
| Finder                  | 경로 마스킹                                                   |

## 작업 단계

1. `title_normalize.yml` 작성 (Top 10)
2. `TitleNormalizer` 서비스 구현 — 정규식 캐시
3. `WindowCaptureService`에서 캡처 시 정규화된 title 저장 (원본도 함께 보존: `windowRaw`)
4. `WindowRestoreService.computeMatchScore`에서 axTitle 정규화 후 비교
5. REST CRUD 엔드포인트 추가
6. `openapi_v2.yaml` + `RestAPI_v2.md` 동기화

## 검증

* [ ] Phase 1 통계에서 exactTitle(90점) 매칭률 상승 확인 (before vs after)
* [ ] 정규화 전후 round-trip 동일성
* [ ] 외부 사용자 정의 룰 추가·삭제 가능

## 완료 조건

베이스라인 대비 동적 타이틀 앱 (Safari, Slack 등) 매칭 성공률 +20% 이상.

# Phase 4 — 점수 함수 개선 (Track B)

## 목표

카테고리 점수 → distance 가산 + areaMatch 약화로 노이즈 매칭 감소.

## 산출물

* `computeMatchScore` v2 — distance 가중치 추가
* `minimumScore` 기본값 30 → 50 상향 (또는 매칭 모드별 차등 — Phase 5와 연계)
* areaMatch(30) 비활성화 옵션 (`AppSettings`)

## 작업 단계

1. 기존 카테고리 점수 유지하되, 동률 시 distance 기반 추가 가산 (0~10점)
2. `AppSettings.matchAreaMatchEnabled: Bool` 추가 (기본 false 검토 — Phase 1 통계 보고 결정)
3. `minimumScore` 상수화 후 매칭 모드와 연동 가능하도록 인터페이스 정리
4. Phase 1 통계에서 변경 전후 비교

## 검증

* [ ] 동률 매칭에서 가까운 위치 선호 동작
* [ ] areaMatch 비활성화 시 오탐 감소 확인 (통계)
* [ ] minimumScore 50 상향 시 회귀 없음 (정상 케이스는 80점 이상)

## 완료 조건

베이스라인 대비 오탐(잘못된 창 매칭) 감소 확인. 회귀 없음.

# Phase 5 — 매칭 모드 + 최후 폴백 (C-3 + C-5)

## 목표

사용자가 "정확히" / "비슷하게" 의도를 표현 가능. loose 모드에서 Moom 스타일 폴백 활성.

## 산출물

* `WindowInfo.matchMode: "strict" | "normal" | "loose"` (옵셔널, 기본 normal)
* `POST /api/v2/layouts/{name}/restore` 에 `mode` 파라미터 추가
* loose 모드 한정: 모든 점수 미달 시 **앱별 창 개수 동일 → z-order 순 위치 배분** 폴백

## 모드 정의

| 모드          | minimumScore | 기하 폴백   | 1:N 매칭        | Moom 폴백 |
| :------------ | -----------: | :---------- | :-------------- | :-------- |
| strict        |           80 | ❌           | ❌               | ❌         |
| normal (기본) |           50 | ✅ (50-70점) | ❌               | ❌         |
| loose         |           30 | ✅           | ✅ (Stay 스타일) | ✅         |

## 작업 단계

1. `MatchMode` enum 신설
2. `WindowInfo` 옵셔널 필드 추가 (스키마 v2 확장)
3. `WindowRestoreService` 모드별 분기
4. loose 모드 Moom 폴백 구현 — `(app, count)` 기준 매칭 후 windowOrder 정렬
5. REST API `mode` 파라미터 라우팅
6. `openapi_v2.yaml` + `RestAPI_v2.md` 동기화

## 검증

* [ ] strict 모드: 타이틀 깨진 창 매칭 거부
* [ ] loose 모드: 타이틀 전부 깨져도 위치 배분
* [ ] normal 모드: Phase 4와 동일 동작 (회귀 없음)

## 완료 조건

세 모드 모두 의도된 거동 확인, paidApp UI에서 선택 가능 (Phase 7 선행 불요 — REST로 검증).

# Phase 6 — 고급 식별자: Spaces + PWA (Track A-2)

## 목표

OSS 영역 미개척 시나리오(Spaces, PWA) 대응으로 차별점 확보.

## 산출물

* `spaceId` 캡처 (비공개 `CGSGetActiveSpace` 등 — cliApp non-sandbox 활용)
* `originURL` 캡처 (Chrome `--app=` 등 PWA 식별)
* `Issue71` 헬퍼 `appMatches` 확장: 다중 식별자 시그니처

## 작업 단계

### 6-1. spaceId

1. 비공개 API 도입 PoC — `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces`
2. paidApp 측 `paid_cli_protocol.md`에 비공개 API 도입 합의 후 진행
3. `WindowInfo.spaceId: Int?` 옵셔널 추가
4. 캡처 시 기록, 복구 시 매칭 가산점

### 6-2. PWA originURL

1. 앱별 어댑터: Chrome/Edge (`--app=` 명령행 인자 파싱), Safari PWA
2. `WindowInfo.originURL: String?` 옵셔널 추가
3. `appMatches`를 다중 식별자(bundleId + originURL + appPath)로 일반화

## 검증

* [ ] Space 2개에 분산된 동일 앱 창 정확 복구
* [ ] Chrome PWA(WhatsApp Web 등)와 일반 Chrome 창 구분 복구
* [ ] 식별자 누락 시 하위 점수로 폴백 (회귀 없음)

## 완료 조건

Spaces 분산 시나리오·PWA 시나리오 e2e 테스트 통과.

# Phase 7 — 사용자 개입 UI (C-4)

## 목표

자동 매칭이 애매할 때 paidApp 다이얼로그로 사용자 선택.

## 산출물

* cliApp: 애매한 매칭 결과 노출 API (`POST /api/v2/layouts/{name}/restore`에 `interactive: true` 옵션)
* paidApp: 후보 선택 다이얼로그 (별도 레포 작업)
* 선택 결과 학습 누적 (cliApp 저장, 가중치 자동 조정)

## 작업 단계

### 7-1. cliApp 측

1. 매칭 score < 50 또는 동률 다중 매치 케이스 검출
2. 후보 리스트를 응답에 포함 (interactive 모드)
3. `POST /api/v2/layouts/{name}/restore/resolve` — 사용자 선택 결과 수신

### 7-2. paidApp 측 (별도 레포)

1. cliApp 응답이 candidates 포함 시 다이얼로그 표시
2. 후보별 썸네일 (`CGWindowListCreateImage`)
3. 사용자 선택 → cliApp resolve 호출

### 7-3. 학습 (선택, 1차 미포함 가능)

1. `(app, title pattern, 선택) → 가중치` 매핑 누적
2. 다음 복구 시 같은 패턴 자동 매칭

## 검증

* [ ] interactive 모드에서 애매 케이스 다이얼로그 노출
* [ ] non-interactive 모드 기본 (자동화 안정성)
* [ ] paidApp 미실행 시 normal 모드 fallback

## 완료 조건

paidApp e2e: 동일 타이틀 다중 창 시나리오에서 사용자 선택 후 정확 복구.

# 의존성·순서

```
Phase 1 (측정) ─────────────────────────┐
                                        │
   ┌──── Phase 2 (windowOrder+display) ─┤
   │                                    │
   ├──── Phase 3 (타이틀 정규화)        │
   │                                    │
   └──── Phase 4 (점수 함수) ───────────┤
                                        │
            Phase 5 (모드+폴백) ────────┤  ← Phase 2,3,4 결과 입력
                                        │
            Phase 6 (Spaces, PWA) ──────┤  ← Phase 5 모드 활용
                                        │
            Phase 7 (사용자 UI) ────────┘  ← Phase 5 모드 기반
```

* **Phase 1은 모든 후속 Phase의 검증 토대** — 선행 필수
* Phase 2, 3, 4는 **병렬 가능** — 영향 영역 분리 (캡처 데이터 / 정규화 / 점수)
* Phase 5 이후는 직렬 — 모드 인터페이스가 후속 Phase의 진입점

# 위험 및 미해결

| 위험                                           | 영향                                      | 완화                                                             |
| :--------------------------------------------- | :---------------------------------------- | :--------------------------------------------------------------- |
| 비공개 API(`CGSGetActiveSpace`) 도입 (Phase 6) | macOS 업데이트 시 동작 변경               | cliApp non-sandbox라 App Store 영향 無. version 감지 후 fallback |
| 정규화 룰셋 유지보수 비용                      | 앱 업데이트로 타이틀 변경 시 룰 갱신 필요 | REST API로 사용자 편집 허용 (Phase 3)                            |
| PWA originURL 추출 신뢰도                      | 브라우저별 다름, 헬퍼 프로세스 처리       | 앱별 어댑터 분리, 실패 시 일반 매칭 폴백                         |
| 매칭 모드 디폴트 변경 시 회귀                  | 기존 사용자의 동작 변화                   | normal = 현재 동작 유지 (변화 없음)                              |

# 측정 지표 (Phase 1 베이스라인 기반)

| 지표                           | 베이스라인 (Phase 1) | 목표 (Phase 3 후) | 목표 (Phase 5 후) |
| :----------------------------- | :------------------- | :---------------- | :---------------- |
| 전체 매칭 성공률               | 측정 필요            | +15%              | +25%              |
| exactTitle(90) 비율            | 측정 필요            | +20%              | +20%              |
| areaMatch(30) 비율 (오탐 의심) | 측정 필요            | -50%              | -90%              |
| 매칭 실패율                    | 측정 필요            | -10%              | -20%              |

# 이슈 등록 권장

본 plan은 7개 Phase로 구성되어 **각 Phase별 별도 이슈** 등록 권장 (병렬 진행 가능 + 점진 배포).

* `Issue72: 창 인식률 — Phase 1 측정 인프라`
* `Issue73: 창 인식률 — Phase 2 데이터 수집 확장`
* ... (이슈 등록 시 `/issue-reg`로 HWM 발급)

# 참고

* design SSOT: [`cli/_doc_design/window_recognize.md`](../../_doc_design/window_recognize.md)
* 코드 SSOT: [`WindowRestoreService.swift`](../../fWarrangeCli/Services/WindowRestoreService.swift)
* 점수표 SSOT: [`fWarrange/.claude/rules/window-rules.md`](../../../../fWarrange/.claude/rules/window-rules.md)
* 상위 협업 규약: [`fWarrange/_doc_design/paid_cli_protocol.md`](../../../../fWarrange/_doc_design/paid_cli_protocol.md)
