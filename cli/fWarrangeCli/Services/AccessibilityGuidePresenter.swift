import Foundation
import AppKit

/// Surfaces the Accessibility permission guide alert (Issue189).
/// Issue217 Phase 2: extracted from AppState. The caller injects the
/// `WindowManager` since opening the system settings is its responsibility.
enum AccessibilityGuidePresenter {
    static func show(windowManager: WindowManager) {
        DispatchQueue.main.async {
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
                Task { @MainActor in
                    windowManager.openAccessibilitySettings()
                }
            }
        }
    }
}
