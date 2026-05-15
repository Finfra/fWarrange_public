import Foundation
import AppKit

// MARK: - 비공개 API 바인딩
// WindowCaptureService, WindowRestoreService에서 공통 사용

@_silgen_name("_AXUIElementGetWindow")
nonisolated func _AXUIElementGetWindow(_ element: AXUIElement, _ id: inout CGWindowID) -> AXError

// MARK: - Issue72_6 (Phase 6): CGSSpace 비공개 API
// macOS 비공개 SkyLight/CoreGraphics 심볼. App Store 영향 없음 (cliApp non-sandbox).
// 폐기·시그니처 변경 시 nil fallback 안전망 보유.

/// 현재 활성 Space ID (workspace switching 시 변경됨).
@_silgen_name("CGSMainConnectionID")
nonisolated func _CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
nonisolated func _CGSGetActiveSpace(_ cid: Int32) -> UInt64

/// CGWindowID 배열의 각 창이 속한 Space ID 배열 반환.
/// Mission Control·풀스크린 창 식별용.
@_silgen_name("CGSCopySpacesForWindows")
nonisolated func _CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> Unmanaged<CFArray>?

/// SpaceId 추출 헬퍼.
/// - 단일 cgWindowID에 대한 Space ID. 비공개 API 실패 시 nil 반환 (안전 폴백).
nonisolated func _spaceIdForCGWindowID(_ wid: CGWindowID) -> Int? {
    let cid = _CGSMainConnectionID()
    let widsArray = [wid] as CFArray
    // mask: 0x7 = include all spaces (active + others + visible)
    guard let cfArray = _CGSCopySpacesForWindows(cid, 0x7, widsArray)?.takeRetainedValue() else {
        return nil
    }
    let count = CFArrayGetCount(cfArray)
    guard count > 0 else { return nil }
    // 첫 번째 결과 (Space ID는 UInt64이지만 CFNumber로 packing)
    if let nsArray = cfArray as? [Any], let first = nsArray.first as? NSNumber {
        return first.intValue
    }
    return nil
}
