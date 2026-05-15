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

    /// Issue72_3 (Phase 3): 타이틀 정규화 서비스 — 주입 없으면 원본 그대로 사용.
    private let titleNormalizer: TitleNormalizer?

    init(titleNormalizer: TitleNormalizer? = nil) {
        self.titleNormalizer = titleNormalizer
    }

    func captureWindows(filterApps: [String]?) -> [WindowInfo] {
        guard let windowListInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        // 현재 실행 중인 UI 활성화 앱(.regular)의 PID 목록
        // (이름 기반 매칭 시 CGWindowList의 ownerName과 NSWorkspace의 localizedName 불일치 문제 방지)
        let regularApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
        let regularAppPIDs = Set(regularApps.map { $0.processIdentifier })
        // PID → bundleIdentifier 매핑 (Issue71: 안정적 매칭 식별자)
        var pidToBundleId: [pid_t: String] = [:]
        for app in regularApps {
            if let bid = app.bundleIdentifier, !bid.isEmpty {
                pidToBundleId[app.processIdentifier] = bid
            }
        }

        // Accessibility API로 실제 창 제목 조회 (CGWindowID → 제목 매핑)
        let axTitleMap = buildAXTitleMap()

        // Issue72_2 (Phase 2): 디스플레이 ID → 영구 UUID 매핑 + 디스플레이별 frame
        // 멀티 디스플레이 환경에서 창의 중심점이 어느 디스플레이에 속하는지 판정용.
        let displayInfo = buildDisplayInfo()

        // Issue72_2 (Phase 2): 같은 앱(PID)별 windowOrder 카운터.
        // CGWindowListCopyWindowInfo는 onscreen 정렬(최전면 첫 번째)이므로 등장 순서로 0,1,2,... 부여.
        var orderByPID: [pid_t: Int] = [:]

        // Issue72_6 (Phase 6-2): PID → originURL(Chrome --app= 등 PWA 식별자) 캐시.
        var pidToOriginURL: [pid_t: String?] = [:]

        var results: [WindowInfo] = []

        for dict in windowListInfo {
            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let cgWindowName = dict[kCGWindowName as String] as? String
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let windowId = dict[kCGWindowNumber as String] as? Int ?? 0

            // AX 제목 우선, CG 이름 fallback
            let rawWindowName = axTitleMap[CGWindowID(windowId)] ?? cgWindowName ?? "No Name"

            // Issue72_3 (Phase 3): 타이틀 정규화. normalizer 주입 시에만 적용.
            let bundleId = pidToBundleId[ownerPID]
            let windowName: String
            let windowRaw: String?
            if let normalizer = titleNormalizer {
                let normalized = normalizer.normalize(title: rawWindowName, bundleId: bundleId, app: ownerName)
                windowName = normalized
                // 원본 보존 — 정규화 결과가 다를 때만 windowRaw에 기록
                windowRaw = (normalized == rawWindowName) ? nil : rawWindowName
            } else {
                windowName = rawWindowName
                windowRaw = nil
            }

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

            // Issue72_2: windowOrder 부여 (필터 통과한 유효한 창만 카운트)
            let order = orderByPID[ownerPID, default: 0]
            orderByPID[ownerPID] = order + 1

            // Issue72_2: 창 중심점이 속한 디스플레이의 UUID 조회
            let centerX = x + width / 2
            let centerY = y + height / 2
            let displayUUID = displayUUIDForPoint(CGPoint(x: centerX, y: centerY), displayInfo: displayInfo)

            // Issue72_6 (Phase 6-1): 비공개 API로 spaceId 조회 (실패 시 nil)
            let spaceId = _spaceIdForCGWindowID(CGWindowID(windowId))

            // Issue72_6 (Phase 6-2): PWA originURL 추출 (Chrome계열만, PID별 캐시)
            let originURL: String?
            if pidToOriginURL.keys.contains(ownerPID) {
                originURL = pidToOriginURL[ownerPID] ?? nil
            } else {
                let extracted = extractOriginURL(pid: ownerPID, bundleId: bundleId)
                pidToOriginURL[ownerPID] = extracted
                originURL = extracted
            }

            let info = WindowInfo(
                id: windowId,
                app: ownerName,
                bundleId: bundleId,
                window: windowName,
                layer: layer,
                pos: WindowPosition(x: x, y: y),
                size: WindowSize(width: width, height: height),
                windowOrder: order,
                displayUUID: displayUUID,
                windowRaw: windowRaw,
                spaceId: spaceId,
                originURL: originURL
            )
            results.append(info)
        }

        return results
    }

    // MARK: - Issue72_2 (Phase 2): 디스플레이 정보

    /// (displayID, NSScreen.frame, UUID) 튜플 목록. 매 캡처마다 빌드.
    private struct DisplayEntry {
        let frame: CGRect
        let uuid: String
    }

    /// 활성 디스플레이 전체에 대해 `(NSScreen.frame, CGDisplayCreateUUIDFromDisplayID UUID 문자열)` 매핑 빌드.
    private func buildDisplayInfo() -> [DisplayEntry] {
        var entries: [DisplayEntry] = []
        for screen in NSScreen.screens {
            guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(displayNumber.uint32Value)
            guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
                continue
            }
            guard let uuidCFString = CFUUIDCreateString(nil, cfUUID) else {
                continue
            }
            let uuid = uuidCFString as String
            entries.append(DisplayEntry(frame: screen.frame, uuid: uuid))
        }
        return entries
    }

    /// 중심점이 속하는 디스플레이의 UUID. 없으면 nil(=주 디스플레이 외 좌표 또는 디스플레이 없음).
    /// NSScreen.frame은 Cocoa 좌표(원점=주 디스플레이 좌하단, y-up).
    /// CGWindow bounds는 Quartz 좌표(원점=주 디스플레이 좌상단, y-down) → 변환 후 비교.
    private func displayUUIDForPoint(_ pointQuartz: CGPoint, displayInfo: [DisplayEntry]) -> String? {
        guard !displayInfo.isEmpty else { return nil }
        // 주 디스플레이 높이 (Cocoa↔Quartz 변환 기준)
        let primaryHeight = displayInfo.first?.frame.height ?? 0
        // Quartz(y-down) → Cocoa(y-up) 변환: cocoaY = primaryHeight - quartzY
        let cocoaPoint = CGPoint(x: pointQuartz.x, y: primaryHeight - pointQuartz.y)
        for entry in displayInfo {
            if entry.frame.contains(cocoaPoint) {
                return entry.uuid
            }
        }
        // 어느 디스플레이에도 정확히 안 들어가면 가장 가까운 디스플레이 선택 (창 일부가 화면 밖에 걸쳐있는 경우)
        return displayInfo.min { lhs, rhs in
            squaredDistance(from: cocoaPoint, to: lhs.frame) < squaredDistance(from: cocoaPoint, to: rhs.frame)
        }?.uuid
    }

    /// 점에서 사각형까지의 제곱 거리 (점이 사각형 내부면 0).
    private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    // MARK: - Issue72_6 (Phase 6-2): PWA originURL 추출

    /// Chromium 계열 PWA의 `--app=URL` 명령행 인자 추출.
    /// 대상 bundleId: Chrome / Edge / Brave 등. 그 외는 nil.
    /// 실패 시(권한·헬퍼 프로세스 등) nil — 매칭 시 fallback.
    private func extractOriginURL(pid: pid_t, bundleId: String?) -> String? {
        // Chromium 계열만 대상 (불필요한 ps 호출 방지)
        let chromiumBundles: Set<String> = [
            "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
            "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
            "org.chromium.Chromium"
        ]
        guard let bid = bundleId, chromiumBundles.contains(bid) else { return nil }

        // `ps -p {pid} -o command=` 로 명령행 추출
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // `--app=https://...` 토큰 추출 (URL은 공백·따옴표 포함 가능 — 단순 토큰 분리로 처리)
        for token in output.components(separatedBy: " ") {
            if token.hasPrefix("--app=") {
                let url = String(token.dropFirst(6))
                if !url.isEmpty { return url }
            }
        }
        return nil
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
