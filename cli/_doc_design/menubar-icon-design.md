---
name: menubar-icon-design
description: cliApp 메뉴바 아이콘 자동 전환 설계 — paidApp 실행 상태에 따라 아이콘 교체
date: 2026-04-20
---

# 개요

cliApp(fWarrangeCli) 메뉴바 아이콘을 paidApp(fWarrange) 실행 상태에 따라 자동 전환하는 메커니즘 설계.
paidApp 실행 중: paidApp 앱 아이콘(컬러) 표시. paidApp 미실행: cliApp 자체 아이콘(clipped rectangle.3.group, 흑백 template) 표시.
paidApp 코드 변경 없이 cliApp이 NSWorkspace 이벤트를 자체적으로 구독하여 아이콘 전환을 주도함.

# 관련 자료

* [cliApp_design.md](cliApp_design.md) — cliApp 전체 아키텍처 설계
* [paidApp_version.md](paidApp_version.md) — paidApp ↔ cliApp 연동 설계 (Bundle ID 규약, 배포 경로 매트릭스)
* [RestAPI_v2.md](RestAPI_v2.md) — REST API v2 설계 (paidApp register API 포함)

# 설계

## 상태 모델

PaidAppMonitor가 paidApp 실행 상태를 추적함. AppState가 이를 구독하여 아이콘을 전환함.

```
PaidAppMonitor.state: PaidAppState
    .cliOnly         → cliApp 아이콘 (clipped rectangle.3.group, isTemplate = true)
    .paidAppActive   → paidApp 아이콘 (NSRunningApplication.icon, isTemplate = false)
```

## 아이콘 생성 로직

| 상태           | 생성 함수                        | 소스                                     | renderingMode |
| :------------- | :------------------------------- | :--------------------------------------- | :------------- |
| `.cliOnly`     | `AppState.makeCLIIcon()`         | SF Symbol `rectangle.3.group` + 대각선 클리핑 | `.template`    |
| `.paidAppActive` | `AppState.makePaidAppIcon(from:)` | `NSRunningApplication.icon` 18×18 리사이즈 | `.original`    |

### cliApp 아이콘 클리핑 방식

`rectangle.3.group` 심볼을 아래 대각선으로 클리핑하여 "진행 중" 상태를 암시:

```
clip path:
  (0, height) → (width, height) → (width, height*0.4) → (0, 0) → close
```

isTemplate = true → 시스템 다크/라이트 모드 자동 적응.

### paidApp 아이콘 리사이즈

`NSRunningApplication.icon`은 다중 해상도 NSImage. `NSImage(size:)` + `lockFocus/unlockFocus`로 18×18 고정 크기로 렌더링. isTemplate = false → 컬러 유지.

## 상태 변화 감시 (`startObservingMenuBarIcon`)

`withObservationTracking` 재귀 패턴으로 `paidAppMonitor.state` 변화 구독:

```swift
private func startObservingMenuBarIcon() {
    func observe() {
        withObservationTracking {
            let state = paidAppMonitor.state
            // menuBarIcon / menuBarIconIsTemplate 갱신
        } onChange: {
            Task { @MainActor [weak self] in
                self?.startObservingMenuBarIcon()  // 재귀 재등록
            }
        }
    }
    observe()
}
```

`initialize()` 내 `paidAppMonitor.startObserving()` 직후 호출 → 초기 상태도 즉시 반영.

## MenuBarExtra 동적 바인딩 (`fWarrangeCliApp.swift`)

```swift
} label: {
    Image(nsImage: appState.menuBarIcon)
        .renderingMode(appState.menuBarIconIsTemplate ? .template : .original)
}
```

`appState`는 `@Observable` → `menuBarIcon` 변경 시 SwiftUI가 자동 재렌더링.

## 트리거 커버리지

| 트리거                            | 아이콘 전환 경로                                                          |
| :-------------------------------- | :----------------------------------------------------------------------- |
| paidApp 수동 실행                 | NSWorkspace `didLaunchApplicationNotification` → PaidAppMonitor → `.paidAppActive` |
| CLIAutoLaunchService 자동 실행    | `open` 명령 → 동일 NSWorkspace 알림                                      |
| paidApp `/paidapp/register` API 호출 | 이미 NSWorkspace 알림으로 커버. 별도 트리거 불필요                       |
| paidApp 정상 종료                 | NSWorkspace `didTerminateApplicationNotification` → `.cliOnly`            |
| paidApp `kill -9` 강제 종료       | PaidAppMonitor가 NSWorkspace fallback으로 감지 → `.cliOnly`              |
| cliApp 재시작 (paidApp 실행 중)   | `PaidAppMonitor.init()`에서 현재 실행 중인 paidApp 탐색 → 초기 상태 `.paidAppActive` |

# 설계 결정 요약

* **cliApp-driven 채택**: paidApp 수정 없이 cliApp이 NSWorkspace 이벤트를 자체 구독. crash·강제 종료 포함 모든 종료 케이스를 커버함
* **renderingMode 이중화**: cliApp 아이콘은 `.template`(시스템 색상 적응), paidApp 아이콘은 `.original`(컬러 유지). 단일 `Image` 뷰에서 `menuBarIconIsTemplate` 플래그로 분기
* **아이콘 크기 18×18 고정**: `NSRunningApplication.icon`은 다중 해상도 이미지이므로 명시 리사이즈 필수. MenuBarExtra 표준 크기(18pt)에 맞춤
* **`makeMenuBarIcon()` AppState 이관**: 기존 `fWarrangeCliApp` private static 메서드를 `AppState.makeCLIIcon()` / `AppState.makePaidAppIcon()` public static으로 이관. 아이콘 로직 단일 위치 관리

# 변경 이력 기준

* 본 문서는 2026-04-20 작성. 이전 이력은 `git log -- cli/_doc_design/menubar-icon-design.md` 참조
* PaidAppMonitor 상태 모델 변경(예: 상태 추가) 시 본 문서 "상태 모델" 섹션 직접 갱신
* 아이콘 생성 로직 변경(크기, 클리핑 경로) 시 본 문서 "아이콘 생성 로직" 섹션 갱신
* paidApp Bundle ID 변경 시 본 문서 및 `paidApp_version.md` 동반 갱신
