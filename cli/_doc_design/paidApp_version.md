---
name: paidApp_version
description: cliApp의 paidApp 인식 및 실행 절차 설계 문서
date: 2026-04-08
---

# 개요

cliApp(무료 helper daemon)이 paidApp(유료 App Store 앱)을 인식하고 연동하는 절차를 정의함.

* **cliApp**: 메뉴바 에이전트, REST API 서버, 창 캡처/복구 데몬
* **paidApp**: App Store 배포 Sandbox GUI 앱 (유료)
* **관계**: cliApp은 독립 실행 가능하되, paidApp 설치 시 GUI 기능을 위임함

# 기능 명세 (Free vs Paid)

cliApp(Free)과 paidApp(Paid)의 기능 경계를 정의함. paidApp 미설치 시 Free 기능만 동작하며, Paid 기능 호출 시 `showPaidOnlyAlert`로 안내함.

## Free 기능 (cliApp 단독 제공)

> ※ REST API 엔드포인트는 v1(`/api/v1`)·v2(`/api/v2`) 양쪽에서 제공됨 (v2는 v1 슈퍼셋). 아래 표는 v1 표기 기준.

| 카테고리        | 기능                                    | 비고                                  |
| :-------------- | :-------------------------------------- | :------------------------------------ |
| 창 캡처         | 현재 창 레이아웃을 YAML로 저장          | `POST /api/v1/capture`                |
| 창 복구         | 저장된 레이아웃으로 창 위치/크기 복구   | `POST /api/v1/layouts/{name}/restore` |
| 레이아웃 CRUD   | 목록 조회/삭제/이름 변경                | `GET/DELETE/PATCH /api/v1/layouts`    |
| REST API        | `localhost:3016/api/v1` 전체 엔드포인트 | 외부 자동화 도구 연동 가능            |
| 글로벌 단축키   | 캡처/복구 HotKey                        | `HotKeyService`                       |
| 메뉴바 에이전트 | 최소 메뉴(About/Quit 등)                | `MenuBarExtra`                        |
| 화면 이동       | 창을 지정 화면으로 이동                 | `ScreenMoveService`                   |
| 자동 실행 관리  | `LaunchAtLogin` 토글 UI                 | Settings 시트                         |

## Paid 기능 (paidApp 설치 시 제공)

| 카테고리           | 기능                                          | 진입점                          |
| :----------------- | :-------------------------------------------- | :------------------------------ |
| Settings GUI       | 앱 설정 시트(단축키/경로/자동 실행 등)         | MenuBarView → Settings 버튼     |
| Management Window  | 레이아웃 목록/미리보기/편집 GUI                | MenuBarView → Management Window |
| 레이아웃 시각 편집 | 창 매칭 규칙/순서/필터를 GUI로 편집           | Management Window               |
| 디스플레이 프리뷰  | 저장된 레이아웃을 화면 배치로 시각화          | Management Window               |
| App Store 배포     | Sandbox 호환, 자동 업데이트, 서명/공증        | Bundle ID `kr.finfra.fWarrange` |

## 상호 의존성

* cliApp은 **단독 실행 가능** — paidApp이 없어도 REST/HotKey/캡처/복구 전부 동작
* paidApp은 내부적으로 `RESTCLIClient`로 cliApp REST API를 호출하여 작업 수행 (GUI는 Paid, 엔진은 Free)
* Paid 기능 = "GUI 편의성"이며, 핵심 엔진 로직은 Free에 포함됨

# Bundle ID

| 앱       | Bundle ID                | Sandbox |
| :------- | :----------------------- | :-----: |
| paidApp  | `kr.finfra.fWarrange`    | ✅      |
| cliApp   | `kr.finfra.fWarrangeCli` | ❌      |

# paidApp 감지 (`detectPaidApp`)

## 검색 경로

명시적 파일 경로에서만 검색함. `NSWorkspace.urlForApplication(withBundleIdentifier:)` 미사용.

