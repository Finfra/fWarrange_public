import Foundation
import AppKit

// MARK: - 데이터 저장 모드

enum DataStorageMode: String, Codable, CaseIterable {
    case host = "host"     // hostname별 독립 저장
    case share = "share"   // _share 공용 저장
}

// MARK: - 단축키 데이터 타입

struct KeyboardShortcutConfig: Codable, Equatable {
    var keyCode: UInt16      // 가상 키 코드 (예: 1=S, 15=R)
    var modifierFlags: UInt  // NSEvent.ModifierFlags.rawValue

    var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += Self.keyLabel(for: keyCode)
        return result
    }

    static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"; case 1: return "S"; case 2: return "D"
        case 3: return "F"; case 4: return "H"; case 5: return "G"
        case 6: return "Z"; case 7: return "X"; case 8: return "C"
        case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"
        case 16: return "Y"; case 17: return "T"
        case 18: return "1"; case 19: return "2"; case 20: return "3"
        case 21: return "4"; case 22: return "6"; case 23: return "5"
        case 25: return "9"; case 26: return "7"; case 28: return "8"; case 29: return "0"
        case 31: return "O"; case 32: return "U"; case 34: return "I"; case 35: return "P"
        case 37: return "L"; case 38: return "J"; case 40: return "K"
        case 41: return ";"; case 42: return "'"
        case 43: return ","; case 44: return "/"
        case 45: return "N"; case 46: return "M"; case 47: return "."
        case 36: return "↩"; case 48: return "⇥"; case 49: return "Space"
        case 51: return "⌫"; case 53: return "⎋"; case 117: return "⌦"
        case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
        // Function keys
        case 122: return "F1"; case 120: return "F2"; case 99: return "F3"
        case 118: return "F4"; case 96: return "F5"; case 97: return "F6"
        case 98: return "F7"; case 100: return "F8"; case 101: return "F9"
        case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        case 105: return "F13"; case 107: return "F14"; case 113: return "F15"
        default: return "(\(keyCode))"
        }
    }

    // MARK: - 라벨 → keyCode 역매핑

    private static let labelToKeyCode: [String: UInt16] = {
        let pairs: [(String, UInt16)] = [
            ("A", 0), ("S", 1), ("D", 2), ("F", 3), ("H", 4), ("G", 5),
            ("Z", 6), ("X", 7), ("C", 8), ("V", 9), ("B", 11), ("Q", 12),
            ("W", 13), ("E", 14), ("R", 15), ("Y", 16), ("T", 17),
            ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("6", 22), ("5", 23),
            ("9", 25), ("7", 26), ("8", 28), ("0", 29),
            ("O", 31), ("U", 32), ("I", 34), ("P", 35),
            ("L", 37), ("J", 38), ("K", 40),
            (";", 41), ("'", 42), (",", 43), ("/", 44),
            ("N", 45), ("M", 46), (".", 47),
            ("↩", 36), ("⇥", 48), ("Space", 49),
            ("⌫", 51), ("⎋", 53), ("⌦", 117),
            ("←", 123), ("→", 124), ("↓", 125), ("↑", 126),
            ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118),
            ("F5", 96), ("F6", 97), ("F7", 98), ("F8", 100),
            ("F9", 101), ("F10", 109), ("F11", 103), ("F12", 111),
            ("F13", 105), ("F14", 107), ("F15", 113),
        ]
        var map: [String: UInt16] = [:]
        for (label, code) in pairs {
            map[label] = code
        }
        return map
    }()

    /// human-readable 문자열("⌘F7", "⌃⌥⇧⌘S")에서 KeyboardShortcutConfig 생성
    static func from(displayString raw: String) -> KeyboardShortcutConfig? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        // 중괄호 제거: {⌘F7} → ⌘F7
        if s.hasPrefix("{") && s.hasSuffix("}") {
            s = String(s.dropFirst().dropLast())
        }

        // 수정자 추출
        var flags: NSEvent.ModifierFlags = []
        let modifierChars: [(Character, NSEvent.ModifierFlags)] = [
            ("⌃", .control), ("^", .control),
            ("⌥", .option),
            ("⇧", .shift),
            ("⌘", .command),
        ]
        for (ch, flag) in modifierChars {
            if s.contains(ch) {
                flags.insert(flag)
                s = s.replacingOccurrences(of: String(ch), with: "")
            }
        }

        // 남은 문자열이 키 라벨
        let keyStr = s.trimmingCharacters(in: .whitespaces)
        guard !keyStr.isEmpty else { return nil }

        // 대소문자 무시 매칭
        let upper = keyStr.uppercased()
        guard let keyCode = labelToKeyCode[upper] ?? labelToKeyCode[keyStr] else { return nil }

        return KeyboardShortcutConfig(keyCode: keyCode, modifierFlags: flags.rawValue)
    }
}

