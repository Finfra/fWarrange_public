import Foundation
import AppKit

// MARK: - 프로토콜

protocol AccessibilityService {
    func isAccessibilityGranted() -> Bool
    func requestAccessibility()
}

// MARK: - 구현체

final class SystemAccessibilityService: AccessibilityService {

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
