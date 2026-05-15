---
name: window_recognize
description: 창 인식(매칭) 원리 정리 및 인식률 개선 토의용 설계 문서
date: 2026-05-11
---

# 목적

저장된 YAML 레이아웃을 다시 복구할 때 "이 창이 그 창이다"를 결정하는 매칭 로직을 정리하고, **인식률을 높이기 위한 개선 아이디어**를 토의하기 위한 문서임.

* 코드 SSOT: [`cli/fWarrangeCli/Services/WindowRestoreService.swift`](../fWarrangeCli/Services/WindowRestoreService.swift) (`computeMatchScore`)
* 점수표 SSOT (상위 paidApp 측): [`fWarrange/.claude/rules/window-rules.md`](../../../fWarrange/.claude/rules/window-rules.md)

# 현재 인식 방식

## 입력 데이터 (YAML 한 항목)

```yaml
- app: "Cursor"            # 앱 이름 (ownerName)
  bundleId: "com.todesktop.230313mzl4w4u92"   # 1순위 매칭 키 (Issue71)
  window: "jm4"            # 창 타이틀
  layer: 0                 # 윈도우 레이어 (보통 0)
  id: 16178                # CGWindowID (세션 휘발성)
  pos: { x: -1707, y: 99 }
  size: { width: 1707, height: 1280 }
```

## 매칭 파이프라인

```
1. 앱 그룹핑     : 실행 중 앱 중 bundleId 일치 → ownerName 일치 → localizedName fallback
2. 창 후보 수집  : 해당 앱의 AX 윈도우 목록 + _AXUIElementGetWindow()로 CGWindowID 획득
3. 점수 계산    : 각 (저장된 target × 실행 중 window) 쌍에 대해 computeMatchScore()
4. 전역 탐욕    : score DESC → distance ASC 로 전역 최적 할당 (per-target 탐욕 금지)
5. 임계값 필터  : score < minimumScore(기본 30) → 매칭 실패
6. 재시도       : 앱이 아직 안 떴거나 후보 부족 시 최대 5회, 0.5s 간격
```

## 점수 테이블

| 점수 | MatchType        | 조건                                          |
| :--- | :--------------- | :-------------------------------------------- |
| 100  | `.windowID`      | `cgWindowId == target.id` (target.id ≠ 0)     |
| 90   | `.exactTitle`    | `axTitle == target.window`                    |
| 80   | `.regexTitle`    | target.window를 정규식으로 해석 → axTitle 매칭 |
| 70   | `.containsTitle` | axTitle이 target.window를 포함 (또는 역방향)   |
| 60   | `.widthMatch`    | 너비가 거의 동일                               |
| 50   | `.heightMatch`   | 높이가 거의 동일                               |
| 40   | `.ratioMatch`    | 가로세로 비율 유사                             |
| 30   | `.areaMatch`     | 면적 유사                                      |
| 0    | `.noMatch`       | 위 어디에도 해당 안 됨                         |

# 인식률을 떨어뜨리는 현실 케이스

## A. ID 휘발성 문제

* `id: 16178`은 **CGWindowID** — OS 재부팅·앱 재시작 시 새로 발급됨
* 동일 세션 즉시 복구에만 100점 의미가 있고, 평소 복구 시나리오에서는 거의 항상 fallback
* → 사실상 90점(타이틀) 이하가 실전 기본선

## B. 타이틀이 동적인 앱

| 앱        | 타이틀 패턴                          | 문제                                              |
| :-------- | :----------------------------------- | :------------------------------------------------ |
| 브라우저  | `"Google — Safari"`, `"GitHub — …"`  | 페이지 이동 시 매번 변경 → exactTitle 깨짐        |
| 에디터    | `"file.swift — fWarrange"`           | 열려 있는 파일에 따라 변경                        |
| 터미널    | `"jm4"`, `"~/_git/… — zsh"`          | 디렉토리 이동 시 변경                             |
| 채팅 앱   | `"Slack — finfra (12)"`              | 안 읽은 메시지 수 변동                            |
| 시스템 앱 | `""` (빈 타이틀)                     | 매칭 키 없음 → 70점 이하 강제                     |

## C. 다중 창 동일 타이틀

* 같은 앱의 창 두 개가 똑같은 타이틀 (ex: Finder 두 창이 모두 `"Downloads"`)
* 90점 동률 → distance 기반 tie-breaking에 의존 → 위치가 비슷하면 뒤바뀜

## D. 앱 식별 실패

* `ownerName`(CG) vs `localizedName`(NSRunningApplication) 불일치
    - VSCode: ownerName=`Code`, localizedName=`Visual Studio Code`
    - Issue71에서 bundleId 우선으로 완화됨
* Electron 앱이 헬퍼 프로세스로 윈도우를 띄우는 경우 PID·bundleId가 다를 수 있음
* PWA·웹 클립처럼 동일 bundleId(Chrome)에 여러 "논리적 앱"이 있는 경우

## E. 멀티 디스플레이 토폴로지 변경

