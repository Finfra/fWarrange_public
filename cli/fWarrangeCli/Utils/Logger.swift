import Foundation
import os.log

/// 로그 레벨 정의
public enum LogLevel: Int, CaseIterable, Sendable, CustomStringConvertible {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    nonisolated public var description: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    nonisolated public var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// fWarrangeCli 전용 로거 - nonisolated (모든 스레드에서 안전하게 호출 가능)
nonisolated final class Logger: Sendable {
    static let shared = Logger()
    private let osLog = OSLog(subsystem: "kr.finfra.fWarrangeCli", category: "main")

    private let logDirectoryURL: URL
    private let logFileURL: URL

    private let queue = DispatchQueue(label: "kr.finfra.fWarrangeCli.logger", qos: .utility)

    nonisolated(unsafe) var currentLogLevel: LogLevel

    nonisolated(unsafe) var isFileLoggingEnabled: Bool = true

    private let sessionDateString: String

    private init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        self.sessionDateString = formatter.string(from: Date())

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appRootPath: String
        if let envPath = ProcessInfo.processInfo.environment["fWarrangeCli_config"], !envPath.isEmpty {
            appRootPath = (envPath as NSString).expandingTildeInPath
        } else {
            appRootPath = documentsURL.appendingPathComponent("finfra/fWarrangeData").path
        }
        let logDir = URL(fileURLWithPath: appRootPath).appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)

        #if DEBUG
            print("🔧 [DEBUG] 로그 디렉토리 설정: \(logDir.path)")
        #endif

        self.logDirectoryURL = logDir
        self.logFileURL = logDir.appendingPathComponent("wlog.log")

        // config.yml에서 logLevel 읽기
        let configPath = URL(fileURLWithPath: appRootPath).appendingPathComponent("_config.yml")
        if let configContent = try? String(contentsOf: configPath, encoding: .utf8),
           let logLevelLine = configContent.split(separator: "\n").first(where: {
               let t = $0.trimmingCharacters(in: .whitespaces)
               return !t.hasPrefix("#") && t.hasPrefix("logLevel:")
           }),
           let levelStr = logLevelLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces),
           let levelValue = Int(levelStr),
           let level = LogLevel(rawValue: levelValue) {
            self.currentLogLevel = level
        } else {
            // 파일 읽기 실패 시 기본값
            #if DEBUG
            self.currentLogLevel = .debug
            #else
            self.currentLogLevel = .info
            #endif
        }

        createLogFileIfNeeded()
    }

    private func createLogFileIfNeeded() {
        // Info 레벨 미만이면 파일 생성 스킵
        guard currentLogLevel.rawValue <= LogLevel.info.rawValue else {
            return
        }

        let startupMessage = "\n=== fWarrangeCli 로그 시작 [\(formatTimestamp(Date()))] ===\n"
        do {
            try startupMessage.write(to: logFileURL, atomically: false, encoding: .utf8)
            #if DEBUG
                print("✅ 로그 파일 초기화 완료: \(logFileURL.path)")
            #endif
        } catch {
            #if DEBUG
                print("❌ 로그 파일 생성 실패: \(error)")
            #endif
        }
    }

    func writeSessionEnd() {
        guard currentLogLevel.rawValue <= LogLevel.info.rawValue else { return }
        queue.sync { [self] in
            let endMessage = "=== fWarrangeCli 로그 종료 [\(formatTimestamp(Date()))] ===\n"
            guard let data = endMessage.data(using: .utf8) else { return }
            appendToFile(url: logFileURL, data: data)
            let archivedLogURL = logDirectoryURL.appendingPathComponent("wlog_\(sessionDateString).log")
            appendToFile(url: archivedLogURL, data: data)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func writeToLogFile(_ message: String, level: LogLevel? = nil) {
        // Info 레벨 이상일 때만 파일에 기록 (logLevel >= 2)
        guard currentLogLevel.rawValue <= LogLevel.info.rawValue else {
            return
        }

        queue.async { [self] in
            let timestampedMessage = "[\(formatTimestamp(Date()))] \(message)\n"
            guard let data = timestampedMessage.data(using: .utf8) else { return }

            appendToFile(url: logFileURL, data: data)

            let archivedLogURL = logDirectoryURL.appendingPathComponent("wlog_\(sessionDateString).log")
            appendToFile(url: archivedLogURL, data: data)
        }
    }

    private func appendToFile(url: URL, data: Data) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }

    // MARK: - 로깅 메서드들

    func info(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.info.rawValue else { return }
        let logMessage = "ℹ️ INFO: \(message())"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .info, logMessage)
        #endif
        writeToLogFile(logMessage, level: .info)
    }

    func debug(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.debug.rawValue else { return }
        #if DEBUG
            let logMessage = "🐛 DEBUG: \(message())"
            print(logMessage)
            writeToLogFile(logMessage, level: .debug)
        #endif
    }

    func verbose(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.verbose.rawValue else { return }
        #if DEBUG
            let logMessage = "💬 VERBOSE: \(message())"
            print(logMessage)
            writeToLogFile(logMessage, level: .verbose)
        #endif
    }

    func warning(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.warning.rawValue else { return }
        let logMessage = "⚠️ WARNING: \(message())"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .default, logMessage)
        #endif
        writeToLogFile(logMessage, level: .warning)
    }

    func error(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.error.rawValue else { return }
        let logMessage = "❌ ERROR: \(message())"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .error, logMessage)
        #endif
        writeToLogFile(logMessage, level: .error)
    }

    func critical(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.critical.rawValue else { return }
        let logMessage = "🚨 CRITICAL: \(message())"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .fault, logMessage)
        #endif
        writeToLogFile(logMessage, level: .critical)
    }

    func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        let logMessage = "🔧 로그 레벨 변경: \(level.emoji) \(level.description)"
        #if DEBUG
            print(logMessage)
        #endif
        writeToLogFile(logMessage)
    }

    func getLogFilePath() -> String {
        return (logFileURL.path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - 전역 헬퍼 함수

public nonisolated func logV(_ message: @autoclosure () -> String) {
    Logger.shared.verbose(message())
}

public nonisolated func logD(_ message: @autoclosure () -> String) {
    Logger.shared.debug(message())
}

public nonisolated func logI(_ message: @autoclosure () -> String) {
    Logger.shared.info(message())
}

public nonisolated func logW(_ message: @autoclosure () -> String) {
    Logger.shared.warning(message())
}

public nonisolated func logE(_ message: @autoclosure () -> String) {
    Logger.shared.error(message())
}

public nonisolated func logC(_ message: @autoclosure () -> String) {
    Logger.shared.critical(message())
}
