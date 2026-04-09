import Foundation
import AppKit

// MARK: - 비공개 API 바인딩
// WindowCaptureService, WindowRestoreService에서 공통 사용

@_silgen_name("_AXUIElementGetWindow")
nonisolated func _AXUIElementGetWindow(_ element: AXUIElement, _ id: inout CGWindowID) -> AXError