* 외부 모니터 연결/해제 시 좌표계 변동 → 기하 유사도(60~30점) 의미 상실
* 음수 좌표가 사라지거나 새로 생김

## F. 풀스크린·Stage Manager·Spaces

* Space가 다르면 AX 윈도우 목록에 안 잡힘 → 후보 0
* 풀스크린은 별도 Space로 동작

## G. 임계값 30점의 한계

* 30점은 "면적만 비슷"이라는 매우 약한 신호 — 전혀 다른 창이 운 좋게 30점 매칭 가능
* 반대로 타이틀이 살짝 바뀐 같은 창이 70점 미만으로 떨어지면 매칭 실패

# 인식률 개선 아이디어 (토의 항목)

## 1. 매칭 시그널 다변화

| 추가 시그널           | 출처                                  | 효과                                    | 비용/리스크                          |
| :-------------------- | :------------------------------------ | :-------------------------------------- | :----------------------------------- |
| 창 순서(z-order)      | CGWindowListCopyWindowInfo의 onscreen | 동일 타이틀 다중 창 tie-breaking 강화   | 캡처 시점에 함께 저장 필요           |
| 디스플레이 ID         | `CGDirectDisplayID` (or UUID)         | 멀티 디스플레이 환경에서 좌표 의존 ↓    | 디스플레이 교체 시 무의미            |
| Space ID              | private API `CGSGetActiveSpace` 등    | 풀스크린/Spaces 매칭                    | 비공개 API 추가 (App Store 영향 無, cliApp만 사용) |
| 창 생성 시각/PID      | NSRunningApplication.launchDate       | 재시작 직후 ID 매칭 보조                | 휘발성은 동일                        |
| 타이틀 정규화         | "— Safari" suffix 제거, 숫자 마스킹   | 동적 타이틀 90점 회복                   | 정규화 규칙 유지보수                 |
| 타이틀 fuzzy 유사도   | Levenshtein, token Jaccard            | 부분 변경된 타이틀 매칭 (75점 신설?)    | 임계값 튜닝 필요                     |
| 위치 우선 매칭        | 동일 앱 내 가까운 위치 우선           | 같은 타이틀 다중 창 안정                | 이미 distance tie-break으로 반영 중  |

## 2. 점수 체계 재설계

현재는 카테고리 점수(100/90/80/…) **선택형**임. 한 가지 강한 신호로 결정되어 다른 신호가 무시됨. 대안:

* **가중 합산 방식**: 각 시그널을 0~1 점수로 환산 후 가중치 합 → 100점 스케일
    ```
    score = w_id * id_match
          + w_title * title_similarity
          + w_geom * geom_similarity
          + w_zorder * zorder_match
          + w_display * display_match
    ```
* **장점**: 약한 신호 여러 개를 결합해 30점 미만 노이즈 매칭 억제
* **단점**: 가중치 튜닝 비용, 임계값 의미 재정의 필요

## 3. 타이틀 정규화 룰셋

```yaml
# title_normalize.yml (제안)
- app: "Safari"
  strip_suffix: " — Safari"
  mask_pattern: "(\\d+)"   # 숫자 마스킹 옵션
- app: "Code"
  strip_suffix: " — Visual Studio Code"
  strip_prefix: "● "       # 미저장 표시 dot
- app: "Slack"
  strip_pattern: " \\(\\d+\\)"  # 알림 카운트
```

캡처·복구 양쪽에서 동일 정규화를 적용하면 90점 매칭률 회복 가능.

## 4. 저장 시 스냅샷 강화

현재 저장되는 필드 외에 추가 저장 가능:

* `windowOrder`: 같은 앱 내 z-order index
* `displayUUID`: 어느 디스플레이에 있었는가
* `spaceId`: 어느 Space에 있었는가
* `pidAge`: 앱 실행 후 N번째 창
* `iconHash` or `windowSnapshotHash` (오버킬 — 토의용)

## 5. 사용자 개입 UI

매칭 실패·애매한 매칭 시 사용자에게 묻는 옵션:

* "이 창이 맞나요?" 후보 N개 제시
* 정답 선택 시 학습 데이터로 저장 → 다음 복구부터 가중치 자동 조정

## 6. 임계값·재시도 정책 조정

| 항목             | 현재  | 토의                                    |
| :--------------- | :---- | :-------------------------------------- |
| minimumScore     | 30    | 50으로 올리고, 아래는 "사용자 확인" UI?  |
| maxRetries       | 5     | 앱 종류별 차등 (Electron은 더 길게)     |
| retryInterval    | 0.5s  | 백오프 (0.5 → 1 → 2s)                   |
| areaMatch(30)    | 활성  | 비활성화 검토 (오탐 주범)               |

## 7. 측정 인프라

개선 효과를 검증하려면 **인식률 측정 지표**가 먼저 필요함:

* 복구 1회당: 전체 target 수, 성공 수, MatchType 분포, 평균 score
* 누적 통계: 자주 실패하는 (app, titlePattern) 페어
* 로그 필드: 이미 `logD("[복구] '\(target.app)'/'\(match.title)' score=\(match.score) \(match.matchType)")` 있음 → 집계 스크립트만 추가하면 됨

