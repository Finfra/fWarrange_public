import Foundation

// MARK: - v2 API 설정 직렬화/패치 헬퍼

extension AppSettings {
    /// AppSettings를 v2 REST API의 full settings dict로 변환
    static func fullSettingsDict(_ s: AppSettings) -> [String: Any] {
        var d: [String: Any] = [
            "excludedApps": s.excludedApps,
            "maxRetries": s.maxRetries,
            "retryInterval": s.retryInterval,
            "minimumMatchScore": s.minimumMatchScore,
            "enableParallelRestore": s.enableParallelRestore ?? true,
            "restServerPort": s.restServerPort ?? 3016,
            "logLevel": s.logLevel ?? 5,
            "dataStorageMode": (s.dataStorageMode ?? .host).rawValue,
            "launchAtLogin": s.launchAtLogin ?? false,
            "appLanguage": s.appLanguage ?? "system",
            "restServerEnabled": s.restServerEnabled ?? true,
            "allowExternalAccess": s.allowExternalAccess ?? false,
            "allowedCIDR": s.allowedCIDR ?? "192.168.0.0/16",
            "autoSaveOnSleep": s.autoSaveOnSleep ?? true,
            "maxAutoSaves": s.maxAutoSaves ?? 5,
            "restoreButtonStyle": s.restoreButtonStyle ?? "nameIcon",
            "confirmBeforeDelete": s.confirmBeforeDelete ?? true,
            "showInCmdTab": s.showInCmdTab ?? true,
            "clickSwitchToMain": s.clickSwitchToMain ?? false,
            "theme": s.theme ?? "system"
        ]
        if let p = s.dataDirectoryPath { d["dataDirectoryPath"] = p }
        if let n = s.defaultLayoutName { d["defaultLayoutName"] = n }
        return d
    }

    /// REST API PATCH 요청의 body를 AppSettings에 적용
    /// appLanguage 변경 시 호출자가 applyLanguageSetting()을 별도로 호출해야 함
    static func applySettingsPatch(_ s: inout AppSettings, body: [String: Any]) {
        if let v = body["appLanguage"] as? String {
            s.appLanguage = v
        }
        if let v = body["dataStorageMode"] as? String, let m = DataStorageMode(rawValue: v) { s.dataStorageMode = m }
        if let v = body["dataDirectoryPath"] as? String { s.dataDirectoryPath = v.isEmpty ? nil : v }
        if body["dataDirectoryPath"] is NSNull { s.dataDirectoryPath = nil }
        if let v = body["launchAtLogin"] as? Bool { s.launchAtLogin = v }
        if let v = body["theme"] as? String { s.theme = v }
        if let v = body["maxRetries"] as? Int { s.maxRetries = v }
        if let v = body["retryInterval"] as? Double { s.retryInterval = v }
        if let v = body["retryInterval"] as? Int { s.retryInterval = Double(v) }
        if let v = body["minimumMatchScore"] as? Int { s.minimumMatchScore = v }
        if let v = body["enableParallelRestore"] as? Bool { s.enableParallelRestore = v }
        if let v = body["excludedApps"] as? [String] { s.excludedApps = v }
        if let v = body["restServerEnabled"] as? Bool { s.restServerEnabled = v }
        if let v = body["restServerPort"] as? Int { s.restServerPort = v }
        if let v = body["allowExternalAccess"] as? Bool { s.allowExternalAccess = v }
        if let v = body["allowedCIDR"] as? String { s.allowedCIDR = v }
        if let v = body["logLevel"] as? Int { s.logLevel = v }
        if let v = body["autoSaveOnSleep"] as? Bool { s.autoSaveOnSleep = v }
        if let v = body["maxAutoSaves"] as? Int { s.maxAutoSaves = v }
        if let v = body["restoreButtonStyle"] as? String { s.restoreButtonStyle = v }
        if let v = body["confirmBeforeDelete"] as? Bool { s.confirmBeforeDelete = v }
        if let v = body["showInCmdTab"] as? Bool { s.showInCmdTab = v }
        if let v = body["clickSwitchToMain"] as? Bool { s.clickSwitchToMain = v }
        if let v = body["defaultLayoutName"] as? String { s.defaultLayoutName = v.isEmpty ? nil : v }
    }
}