```swift
private static let paidAppSearchPaths = [
    "/Applications/fWarrange.app",
    "/Applications/_nowage_app/fWarrange.app",
    "/Applications/_finfra_app/fWarrange.app"
]
```

## 검색 로직

```
for path in paidAppSearchPaths:
    if FileManager.fileExists(path):
        return URL(path)    // 첫 번째 발견 시 즉시 반환
return nil                  // 미발견
```

## 설계 결정

* `NSWorkspace.urlForApplication(withBundleIdentifier:)` 제외 이유: `~/Library/Developer/Xcode/DerivedData/` 빌드 결과물까지 감지하여 개발 환경에서 오작동 발생
* `FileManager.fileExists` 사용: 실제 설치 경로만 확인, 빠르고 예측 가능

# 앱 시작 시 자동 실행 흐름 (Issue10)

cliApp 시작 시 paidApp이 감지되면 자동 실행하고 메뉴바에서 제거됨.

```
cliApp 시작
    │
    ├─ AppState.initialize()
    │   │
    │   ├─ detectPaidApp() → URL?
    │   │   ├─ 발견: launchPaidApp() 호출
    │   │   │   ├─ NSWorkspace.shared.open(url)
    │   │   │   ├─ 성공 → hideMenuBar = true
    │   │   │   │   └─ 메뉴바 아이콘 제거, REST 서버는 유지
    │   │   │   └─ 실패 → hideMenuBar 유지(false), 메뉴바 표시
    │   │   └─ 미발견: 아무 동작 없음, 메뉴바 표시
    │   │
    │   ├─ layoutManager.loadMetadataList()
    │   ├─ restServer.start(port: 3016)      ← 항상 실행
    │   ├─ hotKeyService.register()
    │   ├─ syncLaunchAtLogin()
    │   └─ observePaidAppTermination()       ← 종료 감시 등록
    │
    └─ MenuBarExtra(isInserted: !hideMenuBar)
        └─ hideMenuBar=true이면 메뉴바 아이콘 비표시
```

## 핵심 원칙

* **REST 서버는 항상 유지**: paidApp 실행 여부와 무관하게 `localhost:3016` REST API 활성화
* **메뉴바만 숨김**: `hideMenuBar` 플래그로 `MenuBarExtra(isInserted:)` 제어
* **앱 프로세스는 유지**: `NSApplication.terminate()` 호출하지 않음

# paidApp 종료 실시간 감시 (`observePaidAppTermination`)

paidApp 프로세스가 종료되면 메뉴바를 자동 복원하여 사용자가 cliApp 독립 기능(Quit/About 등)에 접근할 수 있게 함.

실제 구현은 `AppState.observePaidAppTermination()` (`AppState.swift`):

```swift
private func observePaidAppTermination() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let self else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "kr.finfra.fWarrange" else { return }
        Task { @MainActor in
            if self.hideMenuBar {
                self.hideMenuBar = false   // 메뉴바 복원
                logI("🔄 fWarrange 종료 감지 → 메뉴바 자동 복원")
            }
        }
    }
}
```

## 상태 전환 요약

| paidApp 상태        | cliApp 메뉴바       | 동작 주체                      |
| :------------------ | :------------------ | :----------------------------- |
| 감지됨 (시작 시)    | 숨김                | `initialize()` → `launchPaidApp` |
| 미감지 (시작 시)    | 표시                | 기본값 (독립 모드)             |
| 종료 감지           | 복원                | `observePaidAppTermination`    |

## 설계 결정

* **launch 감지 미등록**: 시작 시점에만 1회 감지/실행하는 정책. 앱 실행 도중 paidApp이 별도 경로로 실행되는 케이스는 다음 재시작 때 반영되므로 실시간 launch 감시는 생략
* **weak self**: 옵저버 클로저에서 `[weak self]` 사용하여 retain cycle 방지

# 메뉴바 버튼 연동 (Issue9)

메뉴바에서 Paid 전용 기능 버튼 클릭 시의 분기 처리.

## 버튼 목록

