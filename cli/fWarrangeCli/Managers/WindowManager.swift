import Foundation
import AppKit

@Observable @MainActor
final class WindowManager {
    var currentWindows: [WindowInfo] = []
    var restoreStatus: RestoreStatus = .idle

    private let captureService: WindowCaptureService
    private let restoreService: WindowRestoreService
    private let accessibilityService: AccessibilityService
    /// Issue72_1: 복구 매칭 결과 누적 통계 수집기. nil이면 통계 미수집(테스트·하위 호환용).
    private let statsCollector: RestoreStatsCollector?

    init(
        captureService: WindowCaptureService,
        restoreService: WindowRestoreService,
        accessibilityService: AccessibilityService,
        statsCollector: RestoreStatsCollector? = nil
    ) {
        self.captureService = captureService
        self.restoreService = restoreService
        self.accessibilityService = accessibilityService
        self.statsCollector = statsCollector
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
        enableParallel: Bool = true,
        mode: MatchMode = .normal
    ) async -> [WindowMatchResult] {
        restoreStatus = .restoring(progress: 0, current: "준비 중...")

        let startTime = CFAbsoluteTimeGetCurrent()
        logD("[WindowManager.restoreWindows] 시작 - 창 수: \(windows.count), mode: \(mode.rawValue), maxRetries: \(maxRetries), retryInterval: \(retryInterval)초, minimumScore: \(minimumScore), 병렬: \(enableParallel)")

        let results = await restoreService.restoreWindows(
            windows,
            maxRetries: maxRetries,
            retryInterval: retryInterval,
            minimumScore: minimumScore,
            enableParallel: enableParallel,
            mode: mode,
            onProgress: { [weak self] progress, message in
                self?.restoreStatus = .restoring(progress: progress, current: message)
            }
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let succeeded = results.filter { $0.success }.count
        logD("[WindowManager.restoreWindows] 종료 - 성공: \(succeeded)/\(results.count), 경과: \(String(format: "%.3f", elapsed))초")

        // Issue72_1 (Phase 1): 매칭 결과를 통계 수집기에 push. 디바운스 후 디스크 flush.
        if let statsCollector = statsCollector {
            await statsCollector.recordBatch(results)
        }

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

    func openAccessibilitySettings() {
        accessibilityService.openAccessibilitySettings()
    }
}
