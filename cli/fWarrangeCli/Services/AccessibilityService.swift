import Foundation
import AppKit

// MARK: - 프로토콜

/// Issue96: `requestAccessibility()`(내부 `kAXTrustedCheckOptionPrompt: true`) 를 의도적으로
/// 두지 않는다. 시스템 프롬프트는 **이미 실행 중인 프로세스에는 효과가 없어** 창만 반복해서
/// 뜨고 권한은 그대로다(prj25 Issue222~227 에서 네 라운드에 걸쳐 확인된 함정).
/// 운영 중 권한이 사라졌을 때의 유일한 복구 경로는 재시작이며,
/// 그 안내는 `AccessibilityGuidePresenter.showPermissionLost()` 가 담당한다.
protocol AccessibilityService {
    func isAccessibilityGranted() -> Bool
    func openAccessibilitySettings()
}

// MARK: - Issue104: 부팅 시 목록 등록 요청 (prj25 Issue237 이식)

/// 미승인으로 부팅한 **새 프로세스**가 시스템 권한 요청(`prompt: true`)을 1회 보내
/// 손쉬운 사용 목록에 스스로 올라가게 한다.
///
/// 위 Issue96 주석의 *"프롬프트는 효과가 없다"* 는 **이미 실행 중인 프로세스**에 대한 것이고,
/// `AppState` 의 *"ad-hoc 서명에서는 시스템 프롬프트 무효"* 는 서명이 Apple Development
/// 인증서로 바뀌기 전의 전제다. 부팅 직후의 새 프로세스에서는 macOS 가 앱을 목록에 추가한다.
/// 이 경로가 없어 jma 에서 사용자가 매번 목록에 수동 추가했다(2026-09-27).
///
/// 경계 — Issue96 결정은 유지한다: **부팅 1회만**, 승인 상태면 묻지 않음, 운영 중 재호출 없음.
enum AccessibilityBootListing {

    /// - Returns: 목록 등록 요청을 보냈으면 `true`
    @discardableResult
    static func runIfNeeded(isGranted: () -> Bool, requestListing: () -> Void) -> Bool {
        guard !isGranted() else { return false }
        requestListing()
        return true
    }

    /// 시스템 권한 요청 — macOS 가 앱을 목록에 추가하고 안내 창을 띄운다.
    static func requestSystemListing() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// MARK: - 구현체

final class SystemAccessibilityService: AccessibilityService {

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
