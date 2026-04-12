import Foundation
import AppKit
import ServiceManagement

@Observable @MainActor
final class AppState {
    let windowManager: WindowManager
    let layoutManager: LayoutManager
    let settingsService: SettingsService
    let restServer: RESTServer
    private let hotKeyService: HotKeyService
    private let displaySwitchService: DisplaySwitchService
    private let screenMoveService: ScreenMoveService

    var isRunning = false
    var connectionCount = 0
    var startTime = Date()
    var settings: AppSettings
    var hideMenuBar = false

    init() {
        let baseDir = YAMLLayoutStorageService.resolveDefaultBaseDirectory()
        let settingsService = YAMLSettingsService(baseDirectory: baseDir)
        let settings = settingsService.load()
        self.settings = settings
        self.settingsService = settingsService

        // _config.yml이 없으면 기본값으로 생성
        if !FileManager.default.fileExists(atPath: settingsService.configFilePath) {
            settingsService.save(settings)
        }

        let storageMode = settings.dataStorageMode ?? .host
        if storageMode == .host {
            YAMLLayoutStorageService.migrateRootDataIfNeeded()
            YAMLLayoutStorageService.copyShareDataIfNeeded()
        }

        let captureService = CGWindowCaptureService()
        let restoreService = AXWindowRestoreService()
        let storageService = YAMLLayoutStorageService(
            storageMode: storageMode
        )
        let accessService = SystemAccessibilityService()

        self.windowManager = WindowManager(
            captureService: captureService,
            restoreService: restoreService,
            accessibilityService: accessService
        )
        self.layoutManager = LayoutManager(storageService: storageService)
        self.hotKeyService = CarbonHotKeyService()
        self.displaySwitchService = DisplaySwitchService()
        self.screenMoveService = ScreenMoveService()

        let wm = windowManager
        let lm = layoutManager
        let handlers = RESTServerHandlers(
            captureCurrentWindows: { filterApps in wm.captureCurrentWindows(filterApps: filterApps) },
            restoreWindows: { windows, maxRetries, retryInterval, minimumScore, enableParallel in
                await wm.restoreWindows(windows, maxRetries: maxRetries, retryInterval: retryInterval, minimumScore: minimumScore, enableParallel: enableParallel)
            },
            runningAppNames: { wm.runningAppNames() },
            isAccessibilityGranted: { wm.isAccessibilityGranted() },
            getLayouts: { lm.layouts },
            loadMetadataList: { lm.loadMetadataList() },
            storageServiceLoad: { name in try lm.storageServiceLoad(name: name) },
            saveLayout: { name, windows in try lm.saveLayout(name: name, windows: windows) },
            renameLayout: { oldName, newName in try lm.renameLayout(oldName: oldName, newName: newName) },
            deleteLayout: { name in try lm.deleteLayout(name: name) },
            deleteAllLayouts: { try lm.deleteAllLayouts() },
            removeWindows: { layoutName, windowIds in try lm.removeWindows(layoutName: layoutName, windowIds: windowIds) },
            getSettings: { [weak settingsService] in
                guard let svc = settingsService else { return [:] }
                let s = svc.load()
                var dict: [String: Any] = [
                    "configFilePath": svc.configFilePath,
                    "excludedApps": s.excludedApps,
                    "maxRetries": s.maxRetries,
                    "retryInterval": s.retryInterval,
                    "minimumMatchScore": s.minimumMatchScore,
                    "enableParallelRestore": s.enableParallelRestore ?? true,
                    "restServerPort": s.restServerPort ?? 3016,
                    "logLevel": s.logLevel ?? 5,
                    "dataStorageMode": (s.dataStorageMode ?? .host).rawValue
                ]
                // 단축키 설정 (YAML에 없으면 기본값 사용)
                let d = AppSettings.defaults
                dict["saveShortcut"] = (s.saveShortcut ?? d.saveShortcut)?.displayString ?? "미설정"
                dict["restoreDefaultShortcut"] = (s.restoreDefaultShortcut ?? d.restoreDefaultShortcut)?.displayString ?? "미설정"
                dict["restoreLastShortcut"] = (s.restoreLastShortcut ?? d.restoreLastShortcut)?.displayString ?? "미설정"
                dict["appLanguage"] = s.appLanguage ?? "system"
                return dict
            },
            getDataDirectoryPath: { lm.dataDirectoryPath },
            getSettingsBasePath: { YAMLLayoutStorageService.resolveDefaultBaseDirectory().path },
            getDefaultLayoutName: { [weak settingsService] in
                settingsService?.load().defaultLayoutName
            },
            setDefaultLayoutName: { [weak settingsService] name in
                guard let svc = settingsService else { return }
                var s = svc.load()
                s.defaultLayoutName = name
                svc.save(s)
            }
        )
        self.restServer = RESTServer(handlers: handlers)
    }

