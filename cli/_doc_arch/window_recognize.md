---
name: window_recognize
description: 창 인식(매칭) 원리 정리 및 Issue72 인식률 개선 구현 현황 설계 문서
date: 2026-06-15
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

# 구현 현황 (Implementation Status)

> 본 섹션은 과거 "토의 항목"으로 작성되었으나, **대부분 Issue72 Phase 2~7에서 이미 구현(SHIPPED)됨**. 아래 표는 각 항목을 코드 검증 결과로 **구현됨 / 미해결(OPEN)** 으로 재분류한 것임. (검증일 2026-06-15)

## SHIPPED — 이미 구현된 기능

### S1. 타이틀 정규화 룰셋 (Phase 3) — 구현됨

* **서비스**: [`TitleNormalizer.swift`](../fWarrangeCli/Services/TitleNormalizer.swift) — 프로토콜 `TitleNormalizer` + 구현체 `FileTitleNormalizer`
* **빌트인 Top-10 룰**: [L284–304](../fWarrangeCli/Services/TitleNormalizer.swift#L284) — Safari/Chrome/Edge/Firefox/VSCode/Cursor/Slack/iTerm2/Terminal/Xcode. `stripPrefix`·`stripSuffix`·`stripPattern`(ICU regex) 적용 순서로 동적 타이틀 흡수
* **주입**: 캡처([`CGWindowCaptureService(titleNormalizer:)`](../fWarrangeCli/AppState.swift#L67))·복구([`AXWindowRestoreService(titleNormalizer:)`](../fWarrangeCli/AppState.swift#L69)) 양쪽이 **동일 인스턴스 공유** → 캡처·복구 정규화 대칭 보장. 복구 시 비교는 [`computeMatchScore` L459–462](../fWarrangeCli/Services/WindowRestoreService.swift#L459)에서 `axTitle` 정규화 후 `target.window`와 비교
* **사용자 편집본**: `~/Library/Application Support/fWarrangeCli/title_normalize.yml` (env `fWarrangeCli_normalize_path`로 재정의). 파일 존재 시 빌트인 무시
* **REST CRUD**: `GET/PUT/DELETE /api/v2/normalize-rules` ([`RESTServer.swift` L901–932](../fWarrangeCli/Services/RESTServer.swift#L901)). PUT=전체 교체, DELETE=빌트인 리셋. paidApp이 편집 UI 제공 (역할 분담 = Q5 답)

### S2. 저장 스냅샷 강화 — windowOrder / displayUUID / spaceId / originURL (Phase 2·6) — 구현됨

[`WindowInfo.swift`](../fWarrangeCli/Models/WindowInfo.swift)에 옵셔널 필드로 모두 추가됨 (구 yml 호환):

| 필드          | 라인                                                                | 용도                                              |
| :------------ | :------------------------------------------------------------------ | :------------------------------------------------ |
| `windowOrder` | [L27](../fWarrangeCli/Models/WindowInfo.swift#L27)                   | 동일 앱 z-order index. Moom 폴백 배분 정렬에 사용 |
| `displayUUID` | [L30](../fWarrangeCli/Models/WindowInfo.swift#L30)                   | 디스플레이 영구 UUID                              |
| `spaceId`     | [L41](../fWarrangeCli/Models/WindowInfo.swift#L41)                   | Space ID (매칭 가산점)                            |
| `originURL`   | [L45](../fWarrangeCli/Models/WindowInfo.swift#L45)                   | PWA 분리 식별 키                                  |
| `windowRaw`   | [L33](../fWarrangeCli/Models/WindowInfo.swift#L33)                   | 정규화 전 원본 axTitle (추적용)                   |

* `originURL`은 **캡처 와이어링도 존재**: [`WindowCaptureService.swift` L120–142](../fWarrangeCli/Services/WindowCaptureService.swift#L120) — Chrome 계열 한정 `--app=URL` 추출, PID별 캐시. YAML 직렬화·파싱도 [`LayoutStorageService.swift` L195–282](../fWarrangeCli/Services/LayoutStorageService.swift#L195)에 존재. (단 Chrome 계열만 — 그 외 브라우저 PWA는 미커버, 아래 OPEN 참조)

### S3. strict / normal / loose 매칭 모드 (Phase 5) — 구현됨 (구 Q4 답)

* **enum + 정책**: [`MatchMode.swift`](../fWarrangeCli/Models/MatchMode.swift) — `MatchMode`(strict/normal/loose) + `RuntimeMatchPolicy`. 모드별 `minimumScore`: **strict=70(containsTitle 이상), normal=설정값(기본 30), loose=30** ([L47–73](../fWarrangeCli/Models/MatchMode.swift#L47))
* **REST 파라미터**: `POST /api/v2/layouts/{name}/restore` 의 `mode` 필드를 [`RESTServer.swift:1395`](../fWarrangeCli/Services/RESTServer.swift#L1395) `MatchMode.parse(...)`로 파싱. 핸들러 시그니처에도 `mode: MatchMode` 포함 ([L23](../fWarrangeCli/Services/RESTServer.swift#L23))
* **per-window override**: 특정 창만 `WindowInfo.matchMode` 명시 시 그 창 한정 정책 교체 ([`WindowRestoreService.swift` L567–577](../fWarrangeCli/Services/WindowRestoreService.swift#L567))
* → 과거 Q4("strict vs loose 미해결")는 **틀림**. 이미 구현됨

### S4. Spaces / spaceId 스코어링 (Phase 6) — 구현됨 (구 Q3 답)

* **비공개 API**: [`AXPrivateAPI.swift` L15–42](../fWarrangeCli/Utils/AXPrivateAPI.swift#L15) — `_CGSMainConnectionID`·`_CGSGetActiveSpace`·`_CGSCopySpacesForWindows` 바인딩 + `_spaceIdForCGWindowID(_:)` 헬퍼 (실패 시 nil 안전 폴백)
* **점수 가산**: [`computeMatchScore` L531–536](../fWarrangeCli/Services/WindowRestoreService.swift#L531) — `target.spaceId`와 실제 창 Space 일치 시 **+3점**(상한 99). 다른 Space 동명 창 구분
* → 과거 Q3("Spaces 완전 미시도")는 **틀림**. 비공개 API 도입 완료

### S5. distance·spaceId 점수 가산 (Phase 4·6) — 구현됨 (단순 tie-break 아님)

* **distance 가산점**: [`computeMatchScore` L523–526](../fWarrangeCli/Services/WindowRestoreService.swift#L523) — distance 0px→+9, 900px+→0. 카테고리 점수에 **가산**(상한 9, 경계 보존). 과거 문서의 "distance는 tie-break 용도로만" 서술은 **STALE**
* spaceId +3은 S4 참조. 즉 최종 점수 = 카테고리(100/90/…) + distance보너스(0~9) + spaceId보너스(0/3)

### S6. Moom 스타일 최후 폴백 (Phase 5) — 구현됨

* [`WindowRestoreService.swift` L354–397](../fWarrangeCli/Services/WindowRestoreService.swift#L354) — `moomFallbackEnabled`(loose 모드 전용). 매칭 실패한 target을 앱별 그룹핑, **살아있는 창 개수가 같으면** `windowOrder` 오름차순으로 위치 배분. `matchType=.noMatch`, title=`(moom-fallback)`

### S7. 1:N 매칭 (Stay 스타일, Phase 5) — 구현됨

* [`MatchMode.swift:71`](../fWarrangeCli/Models/MatchMode.swift#L71) `allowMultipleAssignments`(loose 전용). 적용: [`findOptimalMatches` L604](../fWarrangeCli/Services/WindowRestoreService.swift#L604) — true 시 한 axWindow가 여러 target에 매칭 가능

### S8. areaMatch(30점) 토글 (Phase 4) — 구현됨 (구 "비활성화 검토"는 STALE)

* 설정: [`AppSettings.matchAreaMatchEnabled`](../fWarrangeCli/Models/AppSettings.swift#L131) (기본 [true L190](../fWarrangeCli/Models/AppSettings.swift#L190))
* 주입: [`AXWindowRestoreService(areaMatchEnabled:)`](../fWarrangeCli/AppState.swift#L69) → [`computeMatchScore` L509 게이트](../fWarrangeCli/Services/WindowRestoreService.swift#L509). false 시 30점 매칭이 `.noMatch`로 분류
* → "비활성화 검토" 토의는 **이미 토글 존재**. 베이스라인 통계 보고 끄면 됨

### S9. dryRun / interactive preview (Phase 7-1) — 구현됨 (과거 문서 누락 — 신규 기재)

* 프로토콜 인자 [`dryRun` L68](../fWarrangeCli/Services/WindowRestoreService.swift#L68). true 시 매칭만 시뮬레이션하고 적용·검증·Moom 폴백 스킵 ([병렬 L212–216](../fWarrangeCli/Services/WindowRestoreService.swift#L212), [순차 L296–301](../fWarrangeCli/Services/WindowRestoreService.swift#L296), [Moom 가드 L358](../fWarrangeCli/Services/WindowRestoreService.swift#L358))
* 결과는 `success=false` + `matchedTitle="(dry-run) ..."`. paidApp interactive 다이얼로그가 후보를 미리 보여주기 위한 사전 조회 용도

### S10. 측정 인프라 (Phase 1) — 구현됨 (구 "측정만 추가하면 됨"은 STALE)

* **모델·수집기**: [`Models/RestoreStats.swift`](../fWarrangeCli/Models/RestoreStats.swift) + [`Services/RestoreStatsCollector.swift`](../fWarrangeCli/Services/RestoreStatsCollector.swift) (`actor JSONRestoreStatsCollector`, 디스크 영속). [`AppState.swift:79`](../fWarrangeCli/AppState.swift#L79)에서 조립, `WindowManager`가 매칭 결과 push
* **REST**: `GET /api/v2/restore-stats`(스냅샷) / `DELETE`(베이스라인 재시작) ([`RESTServer.swift` L883–895](../fWarrangeCli/Services/RESTServer.swift#L883))
* → 과거 "집계 스크립트만 추가하면 됨"은 **완료됨**

## OPEN — 진짜 미해결 (재검증 후에도 유효)

### O1. 완전한 가중 합산 점수 (weighted-sum) — 미구현

* 현재는 **카테고리 선택형 + 가산 보너스**(distance 0~9, spaceId 0/3)만 존재. 각 시그널을 0~1로 환산해 가중치 합산하는 **완전 가중합 모델**은 아님
* 가산 보너스 상한(9·3)을 카테고리 경계 미만으로 묶어 "선택형"을 유지 중. 진짜 가중합으로 전환하려면 임계값·카테고리 의미 재정의 필요 (열린 설계 결정)

### O2. PWA `originURL` 캡처 커버리지 — 부분 구현

* 필드·캡처·직렬화는 존재(S2)하나 **Chrome 계열(`--app=`)만 추출**. Safari Web App, Edge PWA, Electron 변종 등은 미커버
* 또한 추출된 `originURL`을 **매칭 점수에 반영하는 로직은 아직 약함** — 식별 키로 저장은 되나 PWA 분리 매칭의 전면 활용은 추가 작업 필요

### O3. dryRun 이상의 사용자 개입 UI — 미구현 (paidApp 영역)

* cliApp 측 dryRun 사전조회(S9)는 완료. 그러나 paidApp의 **"이 창이 맞나요?" 후보 제시 + 선택 결과 학습** 다이얼로그는 미구현
* 학습 데이터로 가중치 자동 조정하는 피드백 루프도 미구현 (O1과 연동)

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

# Issue72 Phase 이력 (Shipped Changelog)

> 본 문서는 과거 "3-Track 토론 + 진행 권장 순서"로 작성되었으나, 그 순서표는 **실제로 Issue72 Phase 1~7으로 구현 완료**됨. 아래는 그 순서표를 구현 결과로 재기술한 changelog. (각 항목 코드 검증은 위 「구현 현황」 섹션 참조)

| Phase | 작업                                            | 산출물 (구현됨)                                                     | 검증 위치 (위 섹션) |
| :---- | :---------------------------------------------- | :----------------------------------------------------------------- | :------------------ |
| 1     | 측정 인프라 + 베이스라인 통계                   | `RestoreStats` + `RestoreStatsCollector`, REST `/restore-stats`    | S10                 |
| 2     | windowOrder + displayUUID + windowRaw 캡처      | `WindowInfo` 옵셔널 필드, YAML 직렬화                              | S2                  |
| 3     | 빌트인 타이틀 정규화 룰셋(Top 10) + REST CRUD   | `TitleNormalizer`, `title_normalize.yml`, `/normalize-rules`       | S1                  |
| 4     | distance 가산점 + areaMatch 토글                | `computeMatchScore` 보너스, `matchAreaMatchEnabled`               | S5, S8              |
| 5     | strict/normal/loose 모드 + 1:N + Moom 폴백      | `MatchMode`/`RuntimeMatchPolicy`, REST `mode`, per-window override | S3, S6, S7          |
| 6     | spaceId 스코어링 + originURL(PWA) 캡처          | `AXPrivateAPI` CGS*, spaceId +3 가산, Chrome `--app=` 추출         | S4, S2, O2          |
| 7     | dryRun / interactive preview 사전조회           | `dryRun` 인자, `(dry-run)` 결과 표시                              | S9                  |

## 남은 작업 (위 「OPEN」 섹션과 동일)

* **O1**: 완전한 가중 합산 점수 — 현재는 카테고리 선택형 + 가산 보너스(distance/spaceId)만. 진짜 weighted-sum 전환은 미착수
* **O2**: PWA `originURL` 커버리지 — Chrome 계열만. 타 브라우저 PWA·매칭 점수 전면 반영 미완
* **O3**: dryRun 너머의 사용자 개입 UI — paidApp 후보 다이얼로그·학습 피드백 루프 미구현

# 참고

* [`cli/_doc_arch/cliApp_design.md`](cliApp_design.md) — cliApp 전체 아키텍처
* [`fWarrange/.claude/rules/window-rules.md`](../../../fWarrange/.claude/rules/window-rules.md) — 점수표 SSOT (paidApp 측)
* [`fWarrange/.claude/rules/coding-rules.md`](../../../fWarrange/.claude/rules/coding-rules.md) §5 — 매칭 임계값·허용오차
* 코드: [`WindowRestoreService.swift`](../fWarrangeCli/Services/WindowRestoreService.swift), [`MatchType.swift`](../fWarrangeCli/Models/MatchType.swift), [`WindowCaptureService.swift`](../fWarrangeCli/Services/WindowCaptureService.swift)
