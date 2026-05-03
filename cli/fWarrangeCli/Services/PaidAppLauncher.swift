import Foundation
import AppKit

/// Detects and launches the paid sibling (`fWarrange.app`).
/// Issue217 Phase 2: extracted from AppState. Search paths follow
/// paid_cli_protocol.md §2.1 deployment matrix.
/// Issue223: user-home `~/Applications/fWarrange.app` fallback added.
enum PaidAppLauncher {
    // Issue223: SSOT §2.1 — system locations first, then user-home fallback.
    // ~/Library is intentionally excluded; only well-known install roots are scanned.
    private static let paidAppSearchPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/fWarrange.app").path
        return [
            "/Applications/fWarrange.app",
            "/Applications/_nowage_app/fWarrange.app",
            "/Applications/_finfra_app/fWarrange.app",
            home
        ]
    }()

    // Issue222: SSOT §1.2 — URL Scheme parameter validation.
    // Whitelist accepted action verbs sent to paidApp via `fwarrange://command?action=...`.
    private static let allowedActions: Set<String> = [
        "main", "settings", "layouts", "edit", "about"
    ]

    // Issue222: SSOT §1.2 — layout name pattern (reserved for future open(action:layout:) extension).
    // Matches conservative layout filenames: alphanumeric + `_-.`, length 1..64.
    private static let layoutPattern = #"^[A-Za-z0-9_\-\.]{1,64}$"#

    /// Validate a layout token against `layoutPattern`. Returns false on mismatch.
    static func isValidLayout(_ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: layoutPattern) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }

    /// Detect paid app at known install locations only (excludes ~/Library).
    static func detect() -> URL? {
        for path in paidAppSearchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Launch paid app; returns true on success.
    @discardableResult
    static func launch() -> Bool {
        guard let url = detect() else { return false }
        let success = NSWorkspace.shared.open(url)
        if success {
            logI("✅ fWarrange(Paid) 실행: \(url.path)")
        } else {
            logW("⚠️ fWarrange 실행 실패: \(url.path)")
        }
        return success
    }

    /// Issue195: open a specific paidApp screen via fwarrange:// URL scheme.
    /// If paidApp is not installed, NSWorkspace returns false and the caller
    /// is expected to surface the install/start guide.
    /// Issue222: action whitelist + URL-percent-encoding to block query injection.
    static func open(action: String) {
        guard allowedActions.contains(action) else {
            let allowed = allowedActions.sorted().joined(separator: ",")
            logW("🚫 paidApp URL Scheme 거부: 허용되지 않은 action=\(action) (allowed: \(allowed))")
            return
        }
        var components = URLComponents()
        components.scheme = "fwarrange"
        components.host = "command"
        components.queryItems = [URLQueryItem(name: "action", value: action)]
        guard let url = components.url else {
            logW("⚠️ paidApp URL Scheme URL 생성 실패: action=\(action)")
            return
        }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            logI("🔗 paidApp URL Scheme 호출 성공: action=\(action)")
        } else {
            logW("⚠️ paidApp URL Scheme 호출 실패: action=\(action) — paidApp 미등록 또는 미설치")
        }
    }

    /// Issue68: Terminate the running paidApp via standard NSRunningApplication API.
    /// Uses bundleIdentifier `kr.finfra.fWarrange` to locate live instances and invokes
    /// `terminate()` (graceful) so paidApp's `applicationWillTerminate` fires —
    /// allowing it to POST `/unregister` and clean up before exit.
    /// Falls back to `forceTerminate()` after `gracePeriod` seconds if instances remain.
    /// Returns true when at least one paidApp instance was found and signalled.
    @discardableResult
    static func terminate(gracePeriod: TimeInterval = 2.0) -> Bool {
        let bundleId = "kr.finfra.fWarrange"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard !running.isEmpty else {
            logI("ℹ️ paidApp 종료 시도 — 실행 중 인스턴스 없음 (bundleId=\(bundleId))")
            return false
        }
        for app in running {
            let pid = app.processIdentifier
            let ok = app.terminate()
            if ok {
                logI("👋 paidApp 종료 신호 송신 (graceful): pid=\(pid)")
            } else {
                logW("⚠️ paidApp graceful terminate 실패 → forceTerminate 시도: pid=\(pid)")
                _ = app.forceTerminate()
            }
        }
        let deadline = Date().addingTimeInterval(gracePeriod)
        while Date() < deadline {
            let stillAlive = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if stillAlive.isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        let stragglers = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in stragglers {
            logW("⏱ paidApp graceful 종료 시간 초과 → forceTerminate: pid=\(app.processIdentifier)")
            _ = app.forceTerminate()
        }
        return true
    }

    /// Detect → launch → confirm via NSAlert. Returns false when paidApp is missing.
    @MainActor
    static func tryLaunchFeature() -> Bool {
        guard detect() != nil else { return false }
        if launch() {
            let alert = NSAlert()
            alert.messageText = "fWarrange launched"
            alert.informativeText = "fWarrange (paid version) has been launched.\nPlease use the feature from fWarrange."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            NSApplication.shared.activate(ignoringOtherApps: true)
            alert.runModal()
            return true
        }
        return false
    }
}
