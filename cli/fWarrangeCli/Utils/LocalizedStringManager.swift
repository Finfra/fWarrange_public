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
            "menu.about": "About fWarrangeCli",
            "menu.about.cli": "About fWarrangeCli",
            "menu.about.paid": "About fWarrange",
            "menu.save_layout": "Save Window Layout",
            "menu.restore_last": "Restore Last Layout",
            "menu.restore_default": "Restore Default Layout",
            "menu.layout.default_marker": "%@   Default",
            "menu.layout.more_count": "...and %d more",
            "menu.layout.unset_default": "⭐ (Not Set)   Default",
            "menu.open_main_window": "Open Main Window",
            "menu.daemon.title": "Daemon",
            "menu.daemon.status_running": "Status: Running · Port %d · Uptime %@",
            "menu.daemon.status_stopped": "Status: Stopped",
            "menu.daemon.restart": "Restart Daemon",
            "menu.daemon.pause": "Pause REST API",
            "menu.daemon.resume": "Resume REST API",
            "menu.config.title": "Configuration",
            "menu.config.settings": "Settings…",
            "menu.config.open_file": "Open Config File",
            "menu.config.open_data": "Open Data Folder",
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
            "menu.about": "fWarrangeCli 정보",
            "menu.about.cli": "fWarrangeCli 정보",
            "menu.about.paid": "fWarrange 정보",
            "menu.save_layout": "창 레이아웃 저장",
            "menu.restore_last": "최근 레이아웃 복구",
            "menu.restore_default": "기본 레이아웃 복구",
            "menu.layout.default_marker": "%@   기본",
            "menu.layout.more_count": "...외 %d개",
            "menu.layout.unset_default": "⭐ (미지정)   기본",
            "menu.open_main_window": "메인 창 열기",
            "menu.daemon.title": "데몬",
            "menu.daemon.status_running": "상태: 실행 중 · 포트 %d · 가동 %@",
            "menu.daemon.status_stopped": "상태: 중지됨",
            "menu.daemon.restart": "데몬 재시작",
            "menu.daemon.pause": "REST API 일시 정지",
            "menu.daemon.resume": "REST API 재개",
            "menu.config.title": "설정",
            "menu.config.settings": "환경설정…",
            "menu.config.open_file": "설정 파일 열기",
            "menu.config.open_data": "데이터 폴더 열기",
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
            "menu.about": "fWarrangeCliについて",
            "menu.about.cli": "fWarrangeCliについて",
            "menu.about.paid": "fWarrangeについて",
            "menu.save_layout": "ウィンドウレイアウトを保存",
            "menu.restore_last": "最近のレイアウトを復元",
            "menu.restore_default": "デフォルトレイアウトを復元",
            "menu.layout.default_marker": "%@   デフォルト",
            "menu.layout.more_count": "...他%d件",
            "menu.layout.unset_default": "⭐ (未設定)   デフォルト",
            "menu.open_main_window": "メインウィンドウを開く",
            "menu.daemon.title": "デーモン",
            "menu.daemon.status_running": "状態: 実行中 · ポート%d · 稼働時間 %@",
            "menu.daemon.status_stopped": "状態: 停止中",
            "menu.daemon.restart": "デーモンを再起動",
            "menu.daemon.pause": "REST APIを一時停止",
            "menu.daemon.resume": "REST APIを再開",
            "menu.config.title": "設定",
            "menu.config.settings": "環境設定…",
            "menu.config.open_file": "設定ファイルを開く",
            "menu.config.open_data": "データフォルダを開く",
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
