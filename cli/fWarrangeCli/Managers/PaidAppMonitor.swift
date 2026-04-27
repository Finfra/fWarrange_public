import Foundation
import AppKit

/// Issue195: paidApp 실행 상태를 추적하는 모니터.
/// NSWorkspace launch/terminate 이중 채널로 상태 변화를 감지함.
/// AppState.paidAppStore 와 협력하지만 NSWorkspace 이벤트로 UI 상태를 즉시 반영.
@Observable @MainActor
final class PaidAppMonitor {

    enum State: Equatable {
        case cliOnly        // paidApp 미실행 — cliApp 단독 운영
        case paidAppActive  // paidApp 실행 중 — URL Scheme 버튼 노출
    }

    private(set) var state: State

    private let paidAppBundleId = "kr.finfra.fWarrange"

    /// paidApp terminate 시 호출할 콜백 (AppState의 cleanup 로직 통합용)
    private var onTerminateCallback: ((NSRunningApplication) -> Void)?

    init() {
        // 초기 상태: 현재 실행 중인 paidApp 확인
        let running = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "kr.finfra.fWarrange"
        ).isEmpty
        state = running ? .paidAppActive : .cliOnly
        if running {
            logI("🎯 PaidAppMonitor: 초기화 — paidApp 이미 실행 중 → .paidAppActive")
        }
    }

    /// NSWorkspace 알림 구독 시작. `AppState.initialize()` 시점에 호출.
    /// - Parameter onTerminate: paidApp 종료 시 호출할 콜백 (cleanup 로직)
    func startObserving(onTerminate: ((NSRunningApplication) -> Void)? = nil) {
        self.onTerminateCallback = onTerminate
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "kr.finfra.fWarrange" else { return }
            Task { @MainActor [weak self] in
                self?.state = .paidAppActive
                logI("🎯 PaidAppMonitor: paidApp 실행 감지 → .paidAppActive (pid=\(app.processIdentifier))")
            }
        }

        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "kr.finfra.fWarrange" else { return }
            Task { @MainActor [weak self] in
                self?.state = .cliOnly
                logI("🎯 PaidAppMonitor: paidApp 종료 감지 → .cliOnly (pid=\(app.processIdentifier))")
                // onTerminate 콜백 실행 (AppState의 cleanup 로직)
                self?.onTerminateCallback?(app)
            }
        }
    }
}
