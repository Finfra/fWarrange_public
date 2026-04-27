import Foundation

/// Login Item lifecycle bound to brew services plist (Issue51).
/// Issue217 Phase 2: extracted from AppState. ServiceManagement import is
/// no longer required here because Issue36 removed SMAppService usage.
///
/// brew path: /opt/homebrew/bin/brew (Apple Silicon only).
/// enabled=true  → brew services start (plist install + launchd register)
/// enabled=false → launchctl bootout + plist removal
///                  (brew services stop is avoided because it also kills the
///                  running process, which we do not want here).
enum LoginItemService {
    static func sync(enabled: Bool) {
        if enabled {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
            process.arguments = ["services", "start", "fwarrange-cli"]
            do {
                try process.run()
                process.waitUntilExit()
                logI("Issue51: brew services start fwarrange-cli — plist 설치됨 (재부팅 시 자동 시작)")
            } catch {
                logW("Issue51: brew services start 실패 — \(error.localizedDescription)")
            }
        } else {
            // Step 1: launchctl bootout (replaces brew services stop to avoid killing process).
            let uid = getuid()
            let labelPath = "gui/\(uid)/homebrew.mxcl.fwarrange-cli"
            let bootoutProcess = Process()
            bootoutProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            bootoutProcess.arguments = ["bootout", labelPath]
            do {
                try bootoutProcess.run()
                bootoutProcess.waitUntilExit()
                logI("Issue51: launchctl bootout 완료 — LaunchAgent 등록 해제")
            } catch {
                logW("Issue51: launchctl bootout 실패 — \(error.localizedDescription)")
            }

            // Step 2: remove the plist file.
            let plist = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/LaunchAgents/homebrew.mxcl.fwarrange-cli.plist")
            do {
                if FileManager.default.fileExists(atPath: plist.path) {
                    try FileManager.default.removeItem(at: plist)
                    logI("Issue51: LaunchAgent plist 제거됨 — 재부팅 시 자동 시작 안 함 (상태: none)")
                } else {
                    logI("Issue51: LaunchAgent plist 이미 없음 (launchAtLogin=false 반영됨)")
                }
            } catch {
                logW("Issue51: plist 제거 실패 — \(error.localizedDescription)")
            }
        }
    }
}
