import Foundation
import AppKit
import ServiceManagement

@Observable @MainActor
final class AppState {
    let windowManager: WindowManager
    let layoutManager: LayoutManager
    let settingsService: SettingsService
    let restServer: RESTServer
    let paidAppStore: PaidAppStateStore
    let paidAppMonitor: PaidAppMonitor
    private let hotKeyService: HotKeyService
    private let screenMoveService: ScreenMoveService
    private let modeStorageService: ModeStorageService
    private let appLauncherService: AppLauncherService

    var isRunning = false
    var connectionCount = 0
    var startTime = Date()
    var settings: AppSettings
    var activeModeName: String?
    private var modeActivationInProgress = false

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
        self.modeStorageService = YAMLModeStorageService(baseDirectory: baseDir)
        self.hotKeyService = CarbonHotKeyService()
        self.screenMoveService = ScreenMoveService()
        self.appLauncherService = NSWorkspaceAppLauncherService()

        let wm = windowManager
        let lm = layoutManager
        weak var weakSelf: AppState? = nil // set after init
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
            nextDailySequenceName: { lm.nextDailySequenceName() },
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
            },
            updateShortcuts: { [weak settingsService] body -> [String: String] in
                guard let svc = settingsService else { return [:] }
                var s = svc.load()
                func apply(_ key: String, set: (KeyboardShortcutConfig?) -> Void) {
                    guard let value = body[key] else { return }
                    if value is NSNull {
                        set(nil)
                    } else if let str = value as? String {
                        let trimmed = str.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            set(nil)
                        } else if let cfg = KeyboardShortcutConfig.from(displayString: trimmed) {
                            set(cfg)
                        }
                    }
                }
                apply("saveShortcut") { s.saveShortcut = $0 }
                apply("restoreDefaultShortcut") { s.restoreDefaultShortcut = $0 }
                apply("restoreLastShortcut") { s.restoreLastShortcut = $0 }
                apply("showMainWindowShortcut") { s.showMainWindowShortcut = $0 }
                apply("showSettingsShortcut") { s.showSettingsShortcut = $0 }
                svc.save(s)
                NotificationCenter.default.post(name: .fWarrangeCliShortcutsUpdated, object: nil)
                return [
                    "saveShortcut": s.saveShortcut?.displayString ?? "",
                    "restoreDefaultShortcut": s.restoreDefaultShortcut?.displayString ?? "",
                    "restoreLastShortcut": s.restoreLastShortcut?.displayString ?? "",
                    "showMainWindowShortcut": s.showMainWindowShortcut?.displayString ?? "",
                    "showSettingsShortcut": s.showSettingsShortcut?.displayString ?? ""
                ]
            },
            getFullSettings: { [weak settingsService] in
                guard let svc = settingsService else { return [:] }
                return AppState.fullSettingsDict(svc.load())
            },
            patchSettings: { [weak settingsService] body in
                guard let svc = settingsService else { return [:] }
                var s = svc.load()
                AppState.applySettingsPatch(&s, body: body)
                svc.save(s)
                return AppState.fullSettingsDict(s)
            },
            getExcludedApps: { [weak settingsService] in
                settingsService?.load().excludedApps ?? []
            },
            setExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return apps }
                var s = svc.load()
                s.excludedApps = apps
                svc.save(s)
                return s.excludedApps
            },
            addExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return apps }
                var s = svc.load()
                var set = Array(s.excludedApps)
                for a in apps where !set.contains(a) { set.append(a) }
                s.excludedApps = set
                svc.save(s)
                return s.excludedApps
            },
            removeExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return [] }
                var s = svc.load()
                s.excludedApps = s.excludedApps.filter { !apps.contains($0) }
                svc.save(s)
                return s.excludedApps
            },
            resetExcludedApps: { [weak settingsService] in
                guard let svc = settingsService else { return AppSettings.defaultExcludedApps }
                var s = svc.load()
                s.excludedApps = AppSettings.defaultExcludedApps
                svc.save(s)
                return s.excludedApps
            },
            factoryResetSettings: { [weak settingsService] in
                guard let svc = settingsService else { return [:] }
                svc.resetToDefaults()
                return AppState.fullSettingsDict(svc.load())
            },
            getShortcutsDisplay: { [weak settingsService] in
                guard let svc = settingsService else { return [:] }
                let s = svc.load()
                return [
                    "saveShortcut": s.saveShortcut?.displayString ?? "",
                    "restoreDefaultShortcut": s.restoreDefaultShortcut?.displayString ?? "",
                    "restoreLastShortcut": s.restoreLastShortcut?.displayString ?? "",
                    "showMainWindowShortcut": s.showMainWindowShortcut?.displayString ?? "",
                    "showSettingsShortcut": s.showSettingsShortcut?.displayString ?? ""
                ]
            },
            getLogFilePath: {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                return "\(home)/Documents/finfra/fWarrangeData/logs/wlog.log"
            },
            applyApiSettings: { [weak settingsService] enabled, newPort, external, cidr in
                let prev = settingsService?.load() ?? AppSettings.defaults
                var s = prev
                if let v = enabled { s.restServerEnabled = v }
                if let v = newPort { s.restServerPort = v }
                if let v = external { s.allowExternalAccess = v }
                if let v = cidr, !v.isEmpty { s.allowedCIDR = v }
                settingsService?.save(s)
                let targetPort = UInt16(s.restServerPort ?? 3016)
                let targetExternal = s.allowExternalAccess ?? false
                let targetCidr = s.allowedCIDR ?? "192.168.0.0/16"
                let shouldRun = s.restServerEnabled ?? true

                // 재시작 필요 여부 판단: 서버 동작에 영향을 주는 필드가 실제로 변경된 경우에만
                let prevRun = prev.restServerEnabled ?? true
                let prevPort = prev.restServerPort ?? 3016
                let prevExternal = prev.allowExternalAccess ?? false
                let needsRestart = (prevRun != shouldRun) ||
                                   (prevPort != Int(targetPort)) ||
                                   (prevExternal != targetExternal)

                if needsRestart {
                    // 비동기 재시작 (현재 연결을 바로 끊으면 응답이 유실되므로 지연)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard let self = weakSelf else { return }
                        self.restServer.stop()
                        self.restServer.allowExternal = targetExternal
                        self.restServer.allowedCIDR = targetCidr
                        if shouldRun {
                            self.restServer.start(port: targetPort)
                        }
                    }
                } else {
                    // CIDR만 바뀐 경우 listener 재시작 없이 값만 갱신
                    weakSelf?.restServer.allowedCIDR = targetCidr
                }
                return (isRunning: shouldRun, port: Int(targetPort), external: targetExternal, cidr: targetCidr)
            },
            // Mode 핸들러
            listModes: {
                guard let self = weakSelf else { return [] }
                return try self.modeStorageService.listModeMetadata()
            },
            loadMode: { name in
                guard let self = weakSelf else { throw ModeStorageError.notFound(name) }
                return try self.modeStorageService.load(name: name)
            },
            createMode: { name, icon, shortcut, layoutRef in
                guard let self = weakSelf else { throw ModeStorageError.notFound(name) }
                let mode = Mode(name: name, icon: icon, shortcut: shortcut, layoutRef: layoutRef)
                try self.modeStorageService.save(mode)
                return mode
            },
            updateMode: { name, body in
                guard let self = weakSelf else { throw ModeStorageError.notFound(name) }
                var mode = try self.modeStorageService.load(name: name)
                if let icon = body["icon"] as? String { mode.icon = icon }
                if let shortcut = body["shortcut"] as? String { mode.shortcut = shortcut.isEmpty ? nil : shortcut }
                if body["shortcut"] is NSNull { mode.shortcut = nil }
                if let layout = body["layout"] as? String { mode.layoutRef = layout }
                // requiredApps 수정 지원
                if let apps = body["requiredApps"] as? [[String: Any]] {
                    mode.requiredApps = apps.compactMap { dict in
                        guard let bundleId = dict["bundleId"] as? String else { return nil }
                        let actionStr = dict["action"] as? String ?? "launch"
                        let action = AppAction(rawValue: actionStr) ?? .launch
                        return AppConfig(bundleId: bundleId, action: action)
                    }
                }
                try self.modeStorageService.save(mode)
                return mode
            },
            deleteMode: { name in
                guard let self = weakSelf else { throw ModeStorageError.notFound(name) }
                try self.modeStorageService.delete(name: name)
                if weakSelf?.activeModeName == name {
                    weakSelf?.activeModeName = nil
                }
            },
            activateMode: { name in
                guard let self = weakSelf else { throw ModeStorageError.notFound(name) }
                guard !self.modeActivationInProgress else {
                    throw ModeActivationError.alreadyInProgress
                }
                self.modeActivationInProgress = true
                defer { self.modeActivationInProgress = false }

                let mode = try self.modeStorageService.load(name: name)
                let layout = try self.layoutManager.storageServiceLoad(name: mode.layoutRef)
                let results = await self.windowManager.restoreWindows(
                    layout.windows,
                    maxRetries: self.settings.maxRetries,
                    retryInterval: self.settings.retryInterval,
                    minimumScore: self.settings.minimumMatchScore,
                    enableParallel: self.settings.enableParallelRestore ?? true
                )
                // Phase 2B: requiredApps 자동 실행/숨기기
                await self.appLauncherService.applyAppConfigs(mode.requiredApps)
                self.activeModeName = name
                return (mode: mode, restoreResults: results)
            },
            getActiveModeName: {
                weakSelf?.activeModeName
            }
        )
        let paidAppStore = PaidAppStateStore()
        self.paidAppStore = paidAppStore
        self.paidAppMonitor = PaidAppMonitor()
        self.restServer = RESTServer(handlers: handlers, paidAppStore: paidAppStore)
        weakSelf = self
    }

    // MARK: - v2 설정 직렬화/패치 헬퍼

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

    static func applySettingsPatch(_ s: inout AppSettings, body: [String: Any]) {
        if let v = body["appLanguage"] as? String { s.appLanguage = v }
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

    func initialize() {
        let effectiveLogLevel = Env.logLevel ?? LogLevel(rawValue: settings.logLevel ?? 5) ?? .critical
        Logger.shared.setLogLevel(effectiveLogLevel)

        // 2-모드 메뉴바 — cliApp이 직접 관리. paidApp 실행 여부는 PaidAppMonitor로 감지.
        if detectPaidApp() != nil {
            _ = launchPaidApp()
            logI("✅ fWarrange(Paid) 실행 — cliApp 메뉴바 유지 (2-모드 관리)")
        }

        // PaidAppMonitor NSWorkspace 구독 시작
        paidAppMonitor.startObserving()

        layoutManager.loadMetadataList()

        // REST 서버 시작 (항상 활성화, FWARRANGE_PORT env 우선)
        restServer.start(port: Env.port ?? UInt16(settings.restServerPort ?? 3016))
        isRunning = true
        startTime = Date()

        // Issue39 매트릭스: app start × brew=stopped → brew services start 호출.
        // launchd 기동 / 옵트아웃 / 이미 로드 / brew 미설치는 내부에서 skip.
        // 중복 인스턴스는 SingleInstanceGuard 가 exit(0) 으로 차단.
        BrewServiceSync.onAppStart()

        // 접근성 권한 확인 (prompt:false — ad-hoc 서명에서는 시스템 프롬프트 무효)
        if !windowManager.isAccessibilityGranted() {
            logW("⚠️ Accessibility 권한이 필요합니다")
            showAccessibilityGuide()
        }

        // 글로벌 단축키 등록 (FWARRANGE_DISABLE_HOTKEYS=1 시 건너뜀)
        if !Env.hotkeysDisabled {
            hotKeyService.register(settings: settings) { [weak self] action in
                guard let self else { return }
                self.handleHotKeyAction(action)
            }

            // REST 경로로 단축키가 갱신되면 재로드 후 재등록
            NotificationCenter.default.addObserver(
                forName: .fWarrangeCliShortcutsUpdated,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.settings = self.settingsService.load()
                    self.hotKeyService.register(settings: self.settings) { [weak self] action in
                        self?.handleHotKeyAction(action)
                    }
                    logI("🔁 단축키 재등록 완료 (REST 업데이트 반영)")
                }
            }
        } else {
            logI("ℹ️ FWARRANGE_DISABLE_HOTKEYS=1 — 글로벌 단축키 등록 건너뜀")
        }

        // Issue36: brew services 배타 원칙 — 앱 내부 SMAppService 자동 등록 경로 제거
        // launchAtLogin prefs 는 backward compat 유지, 실제 Login Item 등록은 brew services 가 담당

        // fWarrange(Paid) 종료 감지 → 메뉴바 자동 복원
        observePaidAppTermination()
    }

    // MARK: - fWarrange(Paid) 종료 감시

    /// NSWorkspace notification으로 fWarrange 앱 종료를 감지하여 메뉴바를 자동 복원
    private func observePaidAppTermination() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "kr.finfra.fWarrange" else { return }
            Task { @MainActor in
                // Issue197: kill -9 등 비정상 종료 시 Store stale 잔류 방지
                let cleaned = self.paidAppStore.unregisterAllForBundleId("kr.finfra.fWarrange")
                if cleaned {
                    logI("🧹 fWarrange 종료 감지 → PaidAppStateStore cleanup 완료 (bundleId: kr.finfra.fWarrange)")
                }
            }
        }
    }

    // MARK: - Login Item 관리 (Issue36: obsolete, brew services 배타 원칙)

    // Issue36: `brew services`(LaunchAgent) 가 Login Item 역할 전담 → 앱 내부 SMAppService 경로는 obsolete.
    // 함수 시그니처 유지 (backward compat), 내부는 no-op + 경고 로그.
    // API v2 `launchAtLogin` prefs 는 단순 저장만 수행하고 실제 Login Item 등록/해제는 하지 않음.
    func syncLaunchAtLogin(_ enabled: Bool) {
        logW("⚠️ Issue36: brew services 배타 원칙, SMAppService 경로 obsolete (enabled=\(enabled))")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        settingsService.save(settings)
        syncLaunchAtLogin(enabled)
    }

    private func handleHotKeyAction(_ action: HotKeyAction) {
        switch action {
        case .save:
            let name = layoutManager.nextDailySequenceName()
            let windows = windowManager.captureCurrentWindows(filterApps: nil)
            try? layoutManager.saveLayout(name: name, windows: windows)
            ChangeTracker.shared.record(type: "layout.created", target: name)
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

    /// Issue195: fwarrange:// URL Scheme으로 paidApp 특정 화면 열기.
    /// paidApp 미설치 시 `launchPaidApp()`이 false를 반환하며 UI에서 안내 처리.
    func openPaidApp(action: String) {
        guard let url = URL(string: "fwarrange://command?action=\(action)") else { return }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            logI("🔗 paidApp URL Scheme 호출 성공: action=\(action)")
        } else {
            logW("⚠️ paidApp URL Scheme 호출 실패: action=\(action) — paidApp 미등록 또는 미설치")
        }
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

    // MARK: - Accessibility 권한 안내 (Issue189)

    /// Accessibility 권한 미부여 시 NSAlert 안내 + 시스템 설정 deep link
    private func showAccessibilityGuide() {
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Accessibility 권한 필요"
            alert.informativeText = """
                fWarrangeCli가 창 위치를 제어하려면 접근성 권한이 필요합니다.

                시스템 설정 > 개인정보 보호 및 보안 > 접근성에서
                fWarrangeCli를 추가하고 허용해주세요.
                """
            alert.addButton(withTitle: "설정 열기")
            alert.addButton(withTitle: "나중에")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self?.windowManager.openAccessibilitySettings()
            }
        }
    }
}
