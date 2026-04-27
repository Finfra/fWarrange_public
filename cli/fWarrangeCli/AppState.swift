import Foundation
import AppKit

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

    /// appLanguage 설정에 따른 실효 언어 코드 — settings.appLanguage 변경 시 SwiftUI 자동 재렌더링
    var effectiveLanguage: String {
        let raw = settings.appLanguage ?? "system"
        let normalized = LocalizedStringManager.normalizeLanguageCode(raw)
        if normalized == "system" {
            return String((Locale.preferredLanguages.first ?? "en").prefix(2))
        }
        return normalized
    }
    private var modeActivationInProgress = false

    // 메뉴바 아이콘: paidApp 실행 중이면 paidApp 아이콘, 미실행이면 cliApp 아이콘
    var menuBarIcon: NSImage = AppState.makeCLIIcon()
    var menuBarIconIsTemplate: Bool = true

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

        // appLanguage 설정 적용 (Issue: appLanguage가 _config.yml에서 로드되지 않는 문제)
        AppState.applyLanguageSetting(settings.appLanguage)

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
                return AppSettings.fullSettingsDict(svc.load())
            },
            patchSettings: { [weak settingsService] body in
                guard let svc = settingsService else { return [:] }
                var s = svc.load()
                // appLanguage 변경 감지
                let oldLanguage = s.appLanguage
                AppSettings.applySettingsPatch(&s, body: body)
                if let newLanguage = body["appLanguage"] as? String, newLanguage != oldLanguage {
                    AppState.applyLanguageSetting(newLanguage)
                }
                svc.save(s)
                return AppSettings.fullSettingsDict(s)
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
                return AppSettings.fullSettingsDict(svc.load())
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
        let paidAppStore = PaidAppStateStore { oldSessionId, newSessionId, oldPid, newPid in
            // stale 세션 감지 시 logger에 replaced 이벤트 기록
            PaidAppStateLogger.shared.append(.replaced(
                oldSessionId: oldSessionId,
                newSessionId: newSessionId,
                oldPid: oldPid,
                newPid: newPid
            ))
            logW("⚠️ paidApp 세션 교체 감지: 기존 sessionId=\(oldSessionId) → 신규 sessionId=\(newSessionId)")
        }
        self.paidAppStore = paidAppStore
        self.paidAppMonitor = PaidAppMonitor()
        self.restServer = RESTServer(handlers: handlers, paidAppStore: paidAppStore)
        weakSelf = self
    }


    func initialize() {
        let effectiveLogLevel = Env.logLevel ?? LogLevel(rawValue: settings.logLevel ?? 5) ?? .critical
        Logger.shared.setLogLevel(effectiveLogLevel)

        // 2-모드 메뉴바 — cliApp이 직접 관리. paidApp 실행 여부는 PaidAppMonitor로 감지.
        if detectPaidApp() != nil {
            _ = launchPaidApp()
            logI("✅ fWarrange(Paid) 실행 — cliApp 메뉴바 유지 (2-모드 관리)")
        }

        // PaidAppMonitor NSWorkspace 구독 시작 (paidApp terminate 콜백 포함)
        paidAppMonitor.startObserving { [weak self] app in
            guard let self else { return }
            // Issue197: kill -9 등 비정상 종료 시 Store stale 잔류 방지
            let currentState = self.paidAppStore.currentState()
            let cleaned = self.paidAppStore.unregisterAllForBundleId("kr.finfra.fWarrange")
            if cleaned {
                // cleanup 이벤트 기록: currentState에서 pid 추출
                if case let .running(runtime) = currentState {
                    PaidAppStateLogger.shared.append(.cleanup(
                        bundleId: "kr.finfra.fWarrange",
                        pid: runtime.pid,
                        reason: "didTerminate"
                    ))
                }
                logI("🧹 fWarrange 종료 감지 → PaidAppStateStore cleanup 완료 (bundleId: kr.finfra.fWarrange)")
            }
        }
        startObservingMenuBarIcon()

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
    }

    // MARK: - 메뉴바 아이콘 관리 (Issue217 Phase 2 — MenuBarIconService 위임)

    /// cliApp 기본 메뉴바 아이콘 — 기존 호출 사이트 호환용 wrapper
    static func makeCLIIcon() -> NSImage { MenuBarIconService.makeCLIIcon() }

    /// paidApp 활성 메뉴바 아이콘 — 기존 호출 사이트 호환용 wrapper
    static func makePaidAppActiveIcon() -> NSImage { MenuBarIconService.makePaidAppActiveIcon() }

    /// PaidAppMonitor.state 변화를 감시해 menuBarIcon 자동 전환 (AppState 본질 책임)
    private func startObservingMenuBarIcon() {
        func observe() {
            withObservationTracking {
                let state = paidAppMonitor.state
                switch state {
                case .paidAppActive:
                    menuBarIcon = MenuBarIconService.makePaidAppActiveIcon()
                    menuBarIconIsTemplate = true
                    logI("🎨 메뉴바 아이콘: paidApp 활성 아이콘으로 전환")
                case .cliOnly:
                    menuBarIcon = MenuBarIconService.makeCLIIcon()
                    menuBarIconIsTemplate = true
                    logI("🎨 메뉴바 아이콘: cliApp 아이콘으로 복원")
                }
            } onChange: {
                Task { @MainActor [weak self] in
                    self?.startObservingMenuBarIcon()
                }
            }
        }
        observe()
    }

    // MARK: - Login Item 관리 (Issue217 Phase 2 — LoginItemService 위임)

    /// Issue51: launchAtLogin ↔ brew services plist 연동 — 호환용 wrapper
    func syncLaunchAtLogin(_ enabled: Bool) {
        LoginItemService.sync(enabled: enabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        settingsService.save(settings)
        LoginItemService.sync(enabled: enabled)
    }

    func handleHotKeyAction(_ action: HotKeyAction) {
        switch action {
        case .save:
            let name = layoutManager.nextDailySequenceName()
            let windows = windowManager.captureCurrentWindows(filterApps: nil)
            try? layoutManager.saveLayout(name: name, windows: windows)
            ChangeTracker.shared.record(type: "layout.created", target: name)
            logI("⌨️ 단축키 저장: '\(name)'")
        case .restoreDefault:
            // defaultLayoutName SSOT 우선 → 미지정 시 fileDate 가장 최근
            let target = settings.defaultLayoutName
                ?? layoutManager.layouts.sorted { $0.fileDate > $1.fileDate }.first?.name
            if let target { restoreLayoutByName(target) }
        case .restoreLast:
            // fileDate 가장 최근
            if let target = layoutManager.layouts.sorted(by: { $0.fileDate > $1.fileDate }).first?.name {
                restoreLayoutByName(target)
            }
        case .showMainWindow:
            // paidApp 메인 창 열기 — 감지 시 URL Scheme, 미감지 시 본 분기는 메뉴 클릭 경로에서 처리
            openPaidApp(action: "main")
        case .showSettings:
            // paidApp Settings 위임 — cliApp은 자체 Settings GUI 미보유
            openPaidApp(action: "settings")
        }
    }

    /// 이름으로 레이아웃 복구 (메뉴 클릭 / 핫키 공용)
    func restoreLayoutByName(_ name: String) {
        Task {
            let layout = try? layoutManager.storageServiceLoad(name: name)
            if let layout {
                await windowManager.restoreWindows(
                    layout.windows,
                    maxRetries: settings.maxRetries,
                    retryInterval: settings.retryInterval,
                    minimumScore: settings.minimumMatchScore,
                    enableParallel: settings.enableParallelRestore ?? true
                )
                logI("🔁 레이아웃 복구: '\(name)'")
            } else {
                logW("⚠️ 레이아웃 로드 실패: '\(name)'")
            }
        }
    }

    // MARK: - Paid 버전 (fWarrange.app) 감지 & 실행 (Issue217 Phase 2 — PaidAppLauncher 위임)

    /// Paid 앱 감지만 수행 (명시적 경로에서만 검색, ~/Library 제외) — 호환용 wrapper
    func detectPaidApp() -> URL? { PaidAppLauncher.detect() }

    /// Paid 앱 실행만 수행 (성공 여부 반환) — 호환용 wrapper
    @discardableResult
    func launchPaidApp() -> Bool { PaidAppLauncher.launch() }

    /// Issue195: fwarrange:// URL Scheme으로 paidApp 특정 화면 열기 — 호환용 wrapper
    func openPaidApp(action: String) { PaidAppLauncher.open(action: action) }

    /// 기능 실행 시 호출: 감지 → 실행 → 안내 알림 — 호환용 wrapper
    func tryLaunchPaidFeature() -> Bool { PaidAppLauncher.tryLaunchFeature() }

    var uptimeString: String {
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Accessibility 권한 안내 (Issue217 Phase 2 — AccessibilityGuidePresenter 위임)

    /// Issue189: 권한 미부여 안내 — 호환용 wrapper
    private func showAccessibilityGuide() {
        AccessibilityGuidePresenter.show(windowManager: windowManager)
    }

    /// _config.yml의 appLanguage 설정을 시스템 언어로 적용 (fSnippet 참고)
    /// 국가 코드(kr, jp, cn 등)를 언어 코드(ko, ja, zh-Hans 등)로 정규화
    private static func applyLanguageSetting(_ language: String?) {
        let rawLang = language ?? "system"
        let normalizedLang = LocalizedStringManager.normalizeLanguageCode(rawLang)
        let defaults = UserDefaults.standard

        logI("📝 [appLanguage] 설정 적용: \(rawLang) → \(normalizedLang)")

        LocalizedStringManager.apply(language: rawLang)

        if normalizedLang == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([normalizedLang], forKey: "AppleLanguages")
        }
        defaults.synchronize()
    }
}
