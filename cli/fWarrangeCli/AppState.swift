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
    /// Issue72_1 (Phase 1): 창 복구 매칭 누적 통계 수집기.
    let restoreStatsCollector: RestoreStatsCollector
    /// Issue72_3 (Phase 3): 타이틀 정규화 서비스 (캡처·복구 공유).
    let titleNormalizer: TitleNormalizer
    private let hotKeyService: HotKeyService
    private let screenMoveService: ScreenMoveService
    private let modeStorageService: ModeStorageService
    private let appLauncherService: AppLauncherService
    /// Issue81: 슬립/잠금 시 자동 캡처 코디네이터
    private var autoCaptureCoordinator: AutoCaptureCoordinator?

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

    /// 이 프로세스에서 생성된 AppState 수. 정상은 1 — 2 이상이면 RESTServer·listener 가 두 벌 생긴다.
    /// (prj5#Issue99 후속: 두 번째 인스턴스가 해제되며 3016 에 고아 listener 가 남아 무응답)
    @ObservationIgnored static private(set) var instanceCount = 0

    init() {
        AppState.instanceCount += 1
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

        // Layouts follow settings.dataDirectoryPath (read once at launch); _config.yml stays in baseDir (Issue108 ①)
        let layoutBaseDir = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: settings.dataDirectoryPath, configBase: baseDir)
        if layoutBaseDir != baseDir {
            logI("레이아웃 폴더: dataDirectoryPath → \(layoutBaseDir.path)")
        }

        let storageMode = settings.dataStorageMode ?? .host
        if storageMode == .host {
            YAMLLayoutStorageService.migrateRootDataIfNeeded(baseDir: layoutBaseDir)
            YAMLLayoutStorageService.copyShareDataIfNeeded(baseDir: layoutBaseDir)
        }

        // Issue72_3 (Phase 3): 타이틀 정규화 서비스 — 캡처·복구가 공유.
        let normalizer = FileTitleNormalizer()
        self.titleNormalizer = normalizer

        let captureService = CGWindowCaptureService(titleNormalizer: normalizer)
        // Issue72_4 (Phase 4): areaMatch 활성 여부를 settings에서 주입.
        let restoreService = AXWindowRestoreService(
            titleNormalizer: normalizer,
            areaMatchEnabled: settings.matchAreaMatchEnabled ?? true
        )
        let storageService = YAMLLayoutStorageService(
            storageMode: storageMode,
            baseDirectory: layoutBaseDir
        )
        let accessService = SystemAccessibilityService()

        // Issue72_1 (Phase 1): 매칭 통계 수집기. 디스크 영속은 init 후 initialize()에서 load 호출.
        let statsCollector = JSONRestoreStatsCollector()
        self.restoreStatsCollector = statsCollector

        self.windowManager = WindowManager(
            captureService: captureService,
            restoreService: restoreService,
            accessibilityService: accessService,
            statsCollector: statsCollector
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
            restoreWindows: { windows, maxRetries, retryInterval, minimumScore, enableParallel, mode, dryRun in
                await wm.restoreWindows(windows, maxRetries: maxRetries, retryInterval: retryInterval, minimumScore: minimumScore, enableParallel: enableParallel, mode: mode, dryRun: dryRun)
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
                svc.mutate { $0.defaultLayoutName = name }
            },
            updateShortcuts: { [weak settingsService] body -> [String: String] in
                guard let svc = settingsService else { return [:] }
                let s = svc.mutate { s in
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
                    apply("undoShortcut") { s.undoShortcut = $0 }
                }
                NotificationCenter.default.post(name: .fWarrangeCliShortcutsUpdated, object: nil)
                return [
                    "saveShortcut": s.saveShortcut?.displayString ?? "",
                    "restoreDefaultShortcut": s.restoreDefaultShortcut?.displayString ?? "",
                    "restoreLastShortcut": s.restoreLastShortcut?.displayString ?? "",
                    "showMainWindowShortcut": s.showMainWindowShortcut?.displayString ?? "",
                    "undoShortcut": s.undoShortcut?.displayString ?? ""
                ]
            },
            getFullSettings: { [weak settingsService] in
                guard let svc = settingsService else { return [:] }
                return AppSettings.fullSettingsDict(svc.load())
            },
            patchSettings: { [weak settingsService] body in
                guard let svc = settingsService else { return [:] }
                var languageChanged: String? = nil
                let s = svc.mutate { s in
                    // appLanguage 변경 감지
                    let oldLanguage = s.appLanguage
                    AppSettings.applySettingsPatch(&s, body: body)
                    if let newLanguage = body["appLanguage"] as? String, newLanguage != oldLanguage {
                        languageChanged = newLanguage
                    }
                }
                if let newLanguage = languageChanged {
                    AppState.applyLanguageSetting(newLanguage)
                }
                return AppSettings.fullSettingsDict(s)
            },
            getExcludedApps: { [weak settingsService] in
                settingsService?.load().excludedApps ?? []
            },
            setExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return apps }
                return svc.mutate { $0.excludedApps = apps }.excludedApps
            },
            addExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return apps }
                return svc.mutate { s in
                    var set = Array(s.excludedApps)
                    for a in apps where !set.contains(a) { set.append(a) }
                    s.excludedApps = set
                }.excludedApps
            },
            removeExcludedApps: { [weak settingsService] apps in
                guard let svc = settingsService else { return [] }
                return svc.mutate { s in
                    s.excludedApps = s.excludedApps.filter { !apps.contains($0) }
                }.excludedApps
            },
            resetExcludedApps: { [weak settingsService] in
                guard let svc = settingsService else { return AppSettings.defaultExcludedApps }
                return svc.mutate { $0.excludedApps = AppSettings.defaultExcludedApps }.excludedApps
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
                    "undoShortcut": s.undoShortcut?.displayString ?? ""
                ]
            },
            getLogFilePath: {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                return "\(home)/Documents/finfra/fWarrangeData/logs/wlog_cliApp.log"
            },
            applyApiSettings: { [weak settingsService] enabled, newPort, external, cidr in
                var prev = AppSettings.defaults
                let s = settingsService?.mutate { st in
                    prev = st
                    if let v = enabled { st.restServerEnabled = v }
                    if let v = newPort { st.restServerPort = v }
                    if let v = external { st.allowExternalAccess = v }
                    if let v = cidr, !v.isEmpty { st.allowedCIDR = v }
                } ?? AppSettings.defaults
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
                    enableParallel: self.settings.enableParallelRestore ?? true,
                    mode: .normal,
                    dryRun: false
                )
                // Phase 2B: requiredApps 자동 실행/숨기기
                await self.appLauncherService.applyAppConfigs(mode.requiredApps)
                self.activeModeName = name
                return (mode: mode, restoreResults: results)
            },
            getActiveModeName: {
                weakSelf?.activeModeName
            },
            // Issue72_1 (Phase 1): 매칭 통계 핸들러
            getRestoreStats: { [statsCollector] in
                await statsCollector.currentSnapshot()
            },
            resetRestoreStats: { [statsCollector] in
                await statsCollector.reset()
            },
            // Issue72_3 (Phase 3): 정규화 룰셋 핸들러
            getNormalizeRules: { [normalizer] in
                normalizer.currentRules().map { rule in
                    var dict: [String: Any] = [:]
                    if let v = rule.bundleId { dict["bundleId"] = v }
                    if let v = rule.app { dict["app"] = v }
                    if let v = rule.stripPrefix { dict["stripPrefix"] = v }
                    if let v = rule.stripSuffix { dict["stripSuffix"] = v }
                    if let v = rule.stripPattern { dict["stripPattern"] = v }
                    return dict
                }
            },
            updateNormalizeRules: { [normalizer] payload in
                let parsed: [TitleNormalizeRule]?
                if let payload = payload {
                    parsed = payload.map { dict in
                        TitleNormalizeRule(
                            bundleId: dict["bundleId"] as? String,
                            app: dict["app"] as? String,
                            stripPrefix: dict["stripPrefix"] as? String,
                            stripSuffix: dict["stripSuffix"] as? String,
                            stripPattern: dict["stripPattern"] as? String
                        )
                    }
                } else {
                    parsed = nil
                }
                try normalizer.updateRules(parsed)
                return normalizer.currentRules().map { rule in
                    var dict: [String: Any] = [:]
                    if let v = rule.bundleId { dict["bundleId"] = v }
                    if let v = rule.app { dict["app"] = v }
                    if let v = rule.stripPrefix { dict["stripPrefix"] = v }
                    if let v = rule.stripSuffix { dict["stripSuffix"] = v }
                    if let v = rule.stripPattern { dict["stripPattern"] = v }
                    return dict
                }
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


    /// SwiftUI 는 App.init 을 여러 번 호출할 수 있다 — initialize 는 프로세스당 1회만 실행한다.
    @ObservationIgnored private var didInitialize = false

    func initialize() {
        guard !didInitialize else {
            logW("AppState.initialize 중복 호출 무시 (App.init 재호출)")
            return
        }
        didInitialize = true
        let effectiveLogLevel = Env.logLevel ?? LogLevel(rawValue: settings.logLevel ?? 5) ?? .critical
        Logger.shared.setLogLevel(effectiveLogLevel)

        // Issue72_1 (Phase 1): 매칭 통계 디스크에서 로드 — 앱 재시작 후에도 누적 유지.
        Task { await restoreStatsCollector.load() }

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

        // Issue99 근본예방: 레이아웃 삭제 시 defaultLayoutName 이 그 이름(또는 전체 삭제)이면 정리한다.
        // 죽은 참조가 애초에 남지 않게 해, restoreDefault 가 존재하지 않는 이름으로 복구를 시도하는 상황을 예방한다.
        layoutManager.onLayoutDeleted = { [weak self] name in
            guard let self else { return }
            // ⚠️ self.settings 는 프로세스 시작 시 로드된 스냅샷이라 REST(PUT /settings/default-layout)로
            //    바뀐 defaultLayoutName 을 반영하지 못한다. paidApp GUI 는 전부 REST 를 타므로,
            //    최신 저장값(load)과 대조해야 실사용 경로에서도 죽은 참조가 정리된다. (Issue99, fwarrange-1c 실측)
            if let updated = AppState.clearDeadDefaultLayout(deletedName: name, svc: self.settingsService) {
                self.settings = updated
                ChangeTracker.shared.record(type: "settings.changed", target: "defaultLayout")
                logI("Issue99: defaultLayoutName 정리 — 삭제된 레이아웃 참조 제거 (삭제=\(name))")
            }
        }

        layoutManager.loadMetadataList()

        // Issue81: 기동 시 보관 기간 초과 자동 캡처 정리 + 슬립/잠금 자동 캡처 구독 시작
        layoutManager.cleanupExpiredAutoCaptures(retentionDays: settings.retentionDays ?? 7)
        let coordinator = AutoCaptureCoordinator(
            windowManager: windowManager,
            layoutManager: layoutManager,
            settingsProvider: { [weak self] in
                self?.settingsService.load() ?? AppSettings.defaults
            }
        )
        coordinator.start()
        self.autoCaptureCoordinator = coordinator

        // REST 서버 시작 (항상 활성화, FWARRANGE_PORT env 우선)
        restServer.start(port: Env.port ?? UInt16(settings.restServerPort ?? 3016))
        isRunning = true
        startTime = Date()

        // Issue39 매트릭스: app start × brew=stopped → brew services start 호출.
        // launchd 기동 / 옵트아웃 / 이미 로드 / brew·formula 미설치는 내부에서 skip.
        // start 가 실패하면 exit 하지 않고 이 프로세스가 primary 로 남는다 (Issue109).
        // 중복 인스턴스는 SingleInstanceGuard 가 exit(0) 으로 차단.
        BrewServiceSync.onAppStart()

        // 접근성 권한 확인 — 미승인이면 새 프로세스에서 1회 목록 등록 요청(AccessibilityBootListing).
        // XCTest 호스트에서는 시스템 창을 띄우지 않는다.
        if !windowManager.isAccessibilityGranted() {
            logW("⚠️ Accessibility 권한이 필요합니다 — 목록 등록 요청")
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                AccessibilityBootListing.runIfNeeded(
                    isGranted: windowManager.isAccessibilityGranted,
                    requestListing: AccessibilityBootListing.requestSystemListing
                )
            }
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

    /// Issue96 gate as a pure decision so it can be tested without AX or NSAlert.
    /// Returns false (and calls `onPermissionLost`) when a window action arrives without Accessibility.
    nonisolated static func passesAccessibilityGate(
        _ action: HotKeyAction, granted: Bool, onPermissionLost: () -> Void
    ) -> Bool {
        guard action.requiresAccessibility, !granted else { return true }
        onPermissionLost()
        return false
    }

    func handleHotKeyAction(_ action: HotKeyAction) {
        // Issue96: Carbon RegisterEventHotKey 로 등록한 핫키는 접근성 권한과 무관하게 도달하지만
        // 창 조작 AX API 는 권한 없이 실패한다. "핫키는 들어왔는데 창 조작이 실패" 하는 이 지점이
        // 운영 중 권한 상실을 관측할 수 있는 곳이다 — 시작 시 1회 확인만으로는 잡히지 않는다.
        let granted = !action.requiresAccessibility || windowManager.isAccessibilityGranted()
        guard Self.passesAccessibilityGate(action, granted: granted, onPermissionLost: {
            logW("⚠️ 접근성 권한 상실 감지 — 단축키(\(action)) 처리 중단 후 재시작 안내")
            AccessibilityGuidePresenter.showPermissionLost()
        }) else { return }

        switch action {
        case .save:
            let name = layoutManager.nextDailySequenceName()
            // Issue78: HotKey 트리거 capture도 OperationRegistry 경로 사용 (직렬화 + op.* 이벤트)
            Task { [weak self] in
                guard let self = self else { return }
                guard let opId = await OperationRegistry.shared.register(type: .capture, target: name) else {
                    logI("⌨️ 단축키 저장 거절 — capture 진행 중")
                    return
                }
                await MainActor.run {
                    let windows = self.windowManager.captureCurrentWindows(filterApps: nil)
                    do {
                        try self.layoutManager.saveLayout(name: name, windows: windows)
                        // Issue73: 발행은 LayoutManager.saveLayout이 SSOT로 처리 (layout.created/updated)
                        logI("⌨️ 단축키 저장: '\(name)'")
                        if self.settings.defaultLayoutName == nil {
                            self.settingsService.mutate { $0.defaultLayoutName = name }
                            self.settings.defaultLayoutName = name
                            ChangeTracker.shared.record(type: "settings.changed", target: "defaultLayout")
                            logI("⭐ 첫 레이아웃을 기본으로 자동 설정: '\(name)'")
                        }
                        Task { await OperationRegistry.shared.complete(opId: opId, success: true) }
                    } catch {
                        Task { await OperationRegistry.shared.complete(opId: opId, success: false, reason: "saveFailed") }
                        logW("⚠️ 단축키 저장 실패: '\(name)' — \(error)")
                    }
                }
            }
        case .restoreDefault:
            // defaultLayoutName SSOT 우선 → 미지정·삭제된 이름이면 fileDate 가장 최근으로 fallback (Issue99)
            // ⚠️ `??` 만으로는 nil 만 걸러진다 — defaultLayoutName 이 삭제된 레이아웃을 가리키면(값은 있음)
            //    존재하지 않는 이름으로 복구를 시도해 조용히 실패한다. 실재 여부를 검증한 뒤 fallback 한다.
            let existingNames = Set(layoutManager.layouts.map { $0.name })
            let target = settings.defaultLayoutName.flatMap { existingNames.contains($0) ? $0 : nil }
                ?? layoutManager.layouts.sorted { $0.fileDate > $1.fileDate }.first?.name
            if let target {
                restoreLayoutByName(target)
            } else {
                logW("restoreDefault: 복구할 레이아웃이 없습니다 (defaultLayoutName=\(settings.defaultLayoutName ?? "nil"), 저장된 레이아웃 0개)")
            }
        case .restoreLast:
            // fileDate 가장 최근
            if let target = layoutManager.layouts.sorted(by: { $0.fileDate > $1.fileDate }).first?.name {
                restoreLayoutByName(target)
            }
        case .showMainWindow:
            // paidApp 메인 창 열기 — 감지 시 URL Scheme, 미감지 시 본 분기는 메뉴 클릭 경로에서 처리
            openPaidApp(action: "main")
        case .undo:
            // Issue98: 복구 직전 배치로 되돌린다. 스냅샷 없으면(복구 이력 없음) 무동작.
            if let snapshot = undoSnapshot {
                Task {
                    await windowManager.restoreWindows(
                        snapshot,
                        maxRetries: settings.maxRetries,
                        retryInterval: settings.retryInterval,
                        minimumScore: settings.minimumMatchScore,
                        enableParallel: settings.enableParallelRestore ?? true,
                        mode: .normal
                    )
                    logI("↩️ Undo: 복구 직전 배치로 되돌림 (\(snapshot.count)창)")
                }
            } else {
                logI("↩️ Undo: 복구 이력 없음 — 무동작")
            }
        }
    }

    /// Issue98: 복구 직전 전체 창 배치 스냅샷 (단일 Undo, 메모리 휘발)
    private var undoSnapshot: [WindowInfo]?

    /// Issue99: 삭제된 레이아웃 이름이 **최신 저장된**(load) defaultLayoutName 이면 nil 로 정리한다.
    /// self.settings 스냅샷 대신 svc.load() 를 대조해 REST 변경(paidApp GUI)도 반영한다. (fwarrange-1c 실측)
    /// name `"*"` 은 전체 삭제. 정리했으면 갱신된 AppSettings 를, 아니면 nil 을 반환한다.
    static func clearDeadDefaultLayout(deletedName: String, svc: SettingsService) -> AppSettings? {
        let current = svc.load().defaultLayoutName
        guard deletedName == "*" || current == deletedName else { return nil }
        return svc.mutate { $0.defaultLayoutName = nil }
    }

    /// 이름으로 레이아웃 복구 (메뉴 클릭 / 핫키 공용)
    func restoreLayoutByName(_ name: String) {
        Task {
            let layout = try? layoutManager.storageServiceLoad(name: name)
            if let layout {
                // Issue98: 복구 실행 직전 현재 배치를 Undo 스냅샷으로 저장
                self.undoSnapshot = self.windowManager.captureCurrentWindows(filterApps: nil)
                await windowManager.restoreWindows(
                    layout.windows,
                    maxRetries: settings.maxRetries,
                    retryInterval: settings.retryInterval,
                    minimumScore: settings.minimumMatchScore,
                    enableParallel: settings.enableParallelRestore ?? true,
                    mode: .normal
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
