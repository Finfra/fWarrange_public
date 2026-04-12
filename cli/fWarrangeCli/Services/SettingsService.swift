import Foundation

// MARK: - 프로토콜

protocol SettingsService {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    func resetToDefaults()
    var configFilePath: String { get }
}

// MARK: - YAML 파일 기반 구현체

/// {basePath}/_config.yml에서 설정을 읽고 쓰는 서비스.
/// basePath: 환경변수 fWarrangeCli_config 또는 ~/Documents/finfra/fWarrangeData
final class YAMLSettingsService: SettingsService {
    private let configURL: URL

    var configFilePath: String { configURL.path }

    init(baseDirectory: URL) {
        self.configURL = baseDirectory.appendingPathComponent("_config.yml")
    }

    func load() -> AppSettings {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let content = try? String(contentsOf: configURL, encoding: .utf8) else {
            return AppSettings.defaults
        }
        return parseYAML(content)
    }

    func save(_ settings: AppSettings) {
        let yaml = serializeToYAML(settings)
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? yaml.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func resetToDefaults() {
        save(AppSettings.defaults)
    }

    // MARK: - YAML 직렬화

    private func serializeToYAML(_ s: AppSettings) -> String {
        var lines: [String] = []
        lines.append("# fWarrangeCli Configuration")
        lines.append("")
        lines.append("excludedApps:")
        for app in s.excludedApps {
            lines.append("  - \"\(app)\"")
        }
        lines.append("maxRetries: \(s.maxRetries)")
        lines.append("retryInterval: \(s.retryInterval)")
        lines.append("minimumMatchScore: \(s.minimumMatchScore)")
        lines.append("enableParallelRestore: \(s.enableParallelRestore ?? true)")
        lines.append("restServerPort: \(s.restServerPort ?? 3016)")
        lines.append("# logLevel: 0=verbose, 1=debug, 2=info, 3=warning, 4=error, 5=critical")
        lines.append("logLevel: \(s.logLevel ?? 5)")
        lines.append("dataStorageMode: \(s.dataStorageMode?.rawValue ?? "host")")
        lines.append("launchAtLogin: \(s.launchAtLogin ?? false)")
        if let defaultLayout = s.defaultLayoutName {
            lines.append("defaultLayoutName: \"\(defaultLayout)\"")
        }
        lines.append("appLanguage: \(s.appLanguage ?? "system")")
        // 단축키 설정 (ex: ⌘F7, ⇧⌘F7, ⌃⌥S)
        lines.append("")
        lines.append("# Shortcuts (⌃=Control, ⌥=Option, ⇧=Shift, ⌘=Command)")
        if let sc = s.saveShortcut {
            lines.append("saveShortcut: \"\(sc.displayString)\"")
        }
        if let sc = s.restoreDefaultShortcut {
            lines.append("restoreDefaultShortcut: \"\(sc.displayString)\"")
        }
        if let sc = s.restoreLastShortcut {
            lines.append("restoreLastShortcut: \"\(sc.displayString)\"")
        }
        if let sc = s.showMainWindowShortcut {
            lines.append("showMainWindowShortcut: \"\(sc.displayString)\"")
        }
        if let sc = s.showSettingsShortcut {
            lines.append("showSettingsShortcut: \"\(sc.displayString)\"")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - YAML 파싱

    private func parseYAML(_ content: String) -> AppSettings {
        var dict: [String: String] = [:]
        var excludedApps: [String] = []
        var inExcludedApps = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 주석/빈줄 스킵
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                if inExcludedApps { inExcludedApps = false }
                continue
            }

            // 배열 아이템
            if trimmed.hasPrefix("- ") && inExcludedApps {
                let val = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                excludedApps.append(parseStringValue(val))
                continue
            }

            // key: value
            if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let val = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                if key == "excludedApps" {
                    inExcludedApps = true
                    continue
                }
                inExcludedApps = false
                dict[key] = val
            }
        }

        return AppSettings(
            excludedApps: excludedApps.isEmpty ? AppSettings.defaultExcludedApps : excludedApps,
            maxRetries: Int(dict["maxRetries"] ?? "") ?? AppSettings.defaults.maxRetries,
            retryInterval: Double(dict["retryInterval"] ?? "") ?? AppSettings.defaults.retryInterval,
            minimumMatchScore: Int(dict["minimumMatchScore"] ?? "") ?? AppSettings.defaults.minimumMatchScore,
            enableParallelRestore: dict["enableParallelRestore"].flatMap { Bool($0) } ?? true,
            restServerPort: Int(dict["restServerPort"] ?? "") ?? 3016,
            logLevel: Int(dict["logLevel"] ?? "") ?? 5,
            dataStorageMode: dict["dataStorageMode"].flatMap { DataStorageMode(rawValue: $0) } ?? .host,
            saveShortcut: parseShortcut(dict["saveShortcut"]) ?? AppSettings.defaults.saveShortcut,
            restoreDefaultShortcut: parseShortcut(dict["restoreDefaultShortcut"]) ?? AppSettings.defaults.restoreDefaultShortcut,
            restoreLastShortcut: parseShortcut(dict["restoreLastShortcut"]) ?? AppSettings.defaults.restoreLastShortcut,
            showMainWindowShortcut: parseShortcut(dict["showMainWindowShortcut"]),
            showSettingsShortcut: parseShortcut(dict["showSettingsShortcut"]),
            launchAtLogin: dict["launchAtLogin"].flatMap { Bool($0) } ?? false,
            defaultLayoutName: dict["defaultLayoutName"].flatMap { parseStringValue($0) }.flatMap { $0.isEmpty ? nil : $0 },
            appLanguage: dict["appLanguage"]
        )
    }

    /// 단축키 파싱: human-readable ("⌘F7") 또는 레거시 ("98:1048576") 형식 지원
    private func parseShortcut(_ value: String?) -> KeyboardShortcutConfig? {
        guard let value = value else { return nil }
        let trimmed = parseStringValue(value)

        // 레거시 형식: "98:1048576" (keyCode:modifierFlags)
        let parts = trimmed.split(separator: ":")
        if parts.count == 2,
           let keyCode = UInt16(parts[0]),
           let flags = UInt(parts[1]) {
            return KeyboardShortcutConfig(keyCode: keyCode, modifierFlags: flags)
        }

        // human-readable 형식: "⌘F7", "⇧⌘F7" 등
        return KeyboardShortcutConfig.from(displayString: trimmed)
    }

    private func parseStringValue(_ raw: String) -> String {
        let val = raw.trimmingCharacters(in: .whitespaces)
        if val.hasPrefix("\"") && val.hasSuffix("\"") {
            return String(val.dropFirst().dropLast())
        }
        return val
    }
}

// MARK: - UserDefaults 기반 (레거시, 폴백)

final class UserDefaultsSettingsService: SettingsService {
    private let key = "fWarrangeCli.AppSettings"

    var configFilePath: String { "UserDefaults://\(key)" }

    func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings.defaults
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func resetToDefaults() {
        save(AppSettings.defaults)
    }
}