# 토의 우선순위 제안

| 순위 | 아이디어                          | 근거                                            |
| :--: | :-------------------------------- | :---------------------------------------------- |
|  1   | 측정 인프라 (§7)                  | 개선 전후 비교 없으면 어떤 변경도 검증 불가      |
|  2   | 타이틀 정규화 룰셋 (§3)           | 가장 흔한 실패 케이스(B), 비용 낮음, 효과 큼     |
|  3   | windowOrder + displayUUID 저장 (§4) | 멀티창·멀티디스플레이 두 시나리오 동시 개선     |
|  4   | 가중 합산 점수 (§2)                | 위 시그널이 모이면 자연스럽게 필요해짐           |
|  5   | areaMatch(30) 비활성화 검토 (§6)   | 부작용 큼, 단독으로도 측정 후 결정 가능          |
|  6   | 사용자 개입 UI (§5)                | 자동화 한계 도달 시 최후 수단                    |

# 미해결 질문 (토의)

1. **CGWindowID 100점을 유지할 가치가 있는가?** — 거의 항상 휘발됨. 차라리 "같은 세션 재현용" 별도 경로로 분리?
2. **bundleId가 다른데 같은 앱(브라우저 PWA 등)** 을 어떻게 다룰 것인가?
3. **풀스크린·Spaces 지원 범위** — 현재 한 Space만 지원. 어디까지 확장할지?
4. **레이아웃 저장 시점의 사용자 의도** — "이 창을 정확히 이 위치에"인지 "이 비슷한 창을 비슷한 위치에"인지 사용자가 선택?
5. **paidApp vs cliApp 역할 분담** — UI 개입(§5)이 들어가면 paidApp 영역, 매칭 알고리즘은 cliApp 영역. 정규화 룰셋은 어디에?

# 해결 시도 추적 (Prior Art)

각 질문에 대해 본 레포·상위 paidApp 레포·코드에서 시도되었거나 부분적으로 답이 있는 흔적.

## Q1. CGWindowID 100점 유지 가치

