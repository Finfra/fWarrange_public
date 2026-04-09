import Foundation
import AppKit

@Observable @MainActor
final class WindowManager {
    var currentWindows: [WindowInfo] = []
    var restoreStatus: RestoreStatus = .idle

    private let captureService: WindowCaptureService
    private let restoreService: WindowRestoreService
    private let accessibilityService: AccessibilityService

    init(
        captureService: WindowCaptureService,
        restoreService: WindowRestoreService,
        accessibilityService: AccessibilityService
    ) {
        self.captureService = captureService
        self.restoreService = restoreService
        self.accessibilityService = accessibilityService
    }

    func captureCurrentWindows(filterApps: [String]?) -> [WindowInfo] {
        let windows = captureService.captureWindows(filterApps: filterApps)
        currentWindows = windows
        return windows
    }

    @discardableResult
    func restoreWindows(
        _ windows: [WindowInfo],
        maxRetries: Int = 5,
        retryInterval: Double = 0.5,
        minimumScore: Int = 30,
        enableParallel: Bool = true
    ) async -> [WindowMatchResult] {
        restoreStatus = .restoring(progress: 0, current: "준비 중...")

        let startTime = CFAbsoluteTimeGetCurrent()
        logD("[WindowManager.restoreWindows] 시작 - 창 수: \(windows.count), maxRetries: \(maxRetries), retryInterval: \(retryInterval)초, minimumScore: \(minimumScore), 병렬: \(enableParallel)")

        let results = await restoreService.restoreWindows(
            windows,
            maxRetries: maxRetries,
            retryInterval: retryInterval,
            minimumScore: minimumScore,
            enableParallel: enableParallel,
            onProgress: { [weak self] progress, message in
                self?.restoreStatus = .restoring(progress: progress, current: message)
            }
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let succeeded = results.filter { $0.success }.count
        logD("[WindowManager.restoreWindows] 종료 - 성공: \(succeeded)/\(results.count), 경과: \(String(format: "%.3f", elapsed))초")

        restoreStatus = .completed(total: results.count, succeeded: succeeded)
        return results
    }

    func runningAppNames() -> [String] {
        captureService.runningAppNames()
    }

    func isAccessibilityGranted() -> Bool {
        accessibilityService.isAccessibilityGranted()
    }

    func requestAccessibility() {
        accessibilityService.requestAccessibility()
    }
}
