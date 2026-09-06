import Foundation

/// Login Item lifecycle bound to brew services plist (Issue51).
/// Issue217 Phase 2: extracted from AppState. ServiceManagement import is
/// no longer required here because Issue36 removed SMAppService usage.
///
/// enabled=true  → brew services start (plist install + launchd register)
/// enabled=false → plist removal only (launchctl bootout is intentionally skipped
///                  because it terminates the running process).
///
/// Issue95: neither the brew binary path nor the LaunchAgent plist name is hardcoded here.
/// Homebrew changed its service label convention (`homebrew.mxcl.*` -> `sh.brew.*`), so both
/// lookups are delegated to `BrewServiceSync`, the single decision point.
enum LoginItemService {
    static func sync(enabled: Bool) {
        if enabled {
            guard let brewPath = BrewServiceSync.findBrewPath() else {
                logW("Issue51: brew 미설치 — Login Item 등록 건너뜀")
                return
            }
            let (rc, output) = BrewServiceSync.runCommandWithStatus(
                brewPath, args: ["services", "start", BrewServiceSync.formulaName])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if rc == 0 {
                logI("Issue51: brew services start \(BrewServiceSync.formulaName) — plist 설치됨 (재부팅 시 자동 시작)")
            } else {
                logW("Issue51: brew services start 실패 (rc=\(rc)) — \(trimmed)")
            }
        } else {
            // Remove the plist file only.
            // Do NOT use launchctl bootout — it terminates the running process when the app
            // is managed by launchd, which is the exact bug being fixed here.
            let plists = BrewServiceSync.launchAgentPlistURLs()
            guard !plists.isEmpty else {
                logI("Issue51: LaunchAgent plist 이미 없음 (launchAtLogin=false 반영됨)")
                return
            }
            // 규약 전환기에는 구·신 규약 plist 가 함께 남을 수 있으므로 전부 제거한다.
            for plist in plists {
                do {
                    try FileManager.default.removeItem(at: plist)
                    logI("Issue51: LaunchAgent plist 제거됨 (\(plist.lastPathComponent)) — 재부팅 시 자동 시작 안 함")
                } catch {
                    logW("Issue51: plist 제거 실패 (\(plist.lastPathComponent)) — \(error.localizedDescription)")
                }
            }
        }
    }
}
