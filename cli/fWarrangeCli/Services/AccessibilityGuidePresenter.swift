import Foundation
import AppKit

/// Surfaces the Accessibility permission guide alert (Issue189).
/// Issue217 Phase 2: extracted from AppState. The caller injects the
/// `WindowManager` since opening the system settings is its responsibility.
enum AccessibilityGuidePresenter {

    /// Issue96: `NSAlert.runModal()` 은 블로킹이라 가드가 없으면 호출이 큐에 쌓여
    /// 닫는 즉시 또 뜬다(prj25 Issue221 실발생). 단축키는 연타될 수 있으므로 필수다.
    /// 접근은 모두 main thread(run loop 블록) 안에서만 일어나 별도 동기화가 필요 없다.
    /// Issue116: 시작 안내·권한 상실 안내가 같은 가드를 쓴다(`scheduleExclusive`).
    private static var isPresenting = false

    /// Schedules a modal alert on the main thread (Issue110).
    ///
    /// Not `DispatchQueue.main.async`: `runModal()` inside a main-queue block keeps that block
    /// running until the alert closes, and the serial main queue cannot drain meanwhile — every
    /// REST v2 handler (they hop to the main queue) hung while the guide was up.
    /// A run-loop block runs outside the main-queue callout, so the modal loop keeps servicing it.
    static func schedule(_ present: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: present)
    }

    /// Schedules `present` unless an accessibility alert is already up (Issue116).
    ///
    /// Run-loop blocks also run *inside* an open alert's modal loop, so the serial main queue
    /// no longer keeps guides apart — this shared guard does. One accessibility alert at a time.
    private static func scheduleExclusive(_ name: String, _ present: @escaping () -> Void) {
        schedule {
            guard !isPresenting else {
                logD("[a11y] \(name) — 다른 접근성 안내가 이미 표시 중, 중복 호출 억제")
                return
            }
            isPresenting = true
            defer { isPresenting = false }
            present()
        }
    }

    /// Runs an alert modally. A seam so tests can stand in for `NSAlert.runModal()` (Issue116).
    static var runModal: (NSAlert) -> NSApplication.ModalResponse = { $0.runModal() }

    static func show(windowManager: WindowManager) {
        show(openSettings: {
            Task { @MainActor in
                windowManager.openAccessibilitySettings()
            }
        })
    }

    static func show(openSettings: @escaping () -> Void) {
        scheduleExclusive("시작 안내") {
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

            let response = runModal(alert)
            if response == .alertFirstButtonReturn {
                openSettings()
            }
        }
    }

    // MARK: - 운영 중 권한 상실 (Issue96)

    /// 실행 중에 접근성 권한이 해제된 것을 감지했을 때의 안내.
    ///
    /// 시작 시 안내(`show(windowManager:)`)와 달리 **설정 열기 버튼을 두지 않는다** —
    /// 권한이 해제되면 접근성 목록에서 항목 자체가 사라져 켤 대상이 없고,
    /// 실행 중인 프로세스는 스스로를 그 목록에 되돌릴 수 없다. 재시작이 유일한 복구 경로다.
    static func showPermissionLost() {
        scheduleExclusive("권한 상실 안내") {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "접근성 권한이 해제되었습니다"
            alert.informativeText = """
                단축키는 입력됐지만 창을 제어할 수 없습니다.

                실행 중인 앱은 접근성 목록에 스스로를 다시 등록할 수 없어 재시작이 필요합니다.
                재시작 후에도 동작하지 않으면 시스템 설정 > 개인정보 보호 및 보안 > 접근성에서
                fWarrangeCli를 다시 허용해주세요.
                """
            alert.addButton(withTitle: "지금 재시작")
            alert.addButton(withTitle: "나중에")

            let response = runModal(alert)
            guard response == .alertFirstButtonReturn else {
                logI("[a11y] 권한 상실 안내 — 사용자가 재시작을 미룸")
                return
            }
            AppRestarter.restart(reason: "접근성 권한 상실 안내")
        }
    }
}

// MARK: - Issue119: 재시작 단일 판정 지점

/// Restarts this cliApp instance the way it was launched. Used by the accessibility guide
/// (Issue96) and `POST /api/v2/cli/restart` (Issue119) — one decision, so they can't drift apart.
///
/// Anything this app spawns dies with it (jma 실측 2026-10-05: an in-app `brew services restart`
/// child and an in-app `sh` relaunch helper were both reaped when the app/service stopped).
/// So the comeback is handed to an **independent launchd job** (`launchctl submit`) that waits for
/// this PID to exit, then:
/// * launchd (brew services) managed → `launchctl kickstart gui/<uid>/<label>` — the plist's
///   `KeepAlive {SuccessfulExit=false}` does not restart a clean exit by itself
/// * `open` launched → `open <bundle>`
/// The job removes itself afterwards.
enum AppRestarter {
    enum Path: String { case brewService = "brew-service", openRelaunch = "open-relaunch" }

    struct Plan: Equatable {
        let path: Path
        let jobLabel: String
        let script: String
    }

    /// Seams for tests — production uses the real launchd label, `launchctl submit` and terminate.
    static var managedServiceLabel: () -> String? = { BrewServiceSync.runningServiceLabel() }
    static var submit: (_ jobLabel: String, _ script: String) -> Bool = { submitDefault(jobLabel: $0, script: $1) }
    static var terminate: () -> Void = { NSApp.terminate(nil) }

    static func resetSeams() {
        managedServiceLabel = { BrewServiceSync.runningServiceLabel() }
        submit = { submitDefault(jobLabel: $0, script: $1) }
        terminate = { NSApp.terminate(nil) }
    }

    /// The helper job's script — pure, so tests can read it.
    static func plan(pid: Int32, uid: UInt32, bundlePath: String, serviceLabel: String?) -> Plan {
        let jobLabel = "kr.finfra.fWarrangeCli.relaunch.\(pid)"
        // wait up to 20s for this process to exit
        let wait = "for _ in $(seq 1 100); do kill -0 \(pid) 2>/dev/null || break; sleep 0.2; done"
        let action: String
        let path: Path
        if let label = serviceLabel {
            action = "/bin/launchctl kickstart gui/\(uid)/\(label)"
            path = .brewService
        } else {
            action = "/usr/bin/open \(shellQuote(bundlePath))"
            path = .openRelaunch
        }
        return Plan(path: path, jobLabel: jobLabel, script: "\(wait); \(action); /bin/launchctl remove \(jobLabel)")
    }

    @discardableResult
    static func restart(reason: String) -> Path {
        let label = managedServiceLabel()
        let p = plan(pid: getpid(), uid: getuid(), bundlePath: Bundle.main.bundleURL.path, serviceLabel: label)
        guard submit(p.jobLabel, p.script) else {
            // no helper → quitting now would be a plain stop; stay up instead
            logW("[restart] ⚠️ \(reason) — 재기동 헬퍼 예약 실패, 종료하지 않음. 수동 재시작이 필요합니다")
            return p.path
        }
        if label != nil { BrewServiceSync.beginManagedRelaunch() }
        logI("[restart] \(reason) — \(p.path.rawValue) 헬퍼 예약(\(p.jobLabel)) 후 종료")
        terminate()
        return p.path
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func submitDefault(jobLabel: String, script: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["submit", "-l", jobLabel, "--", "/bin/sh", "-c", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            logW("[restart] launchctl submit 실패 — \(error.localizedDescription)")
            return false
        }
    }
}
