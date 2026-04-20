---
name: design_accessibility-prompt
description: cliApp Accessibility 권한 요청 UX 개선 설계
date: 2026-04-17
---

# 배경

cliApp 처음 실행 시 macOS Accessibility 권한 요청 프롬프트가 자동으로 뜨지 않음.
사용자가 시스템 설정 > 개인정보 보호 > 접근성에서 직접 앱을 추가해야 하는 상황.

## 원인 분석

| 항목                      | 현재 (cliApp)                               | 정상 동작 조건                    |
| :------------------------ | :------------------------------------------ | :-------------------------------- |
| 코드 서명                 | Ad-hoc (`Signature=adhoc`)                  | Developer ID 또는 Apple Development |
| TeamIdentifier            | not set                                     | 유효한 Team ID 필요              |
| Hardened Runtime          | 미설정                                      | `ENABLE_HARDENED_RUNTIME: true`   |
| Accessibility entitlement | 없음                                        | 선택적 (non-sandbox 앱은 불필요) |
| 프롬프트 전략             | 시작 시 `prompt: true` (ad-hoc이라 무효)    | 상황별 분리 필요                  |

Ad-hoc 서명된 앱은 `AXIsProcessTrustedWithOptions(kAXTrustedCheckOptionPrompt: true)` 호출 시
macOS가 신뢰할 수 없는 서명으로 판단하여 프롬프트를 표시하지 않거나, 재빌드마다 CDHash가 변경되어
이전에 부여한 권한이 무효화됨.

## fSnippet (Project 15) 참조 구현

fSnippet은 동일한 문제를 3단계 전략으로 해결함:

```
앱 시작 → prompt:false 체크만 → 권한 없으면 NSAlert 안내 + 시스템 설정 deep link
설정 UI → prompt:true 버튼 (사용자 주도)
CLI     → prompt:false + 로그 안내만 (빌드마다 서명 변경 대응)
```

# 설계

## 적용 대상

cliApp (헬퍼 데몬, `cli/fWarrangeCli/`)

## 변경 사항

### 1. AccessibilityService 확장

[AccessibilityService.swift](../fWarrangeCli/Services/AccessibilityService.swift)

프로토콜에 시스템 설정 열기 메서드 추가:

```swift
protocol AccessibilityService {
    func isAccessibilityGranted() -> Bool
    func requestAccessibility()
    func openAccessibilitySettings()  // 신규
}
```

구현체 `SystemAccessibilityService`:

```swift
func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}
```

### 2. AppState.initialize() 권한 요청 로직 변경

[AppState.swift](../fWarrangeCli/AppState.swift) 라인 327-331

**Before:**
```swift
if !windowManager.isAccessibilityGranted() {
    logW("⚠️ Accessibility 권한이 필요합니다")
    windowManager.requestAccessibility()  // prompt:true → ad-hoc이라 무효
}
```

**After:**
```swift
if !windowManager.isAccessibilityGranted() {
    logW("⚠️ Accessibility 권한이 필요합니다")
    showAccessibilityGuide()  // NSAlert + 시스템 설정 열기
}
```

### 3. NSAlert 안내 다이얼로그

```swift
private func showAccessibilityGuide() {
    DispatchQueue.main.async { [weak self] in
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Accessibility 권한 필요"
        alert.informativeText = """
            fWarrangeCli가 창 위치를 제어하려면 접근성 권한이 필요합니다.

            시스템 설정 > 개인정보 보호 및 보안 > 접근성에서
            fWarrangeCli를 추가하고 허용해주세요.
            """
        alert.addButton(withTitle: "설정 열기")
        alert.addButton(withTitle: "나중에")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            self?.windowManager.openAccessibilitySettings()
        }
    }
}
```

### 4. project.yml Hardened Runtime 추가

[project.yml](../project.yml) 타겟 설정에 추가:

```yaml
targets:
  fWarrangeCli:
    settings:
      base:
        ENABLE_HARDENED_RUNTIME: true  # 신규
```

## 변경 파일 목록

| 파일                          | 변경 내용                                          |
| :---------------------------- | :------------------------------------------------- |
| `Services/AccessibilityService.swift` | `openAccessibilitySettings()` 메서드 추가  |
| `Managers/WindowManager.swift`        | `openAccessibilitySettings()` 전달 메서드  |
| `AppState.swift`                      | `requestAccessibility()` → NSAlert + deep link |
| `project.yml`                         | `ENABLE_HARDENED_RUNTIME: true` 추가       |

## 동작 흐름

```
cliApp 시작
    ↓
AppState.initialize()
    ↓
isAccessibilityGranted() 확인 (prompt: false)
    ↓
권한 없음 → showAccessibilityGuide()
    ↓
NSAlert 표시: "Accessibility 권한 필요"
    ├─ [설정 열기] → 시스템 설정 Accessibility 패널 deep link
    └─ [나중에] → 닫기 (REST 서버는 정상 가동, 권한 필요 기능만 제한)
```

## 고려사항

* cliApp은 `LSUIElement = true` (메뉴바 에이전트)이므로 Dock에 표시되지 않음
    - NSAlert는 정상 동작함 (`canBecomeKey` 가능)
* REST 서버는 권한 없이도 시작됨 — 캡처/복구 API 호출 시에만 권한 필요
* 재빌드마다 CDHash 변경 문제는 Hardened Runtime + 자체 서명 인증서로 완화 가능
    - 당장은 NSAlert 안내로 UX 개선, 향후 코드 서명 개선은 별도 이슈로 관리