| 버튼               | Paid 필요 | 동작                                       |
| :----------------- | :-------: | :----------------------------------------- |
| About fWarrangeCli | ❌        | 항상 활성화, 버전/빌드 정보 표시           |
| Settings           | ✅        | Paid 감지 → paidApp 실행, 미감지 → 알림    |
| Management Window  | ✅        | Paid 감지 → paidApp 실행, 미감지 → 알림    |

## 버튼 클릭 흐름 (`tryLaunchPaidFeature`)

```
버튼 클릭 (Settings / Management Window)
    │
    ├─ detectPaidApp() → URL?
    │   ├─ 발견:
    │   │   ├─ launchPaidApp() → NSWorkspace.open(url)
    │   │   ├─ 성공 → 안내 알림 표시: "fWarrange launched"
    │   │   └─ 실패 → false 반환
    │   └─ 미발견: false 반환
    │
    └─ false 반환 시 → showPaidOnlyAlert()
        ├─ [App Store] → macappstore:// URL 열기
        ├─ [Locate...] → NSOpenPanel으로 fWarrange.app 수동 선택
        │   └─ Bundle ID 검증 (kr.finfra.fWarrange) 후 실행
        └─ [Cancel] → 닫기
```

## Paid 미감지 시 알림 (`showPaidOnlyAlert`)

3개 버튼 제공:

* **App Store**: `macappstore://apps.apple.com/app/fwarrange/id6744105753` 열기
* **Locate...**: `NSOpenPanel`으로 사용자가 직접 fWarrange.app 선택
    - 선택 후 `Bundle(url:).bundleIdentifier == "kr.finfra.fWarrange"` 검증
    - 검증 실패 시 "Invalid application" 경고
* **Cancel**: 닫기

# 실행 중 감지 (`isPaidAppRunning`) — 미구현

> ⚠️ **현재 `AppState.swift`에 미구현.** 향후 UI 상태 표시(예: 메뉴바 아이콘 뱃지) 등이 필요해지면 아래 패턴으로 추가 가능.

```swift
// 참고용 의사 코드 — 실제 구현 시 AppState에 메서드로 추가
func isPaidAppRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains {
        $0.bundleIdentifier == "kr.finfra.fWarrange"
    }
}
```

# 메뉴바 아이콘 (Issue11)

cliApp과 paidApp을 시각적으로 구분하기 위해 아이콘에 대각선 클리핑 적용.

* SF Symbol: `rectangle.3.group`
* 클리핑: `NSBezierPath`로 왼쪽 하단 ~ 오른쪽 40% 높이 대각선 위쪽만 표시
* paidApp은 온전한 아이콘, cliApp은 잘린 아이콘으로 구분

# 관련 소스 파일

| 파일                        | 역할                                          |
| :-------------------------- | :-------------------------------------------- |
| `AppState.swift`            | `detectPaidApp`, `launchPaidApp`, `tryLaunchPaidFeature`, `observePaidAppTermination`, `hideMenuBar` |
| `fWarrangeCliApp.swift`     | `MenuBarExtra(isInserted:)` 바인딩, `makeMenuBarIcon` |
| `MenuBarView.swift`         | Settings/Management Window 버튼, `showPaidOnlyAlert` |

# 관련 이슈

| 이슈    | 내용                                         | 상태 |
| :------ | :------------------------------------------- | :--: |
| Issue9  | 메뉴바 Settings/Management Window/About 추가 | ✅   |
| Issue10 | Paid 감지 → 실행 후 메뉴바 제거              | ✅   |
| Issue11 | 메뉴바 아이콘 대각선 클리핑                  | ✅   |

# 향후 고려사항

* `paidAppSearchPaths`에 경로 추가 시 검색 순서 = 우선순위
* paidApp의 특정 창(설정/관리)을 직접 열어야 하는 경우 URL Scheme 또는 DistributedNotification 활용 필요
* `이슈후보`에 등록된 "paidApp_version.md에 따라 코드 삭제" 항목은 이 문서 기준으로 불필요한 Paid 관련 코드 정리를 의미
