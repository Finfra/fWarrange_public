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
/// basePath: Env.configPath (env: fWarrangeCli_config) 또는 ~/Documents/finfra/fWarrangeData
final class YAMLSettingsService: SettingsService {
    private let configURL: URL

    var configFilePath: String { configURL.path }

    init(baseDirectory: URL) {
        self.configURL = baseDirectory.appendingPathComponent("_config.yml")
    }

    func load() -> AppSettings {
        // 파일이 없으면 번들 시드(_config.yml) 복사 시도 (pairApp/fSnippetCli 패턴)
        if !FileManager.default.fileExists(atPath: configURL.path) {
            _ = copyConfigFromBundle()
        }
        guard FileManager.default.fileExists(atPath: configURL.path),
              let content = try? String(contentsOf: configURL, encoding: .utf8) else {
            return AppSettings.defaults
        }
        return parseYAML(content)
    }

    /// 앱 번들의 `_config.yml`을 사용자 데이터 경로로 복사.
    /// 실패 시 호출자가 하드코딩 기본값(AppSettings.defaults)으로 폴백.
    @discardableResult
    private func copyConfigFromBundle() -> Bool {
        guard let bundleURL = Bundle.main.url(forResource: "_config", withExtension: "yml") else {
            return false
        }
        let dir = configURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: bundleURL, to: configURL)
            return true
        } catch {
            return false
        }
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
        lines.append("launchAtLogin: \(s.launchAtLogin ?? true)")
        if let defaultLayout = s.defaultLayoutName {
            lines.append("defaultLayoutName: \"\(defaultLayout)\"")
        }
        lines.append("appLanguage: \(s.appLanguage ?? "system")")
        lines.append("")
        lines.append("# REST API Server")
        lines.append("restServerEnabled: \(s.restServerEnabled ?? true)")
        lines.append("allowExternalAccess: \(s.allowExternalAccess ?? false)")
        lines.append("allowedCIDR: \"\(s.allowedCIDR ?? "192.168.0.0/16")\"")
        if let p = s.dataDirectoryPath, !p.isEmpty {
            lines.append("dataDirectoryPath: \"\(p)\"")
        }
        lines.append("")
        lines.append("# Auto save")
        lines.append("autoSaveOnSleep: \(s.autoSaveOnSleep ?? true)")
        lines.append("maxAutoSaves: \(s.maxAutoSaves ?? 5)")
        lines.append("")
        lines.append("# UI options")
        lines.append("restoreButtonStyle: \(s.restoreButtonStyle ?? "nameIcon")")
        lines.append("confirmBeforeDelete: \(s.confirmBeforeDelete ?? true)")
        lines.append("showInCmdTab: \(s.showInCmdTab ?? true)")
        lines.append("clickSwitchToMain: \(s.clickSwitchToMain ?? false)")
        lines.append("theme: \(s.theme ?? "system")")
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

        var s = AppSettings.defaults
        s.excludedApps = excludedApps.isEmpty ? AppSettings.defaultExcludedApps : excludedApps
        if let v = dict["maxRetries"], let i = Int(v) { s.maxRetries = i }
        if let v = dict["retryInterval"], let d = Double(v) { s.retryInterval = d }
        if let v = dict["minimumMatchScore"], let i = Int(v) { s.minimumMatchScore = i }
        if let v = dict["enableParallelRestore"], let b = Bool(v) { s.enableParallelRestore = b }
        if let v = dict["restServerPort"], let i = Int(v) { s.restServerPort = i }
        if let v = dict["logLevel"], let i = Int(v) { s.logLevel = i }
        if let v = dict["dataStorageMode"], let m = DataStorageMode(rawValue: v) { s.dataStorageMode = m }
        // 단축키: _config.yml에 명시된 항목만 글로벌 등록 대상이 되도록 직접 대입.
        // 키 누락 시 nil → HotKeyService에서 compactMap으로 제외됨.
        s.saveShortcut = parseShortcut(dict["saveShortcut"])
        s.restoreDefaultShortcut = parseShortcut(dict["restoreDefaultShortcut"])
        s.restoreLastShortcut = parseShortcut(dict["restoreLastShortcut"])
        s.showMainWindowShortcut = parseShortcut(dict["showMainWindowShortcut"])
        s.showSettingsShortcut = parseShortcut(dict["showSettingsShortcut"])
        if let v = dict["launchAtLogin"], let b = Bool(v) { s.launchAtLogin = b }
        if let v = dict["defaultLayoutName"].map(parseStringValue), !v.isEmpty { s.defaultLayoutName = v }
        if let v = dict["appLanguage"] { s.appLanguage = v }
        if let v = dict["restServerEnabled"], let b = Bool(v) { s.restServerEnabled = b }
        if let v = dict["allowExternalAccess"], let b = Bool(v) { s.allowExternalAccess = b }
        if let v = dict["allowedCIDR"].map(parseStringValue) { s.allowedCIDR = v }
        if let v = dict["dataDirectoryPath"].map(parseStringValue), !v.isEmpty { s.dataDirectoryPath = v }
        if let v = dict["autoSaveOnSleep"], let b = Bool(v) { s.autoSaveOnSleep = b }
        if let v = dict["maxAutoSaves"], let i = Int(v) { s.maxAutoSaves = i }
        if let v = dict["restoreButtonStyle"].map(parseStringValue) { s.restoreButtonStyle = v }
        if let v = dict["confirmBeforeDelete"], let b = Bool(v) { s.confirmBeforeDelete = b }
        if let v = dict["showInCmdTab"], let b = Bool(v) { s.showInCmdTab = b }
        if let v = dict["clickSwitchToMain"], let b = Bool(v) { s.clickSwitchToMain = b }
        if let v = dict["theme"].map(parseStringValue) { s.theme = v }
        return s
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
