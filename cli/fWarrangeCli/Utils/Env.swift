import Foundation

/// 환경 변수 기반 런타임 오버라이드 헬퍼.
/// `brew services` launchd plist의 `EnvironmentVariables`를 통해 주입됨.
enum Env {
    /// FWARRANGE_PORT: RESTServer 포트 오버라이드 (1–65535)
    static var port: UInt16? {
        guard let raw = ProcessInfo.processInfo.environment["FWARRANGE_PORT"],
              let v = Int(raw), v > 0, v <= 65535 else { return nil }
        return UInt16(v)
    }

    /// FWARRANGE_LOG_LEVEL: 로그 레벨 오버라이드 (verbose|debug|info|warning|error|critical)
    static var logLevel: LogLevel? {
        guard let raw = ProcessInfo.processInfo.environment["FWARRANGE_LOG_LEVEL"] else { return nil }
        switch raw.lowercased() {
        case "verbose":  return .verbose
        case "debug":    return .debug
        case "info":     return .info
        case "warning":  return .warning
        case "error":    return .error
        case "critical": return .critical
        default:         return nil
        }
    }

    /// FWARRANGE_DISABLE_HOTKEYS = "1" 시 글로벌 단축키 등록을 건너뜀
    static var hotkeysDisabled: Bool {
        ProcessInfo.processInfo.environment["FWARRANGE_DISABLE_HOTKEYS"] == "1"
    }
}