* **현재 코드**: [`WindowRestoreService.swift:390`](../fWarrangeCli/Services/WindowRestoreService.swift#L390) — `if cgWindowId == target.id && target.id != 0` 조건은 이미 `target.id != 0` 가드로 방어. 즉 미저장(0) 시 자동으로 90점 이하로 폴백
* **명시적 시도 없음**: "세션 재현 전용 경로 분리"는 코드·이슈에 흔적 없음 — 본 토의가 첫 제기
* **부분 사례**: Issue.md Save Point 메커니즘이 "같은 세션 내 즉시 복구" 시나리오를 다루나, 창 매칭이 아니라 git 커밋 해시 기록임 — 동일 의도(세션 식별)는 아님
* **결론**: 미해결, 단 가드(`!= 0`)로 부작용은 차단되어 있어 긴급도는 낮음

## Q2. bundleId가 다른데 같은 앱 (PWA 등)

* **Issue71 완료 (2026-05-08, 7b41337)**: ownerName ↔ localizedName 불일치(`Code` vs `Visual Studio Code`)는 **bundleId 우선 매칭**으로 해결됨
    - [`WindowRestoreService.swift:19~46`](../fWarrangeCli/Services/WindowRestoreService.swift#L19) `appMatches(_:targetApp:targetBundleId:)` — bundleId 정확 일치를 1순위로
    - 단 이는 "**같은 앱인데 이름이 다르게 보이는** 경우" 해결. PWA처럼 "**bundleId는 같은데 논리적으로 다른 앱**"은 반대 방향이라 미해결
* **명시적 PWA 흔적**: 코드·이슈에 PWA/`Chrome --app=` 처리 없음
* **부분 단서**: Issue71 fix는 매칭 키를 **다중화**할 수 있는 구조(`appMatches`)를 만들어 둠 → 향후 `windowOrder + originURL` 같은 추가 키 도입 시 같은 헬퍼 확장 가능
* **결론**: 반쪽 해결. Issue71 패턴을 역방향(다중 식별자)으로 확장하면 PWA 대응 가능

## Q3. 풀스크린·Spaces 지원 범위

* **현재 한계 명시**: [`window_recognize.md` §F](#f-풀스크린stage-managerspaces) — 다른 Space 창은 AX 목록에 미노출
* **시도된 우회**: 본 레포 코드 grep 결과 `CGSpace`, `CGSGetActiveSpace`, fullscreen 관련 처리 **전무**
* **간접 사례**: [`menubar-icon-design.md`](menubar-icon-design.md)에서 NSWorkspace 이벤트로 앱 라이프사이클을 추적하나 Space 단위는 다루지 않음
* **상위 paidApp 측**: `_doc_arch/paid_cli_protocol.md`에 Space 관련 정의 없음
* **결론**: 완전 미시도. 비공개 API(`CGSGetActiveSpace`) 도입이 필요한 영역

## Q4. 사용자 의도 (strict vs loose)

* **현재 코드**: 단일 임계값 `minimumScore = 30` 하드코딩 가까운 형태로 `WindowRestoreService` 호출부에서 주입 ([L69, L95](../fWarrangeCli/Services/WindowRestoreService.swift#L69))
* **명시적 시도 없음**: 레이아웃별 strict/loose 옵션, "이 창은 정확히"·"이 창은 비슷하게" 플래그 등 코드·YAML 스키마에 없음
* **간접 단서**:
    - YAML 스키마는 추가 필드 받아도 무방함 (현재 [`WindowInfo.swift`](../fWarrangeCli/Models/WindowInfo.swift)는 고정 필드)
    - [API_v2](RestAPI_v2.md)에 `/api/v2/layouts/{name}/restore`는 옵션 파라미터 없음 — 추가 여지 있음
    - API 테스트 리포트 [`apiTest_v2_run_2026-04-13.md`](../_doc_work/z_done/report/apiTest_v2_run_2026-04-13.md)에서 "Strict 검증" 용어 사용 — 단 이는 API 테스트의 검증 방식이지 매칭 모드는 아님
* **결론**: 미해결. 스키마·API 양쪽 확장 필요

## Q5. paidApp vs cliApp 역할 분담 / 정규화 룰셋 위치

* **상위 SSOT**: `~/_git/__all/fWarrange/_doc_arch/paid_cli_protocol.md` — 분리 배경·REST/URL Scheme·기능 경계 정의됨 (현재 컨텍스트에서 직접 grep 안 됨, 메모리 기준)
* **메모리 단언**: `project_paidapp-ui-scope.md` — "고급 기능 GUI(Screen 설정·Settings·Layout 목록/상세)는 **paidApp 전담**, cliApp은 **데이터·REST만**"
* **메모리 단언**: `project_ssot-split.md` — 메뉴 구조는 `menuBar_enhance.md`, 라이프사이클은 `paid_cli_protocol.md`
* **코드 사례**: Issue.md 진행 이슈들(예: 메뉴 단축키 정책)은 정책을 paidApp 측 protocol에 두고 구현을 cliApp에 두는 패턴 일관
* **본 질문 적용**:
    - 매칭 알고리즘(코드) → **cliApp** (이미 그렇게 됨)
    - 매칭 결과 UI(후보 제시·사용자 선택) → **paidApp**
    - 정규화 룰셋 — 두 방향 가능:
        a. **데이터 SSOT가 cliApp**: 룰셋도 cliApp에 두고 paidApp이 REST로 조회/편집 (현재 `_config.yml` SSOT 패턴과 일관)
        b. **사용자 편집 UI는 paidApp**: 룰셋 편집기는 paidApp, 적용은 cliApp이 한다 — 둘이 함께 사는 형태
    - 메모리·기존 패턴상 **(a) cliApp 보유 + paidApp 편집 REST** 가 정합적
* **결론**: 분담 원칙은 명확. 정규화 룰셋만 결정 남음 — 사실상 (a) 권장

# 토의 진행 시 다음 단계 제안

| 질문 | 다음 단계                                                      |
| :--: | :------------------------------------------------------------- |
|  Q1  | 측정 인프라(§7) 도입 후 `.windowID` 매칭 적중률 통계 확인 → 데이터 기반 결정 |
|  Q2  | Issue71 `appMatches` 헬퍼 확장 설계 — 다중 식별자(`bundleId + originURL/appPath`) 시그니처 추가 |
|  Q3  | 별도 이슈 등록 — 비공개 API 도입 PoC + paidApp 측 protocol 합의 |
|  Q4  | `WindowInfo` 스키마에 옵셔널 `matchMode: "strict"|"loose"` 필드 + API `restore` 옵션 추가 안 |
|  Q5  | `cli/_doc_arch/title_normalize.yml` (SSOT) + REST `/api/v2/normalize-rules` CRUD 엔드포인트 설계 |

# 유사 프로젝트 비교 (Prior Art Survey)

같은 문제 — "macOS 창 레이아웃을 저장하고 다시 복구할 때 어떤 창이 어떤 창인지 식별" — 를 다루는 프로젝트들을 조사함. 매칭 키·전략·한계만 비교.

## 비교 매트릭스

| 프로젝트                         | 라이선스 | 매칭 키                                          | 매칭 전략                                        | 동일 타이틀 다중 창 | 재시작 후 복구 | 멀티 디스플레이 트리거 |
| :------------------------------- | :------- | :----------------------------------------------- | :----------------------------------------------- | :------------------ | :------------- | :--------------------- |
| **fWarrangeCli** (본 프로젝트)   | OSS      | bundleId+ownerName, title, **CGWindowID**, 크기  | 점수 0~100 카테고리 선택형, 전역 탐욕 할당       | distance tie-break  | 타이틀 90→폴백 | 수동 + REST            |
| **Stay** (Cordless Dog)          | 상용     | **ICU regex title**, 크기 근사치                 | "closest match"(미공개), 패턴 중첩 허용          | 패턴+근사매칭       | 패턴 매칭      | 디스플레이 변경 자동   |
| **Moom** (Many Tricks)           | 상용     | **title**, 실패 시 창 **개수**                   | 타이틀 우선, fallback=앱별 창 수 매칭            | 미공개 (개수 폴백)  | 개수 폴백      | 디스플레이 변경 자동   |
| **MacLayout**                    | 상용     | (미공개)                                         | 디스플레이 구성/앱 실행 트리거 자동 복구         | 미공개              | 미공개         | 자동                   |
| **Memmon** (relikd, 오픈소스)    | OSS      | **PID + CGWindowNumber 만**                      | 세션 내 단순 매핑, 정렬 보존                     | 미지원              | 미지원         | `screenParameters` 자동 |
| **macOS-Window-Position-Utility** | OSS      | 앱 이름 + 윈도우 제목 + 크기                     | JSON 저장, 단순 매칭                             | 미명시              | 미명시         | 수동 명령              |
| **yabai**                        | OSS      | app name + (optional) title regex 룰             | 정적 룰, 동적 매칭 아님                          | 룰 작성자 책임      | N/A (룰 영구)  | N/A                    |
| **Rectangle / Magnet**           | OSS/상용 | (저장·복구 미지원)                               | 스냅핑만                                         | N/A                 | N/A            | N/A                    |
| **Swindler** (lib)               | OSS      | AXUIElement + PID (모델 캐싱)                    | 매칭이 아니라 추적 (앱 재시작 시 새 객체)        | N/A (실시간 추적)   | N/A            | N/A                    |

## 시사점

### S1. CGWindowID-only 접근(Memmon)은 의도적 단순화

* Memmon은 **타이틀·bundleId 전혀 안 봄**. PID + WindowNumber(=CGWindowID)만 사용
* "디스플레이 연결 변화" 시나리오에 한정되어 세션 내 복구만 다루기 때문
* 우리 Q1("CGWindowID 100점 분리")의 극단 버전이 이미 OSS에 존재한다는 증거 — 시나리오를 명확히 분리하면 그 자체로 답이 됨

### S2. Stay의 "ICU regex + closest match"는 우리 80점(regexTitle)과 동일 컨셉

* Stay 매뉴얼: "Approximate matching of window titles, favouring the closest match. Approximate matching of window sizes, favouring the closest match"
* 즉 우리 §2(가중 합산)·§3(타이틀 정규화) 방향성이 상용 도구와 일치 — 검증된 길임
* Stay는 한 저장된 창이 **여러 열린 창에 매칭 가능**하다고 명시 — 우리 "전역 탐욕 할당"과 반대. 의도적 1:N 적용 (브라우저 창마다 같은 위치) 케이스
* 우리도 §4(strict/loose)의 "loose 모드"로 같은 의미를 줄 수 있음

### S3. Moom의 "창 개수 폴백"은 검토할 만한 fallback

* Moom 동작 보고: 타이틀 매칭 실패 시 **앱별 창 개수가 같으면** 위치를 그냥 배분
* 우리 30점 areaMatch보다 더 약한 신호로 폴백 동작 — "내용은 모르겠지만 자리는 맞춰주기"
* 토의 가치: 30점 미만 케이스에 "최후 폴백"으로 도입할지

### S4. Swindler·yabai는 우리와 문제가 다름

* Swindler/yabai는 **실시간 추적**(앱 실행 동안 창 이벤트 구독) — 우리는 **시점 간 매칭**(저장 시점 ↔ 복구 시점). 식별자 안정성 요구가 다름
* 다만 Swindler의 "in-memory model + 이벤트 구독"은 우리가 캡처 시점에 zorder·spaceId 같은 추가 시그널을 함께 채집할 때 차용 가능

### S5. PWA / 다중 식별자

* 검토한 어떤 프로젝트도 PWA(같은 bundleId·다른 논리 앱)를 명시적으로 다루지 않음 — 보편적 미해결 영역
* 우리 Issue71의 `appMatches(_:targetApp:targetBundleId:)` 다중 식별자 헬퍼 확장이 차별점이 될 여지 있음

### S6. Spaces / Fullscreen

* Memmon: "Other Space 창은 그 Space 활성 시에만 복구" — 우리와 같은 한계
* Stay·Moom: 명시적 언급 없음 — 모두 회피하는 영역
* 우리 Q3(비공개 `CGSGetActiveSpace` 도입)는 OSS 영역에선 거의 미개척

## 토의용 차용 후보

| 출처      | 차용 아이디어                                            | 본 문서 연결            |
| :-------- | :------------------------------------------------------- | :---------------------- |
| Stay      | "1:N 매칭 허용 모드" — 한 저장된 창 → 매칭되는 모든 창 적용 | §4(loose 모드) 구체화   |
| Stay      | 크기 근사 매칭을 width/height 따로가 아닌 **합산 거리**로 | §2(가중 합산 점수)      |
| Moom      | 최후 폴백: **앱별 창 개수 동일 시 z-order 순서로 배분**  | §6(임계값) area 대체    |
| Memmon    | "현재 세션 즉시 복구" 별도 경로 (CGWindowID-only)        | Q1 결정 — 분리          |
| Swindler  | 캡처 시 **zorder + AXUIElement 메타** 함께 수집          | §4(저장 스냅샷 강화)    |
| yabai 룰  | 사용자 정의 룰(앱별 매칭 규칙)을 별도 YAML로             | §3(타이틀 정규화 룰셋)  |

# 토론 트랙 (3-Track Discussion)

본 문서의 모든 개선 아이디어·미해결 질문·차용 후보를 세 갈래 토론 트랙으로 재배치함. 트랙끼리 직교적이라 병렬 토의 가능. 트랙 간 시너지는 마지막에 별도 정리.

## Track A. 윈도우 정보 수집 강화 (Identity Enrichment)

**관점**: "창을 더 잘 구분할 수 있는 시그널을 캡처 시점에 더 많이 모은다."

### 핵심 질문

* 어떤 시그널을 더 모으면 인식률이 의미 있게 오르는가?
* 비공개 API·추가 권한 비용을 어디까지 감수할 것인가?
* 저장 스키마(YAML) 확장과 하위호환을 어떻게 유지하는가?

### 현재 상태

* 수집 중: `app`, `bundleId`, `window(title)`, `layer`, `id(CGWindowID)`, `pos`, `size`
* Issue71에서 `bundleId` 추가하여 ownerName 불일치 해결 — **다중 식별자 헬퍼 `appMatches`** 토대 마련됨

### 추가 후보 시그널

| 시그널                | 출처                                  | 안정성              | 비용                     |
| :-------------------- | :------------------------------------ | :------------------ | :----------------------- |
| `windowOrder` (zorder) | CGWindowListCopyWindowInfo 순서       | 세션 휘발성         | 캡처 시 함께 저장만 하면 됨 |
| `displayUUID`         | `CGDirectDisplayID`                   | 디스플레이 교체 시 무효 | 공개 API                 |
| `spaceId`             | 비공개 `CGSGetActiveSpace`            | 안정적              | 비공개 API (cliApp 사용 가능) |
| `axIdentifier`        | AX 속성 `AXIdentifier`                | 앱이 노출해야 의미 있음 | 공개 API                 |
| `originURL` (PWA)     | Chrome/Safari 등 명령행 인자          | 앱 종류별 분기      | 큼 (앱별 어댑터)         |
| `pidAge` / launchDate | NSRunningApplication.launchDate       | 세션 휘발성         | 공개 API                 |
| `windowSnapshotHash`  | 윈도우 이미지 해시                    | 콘텐츠 변경에 약함  | CPU/메모리 큼            |

### 차용 후보 (Prior Art)

* Swindler — 캡처 시 zorder + AXUIElement 메타 수집 패턴
* yabai — 앱별 룰셋 YAML 구조 (단, 실시간 추적용이라 직접 이식은 X)
* Issue71 — 본 프로젝트 내 다중 식별자 헬퍼 일반화

### 미해결 질문 매핑

* Q2 (PWA / 다중 논리앱) — `originURL` 또는 `appPath` 추가로 해결 시도 가능
* Q3 (Fullscreen / Spaces) — `spaceId` 추가가 전제조건
* Q5 (분담) — 수집 자체는 cliApp 책임. UI 편집은 paidApp

### 결정해야 할 것

1. `WindowInfo` 스키마에 옵셔널 필드를 추가할 것인가, 별도 파일로 분리할 것인가?
2. 비공개 API(`CGSGetActiveSpace`) 도입 의사 — cliApp은 non-sandbox이므로 가능
3. PWA 대응 우선순위 — 사용자 요구가 명확한 경우만 점진 도입?

## Track B. 크기·면적 유사성 기반 매칭 (Geometric Similarity)

**관점**: "타이틀·식별자가 깨져도 '같은 자리에 비슷한 모양으로 있던 창'은 그 창일 가능성이 높다."

### 핵심 질문

* 기하 유사도(60~30점)는 실전에서 얼마나 도움이 되는가, 얼마나 오탐을 일으키는가?
* 카테고리 점수(폭/높이/비율/면적 중 **하나만**)에서 **가중 합산**으로 바꿀 가치가 있는가?
* 멀티 디스플레이·해상도 변경 시 기하 신호를 어떻게 보정할 것인가?

### 현재 상태

| 점수 | 조건                              | 허용오차     |
| :--- | :-------------------------------- | :----------- |
| 60   | 너비 동일                         | 5px          |
| 50   | 높이 동일                         | 5px          |
| 40   | 가로세로 비율 동일                | 0.05         |
| 30   | 면적 동일                         | 5%           |

* 임계값(`minimumScore`) 기본 30, distance(위치 거리)는 tie-break 용도로만 사용

### 개선 아이디어

| 아이디어                            | 효과                                       | 리스크                           |
| :---------------------------------- | :----------------------------------------- | :------------------------------- |
| 가중 합산 점수로 통합               | 약한 신호 결합 → 노이즈 매칭 감소          | 가중치 튜닝 필요                 |
| distance를 점수에 포함              | 같은 자리에 같은 모양 = 강한 신호          | 위치는 멀티 디스플레이에 취약    |
| 면적 매칭(30점) 비활성화 옵션       | 오탐 감소                                  | 일부 정상 매칭도 잃음            |
| 디스플레이 좌표계 정규화            | displayUUID 기준 상대좌표로 재계산         | Track A의 displayUUID 의존       |
| 종횡비 토큰화 (16:9, 4:3, 정사각형) | 디스플레이 회전·해상도 변경에 강인         | 토큰 경계 정의 필요              |
| 영역 IoU (intersection over union)  | 겹침 비율로 단일 점수 — 폭/높이/면적 통합   | 디스플레이 좌표 신뢰 필요        |

### 차용 후보 (Prior Art)

* Stay — "approximate matching of window sizes, favouring the closest match" (구체 알고리즘 비공개이나 방향성 일치)
* Moom — 최후 폴백: **앱별 창 개수가 같으면** 위치를 z-order 순으로 배분 → 30점보다 약한 폴백으로 검토 가치
* Swindler — 실시간 추적 시 위치/크기 변화 이벤트를 신뢰 신호로 활용

### 미해결 질문 매핑

* Q1 (CGWindowID 분리) — 같은 세션이면 위치도 동일할 가능성 큼. 세션 경로 분리 후 기하 폴백 제거 검토
* Q4 (strict/loose) — strict 모드는 기하 점수 비활성, loose 모드는 적극 활용 — 트랙 B가 strict/loose의 핵심 차이를 만든다

### 결정해야 할 것

1. 카테고리 점수 → 가중 합산으로 전환할지, 카테고리를 유지하되 distance를 점수에 가산할지
2. `minimumScore` 기본값을 30 유지, 50 상향, 또는 매칭 모드별 차등?
3. 디스플레이 토폴로지 변경 시 기하 신호를 **자동 무시**할 트리거 마련?

## Track C. 그 외: 정책·UX·인프라 (Policy / UX / Infrastructure)

**관점**: "알고리즘 자체보다 그 주변(룰셋·사용자 의도·측정·역할분담)이 인식률 체감에 더 큰 영향을 줄 수 있다."

### 핵심 질문

* 알고리즘을 바꾸기 전에 **현재 인식률을 측정**할 수 있는가?
* 사용자가 "이 창은 정확히 / 이 창은 비슷하게" 의도를 표현할 수 있어야 하는가?
* 정규화 룰셋·매칭 모드·UI 개입은 어느 앱(paidApp/cliApp)에 두는가?

### 하위 트랙

#### C-1. 측정 인프라 (선결조건)

* 이미 로그에 `score`, `matchType` 기록 중 — 집계만 추가하면 됨
* 메트릭 후보: 복구당 성공률, MatchType 분포, 평균 score, 자주 실패하는 `(app, titlePattern)` 페어
* 위치: cliApp 로컬 누적 + REST `/api/v2/restore-stats` 노출, paidApp이 GUI로 시각화

#### C-2. 타이틀 정규화 룰셋

* 동적 타이틀(브라우저·에디터·터미널) 정규화 → exactTitle(90점) 회복
* 예시: `Slack — finfra (12)` → `Slack — finfra`, `file.swift — Code` → `Code`
* 형식: `cli/_doc_arch/title_normalize.yml` (cliApp SSOT) + paidApp이 REST `/api/v2/normalize-rules` CRUD로 편집
* 차용: yabai의 룰 YAML 패턴

#### C-3. 사용자 의도 표현 (strict / loose)

* `WindowInfo`에 옵셔널 `matchMode: "strict" | "normal" | "loose"` 필드
* strict: ID/exactTitle/regexTitle만 허용 (점수 ≥80), 기하 폴백 차단
* normal: 현재 동작 (≥30)
* loose: Stay 스타일 1:N 매칭 허용, 면적·창개수 폴백까지 사용
* API: `POST /api/v2/layouts/{name}/restore`에 `mode` 파라미터

#### C-4. 사용자 개입 UI (마지막 수단)

* 매칭 score < 50 또는 동률 다중 매치 시 paidApp 다이얼로그 띄우기
* "이 창이 맞나요?" + 후보 N개 썸네일
* 선택 결과를 학습 데이터로 누적 → 다음 복구부터 가중치 조정

#### C-5. 폴백 정책 (Moom 스타일)

* 모든 점수가 임계값 미만일 때 최후 수단: **앱별 창 개수가 같으면 z-order 순으로 위치 배분**
* "내용은 모르겠지만 자리는 맞춰주기"
* loose 모드에서만 활성 권장

#### C-6. 세션 즉시 복구 분리 (Memmon 스타일)

* "지금 이 순간 저장 → 디스플레이 연결 시 자동 복구" 같은 세션 시나리오는 CGWindowID 단독 매칭이 충분
* 별도 경로(`/api/v2/snapshot-restore`)로 분리해 메인 로직과 격리 → Q1 자연스럽게 해결

#### C-7. 역할 분담 (paidApp / cliApp)

| 컴포넌트                | 위치     | 근거                                        |
| :---------------------- | :------- | :------------------------------------------ |
| 매칭 알고리즘           | cliApp   | 데이터·API SSOT                              |
| 측정 누적·노출 API      | cliApp   | 로그·통계 보유                              |
| 통계 대시보드 GUI       | paidApp  | 메모리 `project_paidapp-ui-scope.md`        |
| 정규화 룰셋 데이터      | cliApp   | `_config.yml` SSOT 패턴 일관                |
| 정규화 룰셋 편집 UI     | paidApp  | 사용자 GUI는 paidApp 전담                   |
| 매칭 모드 선택 UI       | paidApp  | 동                                          |
| 후보 선택 다이얼로그    | paidApp  | 사용자 개입은 GUI 영역                      |

### 미해결 질문 매핑

* Q1 (세션 분리) — **C-6**으로 답
* Q4 (strict/loose) — **C-3**으로 답
* Q5 (분담·룰셋 위치) — **C-7**로 답

### 결정해야 할 것

1. 측정 인프라(C-1) 도입을 다른 모든 작업의 선결조건으로 둘 것인가?
2. 정규화 룰셋(C-2)을 사용자 편집 가능 형태로 시작할지, 일단 빌트인 룰만 제공할지?
3. 사용자 개입 UI(C-4) 시점 — strict 모드 동률만? 모든 저점수?

## 트랙 간 의존성

```
       ┌──────────────────────────────────────────────┐
       │  C-1 측정 인프라 (선결, 모든 트랙의 검증 토대)  │
       └──────────────┬───────────────────────────────┘
                      │
        ┌─────────────┼──────────────┐
        ▼             ▼              ▼
   ┌─────────┐  ┌─────────┐    ┌─────────┐
   │Track A  │  │Track B  │    │ C-2~C-6 │
   │식별자   │  │기하유사 │    │정책·UX  │
   │확장     │  │가중합산 │    │룰셋·모드│
   └────┬────┘  └────┬────┘    └────┬────┘
        │            │              │
        └──────┬─────┴──────┬───────┘
               ▼            ▼
        ┌──────────────────────────┐
        │ C-7 paidApp/cliApp 분담  │
        │ (모든 트랙이 정착될 때    │
        │  자연스럽게 결정됨)       │
        └──────────────────────────┘
```

* **C-1(측정)은 모든 트랙의 선결조건** — 개선 효과 검증 없이는 어떤 변경도 가치 입증 불가
* Track A의 `displayUUID`·`spaceId` 수집은 Track B의 디스플레이 정규화·기하 신호 보정에 입력
* Track A의 다중 식별자는 C-3의 strict 모드에서 비로소 활용도가 극대화 (식별자 많아도 모드가 없으면 똑같이 점수화)
* Track B의 거리 가중치는 C-5(Moom 폴백)과 충돌 가능 — 어느 게 우선인지 정의 필요

## 토의 진행 권장 순서

| 단계 | 트랙 | 작업                                          | 산출물                       |
| :--: | :--: | :-------------------------------------------- | :--------------------------- |
|  1   | C-1  | 측정 인프라 구축 + 현재 인식률 베이스라인 수집 | `restore-stats` REST + 리포트 |
|  2   |  A   | windowOrder + displayUUID 캡처 추가            | YAML 스키마 v2               |
|  3   | C-2  | 빌트인 타이틀 정규화 룰셋 (Top 10 앱)          | `title_normalize.yml` v1     |
|  4   |  B   | 거리 가중치 도입 + areaMatch(30) 약화           | 점수 함수 v2                 |
|  5   | C-3  | strict/loose 매칭 모드 추가                    | API v2 + WindowInfo v2       |
|  6   |  A   | spaceId 도입 (Q3)                              | 비공개 API 도입 결정          |
|  7   | C-5  | Moom 스타일 최후 폴백 (loose 모드 한정)         | 폴백 로직                    |
|  8   |  A   | PWA `originURL` 등 (Q2)                        | 다중 식별자 v2               |
|  9   | C-4  | 사용자 개입 UI                                 | paidApp 다이얼로그           |

# 참고

* [`cli/_doc_arch/cliApp_design.md`](cliApp_design.md) — cliApp 전체 아키텍처
* [`fWarrange/.claude/rules/window-rules.md`](../../../fWarrange/.claude/rules/window-rules.md) — 점수표 SSOT (paidApp 측)
* [`fWarrange/.claude/rules/coding-rules.md`](../../../fWarrange/.claude/rules/coding-rules.md) §5 — 매칭 임계값·허용오차
* 코드: [`WindowRestoreService.swift`](../fWarrangeCli/Services/WindowRestoreService.swift), [`MatchType.swift`](../fWarrangeCli/Models/MatchType.swift), [`WindowCaptureService.swift`](../fWarrangeCli/Services/WindowCaptureService.swift)
