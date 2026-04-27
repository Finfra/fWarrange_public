import Foundation
import AppKit

/// Detects and launches the paid sibling (`fWarrange.app`).
/// Issue217 Phase 2: extracted from AppState. Search paths follow
/// paid_cli_protocol.md §2.1 deployment matrix; user-home install fallback
/// is tracked separately (issue후보 — 이슈후보2, 2026-04-26).
enum PaidAppLauncher {
    private static let paidAppSearchPaths = [
        "/Applications/fWarrange.app",
        "/Applications/_nowage_app/fWarrange.app",
        "/Applications/_finfra_app/fWarrange.app"
    ]

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
    static func open(action: String) {
        guard let url = URL(string: "fwarrange://command?action=\(action)") else { return }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            logI("🔗 paidApp URL Scheme 호출 성공: action=\(action)")
        } else {
            logW("⚠️ paidApp URL Scheme 호출 실패: action=\(action) — paidApp 미등록 또는 미설치")
        }
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