    func initialize() {
        if let level = LogLevel(rawValue: settings.logLevel ?? 5) {
            Logger.shared.setLogLevel(level)
        }

        // Issue10 — Paid 버전 감지 시 실행하고, 성공하면 메뉴바만 숨김
        if detectPaidApp() != nil {
            if launchPaidApp() {
                logI("✅ fWarrange(Paid) 실행 성공 → 메뉴바 숨김, REST 서버 유지")
                hideMenuBar = true
            }
        }

        layoutManager.loadMetadataList()

        // REST 서버 시작 (항상 활성화)
        restServer.start(port: UInt16(settings.restServerPort ?? 3016))
        isRunning = true
        startTime = Date()

        // 접근성 권한 확인
        if !windowManager.isAccessibilityGranted() {
            logW("⚠️ Accessibility 권한이 필요합니다")
            windowManager.requestAccessibility()
        }

        // 글로벌 단축키 등록
        hotKeyService.register(settings: settings) { [weak self] action in
            guard let self else { return }
            self.handleHotKeyAction(action)
        }

        // 우클릭 디스플레이 전환 (설정에 따라)
        displaySwitchService.registerRightClickMonitor(enabled: false)

        // 로그인 시 자동 시작 동기화
        syncLaunchAtLogin(settings.launchAtLogin ?? false)
    }

    // MARK: - Login Item 관리

    func syncLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status != .enabled {
                        try service.register()
                        logI("✅ 로그인 시 자동 시작 등록")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        logI("✅ 로그인 시 자동 시작 해제")
                    }
                }
            } catch {
                logE("❌ LoginItem 설정 실패: \(error)")
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        settingsService.save(settings)
        syncLaunchAtLogin(enabled)
    }

    private func handleHotKeyAction(_ action: HotKeyAction) {
        switch action {
        case .save:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let name = "\(formatter.string(from: Date()))-hotkey"
            let windows = windowManager.captureCurrentWindows(filterApps: nil)
            try? layoutManager.saveLayout(name: name, windows: windows)
            logI("⌨️ 단축키 저장: '\(name)'")
        case .restoreDefault, .restoreLast:
            if let first = layoutManager.layouts.first {
                Task {
                    let layout = try? layoutManager.storageServiceLoad(name: first.name)
                    if let layout {
                        await windowManager.restoreWindows(layout.windows, maxRetries: settings.maxRetries, retryInterval: settings.retryInterval, minimumScore: settings.minimumMatchScore, enableParallel: settings.enableParallelRestore ?? true)
                    }
                }
            }
        case .showMainWindow, .showSettings:
            break // fWarrangeCli에서는 GUI 없음
        }
    }

    // MARK: - Paid 버전 (fWarrange.app) 감지 & 실행

    private static let paidAppSearchPaths = [
        "/Applications/fWarrange.app",
        "/Applications/_nowage_app/fWarrange.app",
        "/Applications/_finfra_app/fWarrange.app"
    ]

    /// Paid 앱 감지만 수행 (명시적 경로에서만 검색, ~/Library 제외)
    func detectPaidApp() -> URL? {
        for path in Self.paidAppSearchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Paid 앱 실행만 수행 (성공 여부 반환)
    @discardableResult
    func launchPaidApp() -> Bool {
        guard let url = detectPaidApp() else { return false }
        let success = NSWorkspace.shared.open(url)
        if success {
            logI("✅ fWarrange(Paid) 실행: \(url.path)")
        } else {
            logW("⚠️ fWarrange 실행 실패: \(url.path)")
        }
        return success
    }

    /// 기능 실행 시 호출: 감지 → 실행 → 안내 알림. 감지 실패 시 false 반환
    func tryLaunchPaidFeature() -> Bool {
        guard detectPaidApp() != nil else { return false }
        if launchPaidApp() {
            let alert = NSAlert()
            alert.messageText = "fWarrange launched"
            alert.informativeText = "fWarrange (paid version) has been launched.\nPlease use the feature from fWarrange."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            NSApplication.shared.activate(ignoringOtherApps: true)
            alert.runModal()
            return true
        }
        return false
    }

    var uptimeString: String {
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