// MARK: - 앱 설정 (fWarrangeCli)

struct AppSettings: Codable {
    var excludedApps: [String]
    var maxRetries: Int
    var retryInterval: Double
    var minimumMatchScore: Int
    var enableParallelRestore: Bool?  // nil = 기본값 true, 앱별 병렬 복구 활성화
    var restServerPort: Int?           // nil = 기본값 3016, 서버 포트
    var logLevel: Int?
    var dataStorageMode: DataStorageMode?  // nil = 기본값 .host

    // 단축키 설정 (HotKeyService 연동용)
    var saveShortcut: KeyboardShortcutConfig?
    var restoreDefaultShortcut: KeyboardShortcutConfig?
    var restoreLastShortcut: KeyboardShortcutConfig?
    var showMainWindowShortcut: KeyboardShortcutConfig?
    var showSettingsShortcut: KeyboardShortcutConfig?

    // 로그인 시 자동 시작
    var launchAtLogin: Bool?

    // 기본 레이아웃 이름
    var defaultLayoutName: String?

    // 언어 설정 (locale 엔드포인트 호환용)
    var appLanguage: String?

    // REST API 서버 (API 탭)
    var restServerEnabled: Bool?       // nil = 기본 true
    var allowExternalAccess: Bool?     // nil = 기본 false
    var allowedCIDR: String?           // nil = "192.168.0.0/16"

    // 데이터 경로 오버라이드 (General 탭)
    var dataDirectoryPath: String?

    // 자동 저장 (Advanced 탭)
    var autoSaveOnSleep: Bool?         // 슬립/종료 시 자동 저장
    var maxAutoSaves: Int?             // 최대 보관 개수

    // UI 옵션 (Advanced 탭, GUI 앱이 읽어가는 설정)
    var restoreButtonStyle: String?    // "iconOnly" | "nameIcon" | "nameOnly"
    var confirmBeforeDelete: Bool?
    var showInCmdTab: Bool?
    var clickSwitchToMain: Bool?
    var theme: String?                 // "system" | "light" | "dark"

    static let defaultExcludedApps: [String] = [
        "Activity Monitor",
        "System Settings"
    ]

    /// 지원 언어 목록
    static let supportedLanguages: [(code: String, label: String)] = [
        ("system", "시스템 기본"),
        ("ko", "한국어"),
        ("en", "English"),
        ("ja", "日本語")
    ]

    static let defaults = AppSettings(
        excludedApps: defaultExcludedApps,
        maxRetries: 5,
        retryInterval: 0.5,
        minimumMatchScore: 30,
        enableParallelRestore: true,
        restServerPort: 3016,
        logLevel: 5,
        dataStorageMode: .host,
        // 단축키: _config.yml에 명시된 항목만 글로벌 등록되어야 하므로 default는 모두 nil.
        // 사용자가 yml에서 라인 삭제 시 글로벌 등록도 사라지도록 보장 (Issue61).
        saveShortcut: nil,
        restoreDefaultShortcut: nil,
        restoreLastShortcut: nil,
        showMainWindowShortcut: nil,
        showSettingsShortcut: nil,
        launchAtLogin: false,
        defaultLayoutName: nil,
        appLanguage: nil,
        restServerEnabled: true,
        allowExternalAccess: false,
        allowedCIDR: "192.168.0.0/16",
        dataDirectoryPath: nil,
        autoSaveOnSleep: true,
        maxAutoSaves: 5,
        restoreButtonStyle: "nameIcon",
        confirmBeforeDelete: true,
        showInCmdTab: true,
        clickSwitchToMain: false,
        theme: "system"
    )
}
