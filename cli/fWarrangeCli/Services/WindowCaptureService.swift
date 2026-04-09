import Foundation
import CoreGraphics
import AppKit

// MARK: - 프로토콜

protocol WindowCaptureService {
    func captureWindows(filterApps: [String]?) -> [WindowInfo]
    func runningAppNames() -> [String]
}

// MARK: - 구현체

final class CGWindowCaptureService: WindowCaptureService {

    func captureWindows(filterApps: [String]?) -> [WindowInfo] {
        guard let windowListInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        // 현재 실행 중인 UI 활성화 앱(.regular)의 PID 목록
        // (이름 기반 매칭 시 CGWindowList의 ownerName과 NSWorkspace의 localizedName 불일치 문제 방지)
        let regularAppPIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { $0.processIdentifier })

        // Accessibility API로 실제 창 제목 조회 (CGWindowID → 제목 매핑)
        let axTitleMap = buildAXTitleMap()

        var results: [WindowInfo] = []

        for dict in windowListInfo {
            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let cgWindowName = dict[kCGWindowName as String] as? String
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let windowId = dict[kCGWindowNumber as String] as? Int ?? 0

            // AX 제목 우선, CG 이름 fallback
            let windowName = axTitleMap[CGWindowID(windowId)] ?? cgWindowName ?? "No Name"

            // 1. 사용자 지정 필터(filterApps)가 존재하면 해당 앱만 캡처
            if let apps = filterApps, !apps.contains(ownerName) {
                continue
            }

            // 2. 실체가 안 보이는 앱 필터링 (정규 UI 앱만 캡처, PID 기반)
            if ownerPID != 0 && !regularAppPIDs.contains(ownerPID) {
                continue
            }

            guard let bounds = dict[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            let x = bounds["X"] as? CGFloat ?? 0
            let y = bounds["Y"] as? CGFloat ?? 0
            let width = bounds["Width"] as? CGFloat ?? 0
            let height = bounds["Height"] as? CGFloat ?? 0

            // 3. 비정상 창 필터링 (최소 크기 50x50 미만 제외)
            if width < 50 || height < 50 {
                continue
            }

            let info = WindowInfo(
                id: windowId,
                app: ownerName,
                window: windowName,
                layer: layer,
                pos: WindowPosition(x: x, y: y),
                size: WindowSize(width: width, height: height)
            )
            results.append(info)
        }

        return results
    }

    // MARK: - Accessibility API 창 제목 조회

    /// 실행 중인 앱의 AX 창 목록에서 CGWindowID → 실제 창 제목 매핑을 생성합니다.
    private func buildAXTitleMap() -> [CGWindowID: String] {
        var map: [CGWindowID: String] = [:]
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }

        for app in apps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 1.0)

            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            guard result == .success, let axWindows = value as? [AXUIElement] else { continue }

            for axWindow in axWindows {
                var cgWindowId: CGWindowID = 0
                _ = _AXUIElementGetWindow(axWindow, &cgWindowId)

                if cgWindowId != 0 {
                    var titleValue: CFTypeRef?
                    AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
                    if let title = titleValue as? String, !title.isEmpty {
                        map[cgWindowId] = title
                    }
                }
            }
        }
        return map
    }

    func runningAppNames() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .filter { !$0.isEmpty }
            .sorted()
    }
}
