import Foundation

/// fSnippetCli LocalizedStringManager 패턴 준용 — appLanguage 설정 기반 UI 문자열 관리
func L10n(_ key: String, lang: String = LocalizedStringManager.currentLanguage) -> String {
    LocalizedStringManager.string(key, lang: lang)
}

enum LocalizedStringManager {
    static var currentLanguage: String = "en"

    static func apply(language: String?) {
        let raw = language ?? "system"
        let normalized = normalizeLanguageCode(raw)
        if normalized == "system" {
            currentLanguage = String((Locale.preferredLanguages.first ?? "en").prefix(2))
        } else {
            currentLanguage = normalized
        }
    }

    static func string(_ key: String, lang: String) -> String {
        (strings[lang] ?? strings["en"]!)[key] ?? key
    }

    static func normalizeLanguageCode(_ code: String) -> String {
        let map: [String: String] = [
            "kr": "ko", "jp": "ja", "cn": "zh-Hans", "tw": "zh-Hant",
            "us": "en", "gb": "en", "br": "pt",
        ]
        return map[code.lowercased()] ?? code.lowercased()
    }

    private static let strings: [String: [String: String]] = [
        "en": [
            "menu.launch_at_login": "Launch at Login",
            "menu.open_log_folder": "Open Log Folder",
            "menu.quit": "Quit",
            "menu.open_paid_app": "Open fWarrange",
            "menu.open_config_folder": "Open Config Folder",
            "status.running": "Running",
            "status.stopped": "Stopped",
            "status.label": "Status:",
            "alert.paid_not_found.title": "fWarrange Not Found",
            "alert.paid_not_found.message": "fWarrange (App Store) is not installed.\nPlease install from the App Store, or select the app directly.",
            "alert.paid_not_found.app_store": "App Store",
            "alert.paid_not_found.browse": "Browse...",
            "alert.paid_not_found.cancel": "Cancel",
            "alert.invalid_app.title": "Invalid App",
            "alert.invalid_app.message": "The selected app is not fWarrange.",
        ],
        "ko": [
            "menu.launch_at_login": "로그인 시 자동 시작",
            "menu.open_log_folder": "로그 폴더 열기",
            "menu.quit": "종료",
            "menu.open_paid_app": "fWarrange 앱 열기",
            "menu.open_config_folder": "설정 파일 폴더 열기",
            "status.running": "실행 중",
            "status.stopped": "중지됨",
            "status.label": "상태:",
            "alert.paid_not_found.title": "fWarrange를 찾을 수 없습니다",
            "alert.paid_not_found.message": "fWarrange (App Store 버전)가 설치되어 있지 않습니다.\nApp Store에서 설치하거나, 이미 설치된 경우 앱을 직접 선택해주세요.",
            "alert.paid_not_found.app_store": "App Store",
            "alert.paid_not_found.browse": "직접 찾기...",
            "alert.paid_not_found.cancel": "취소",
            "alert.invalid_app.title": "잘못된 앱",
            "alert.invalid_app.message": "선택한 앱이 fWarrange가 아닙니다.",
        ],
        "ja": [
            "menu.launch_at_login": "ログイン時に起動",
            "menu.open_log_folder": "ログフォルダを開く",
            "menu.quit": "終了",
            "menu.open_paid_app": "fWarrangeを開く",
            "menu.open_config_folder": "設定フォルダを開く",
            "status.running": "実行中",
            "status.stopped": "停止中",
            "status.label": "状態:",
            "alert.paid_not_found.title": "fWarrangeが見つかりません",
            "alert.paid_not_found.message": "fWarrange (App Store版) がインストールされていません。\nApp Storeからインストールするか、直接アプリを選択してください。",
            "alert.paid_not_found.app_store": "App Store",
            "alert.paid_not_found.browse": "参照...",
            "alert.paid_not_found.cancel": "キャンセル",
            "alert.invalid_app.title": "無効なアプリ",
            "alert.invalid_app.message": "選択したアプリはfWarrangeではありません。",
        ],
    ]
}
