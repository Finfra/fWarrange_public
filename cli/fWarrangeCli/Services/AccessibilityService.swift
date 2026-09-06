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
