import XCTest
import CoreGraphics
@testable import fWarrangeCli

/// Regression tests for the `tdd/playlist.md` goals that had no test yet (prj5#Issue99).
/// Every test works on a private temporary directory — never on the user's real
/// `~/Documents/finfra/fWarrangeData`, and never on the running brew instance.
final class TDDPlaylistTests: XCTestCase {

    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TDDPlaylistTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - test-host-isolation (found in this round)

    /// The test host is the app binary itself. If it resolves the default data
    /// directory, every default-path writer (Logger, PaidAppStateLogger, layout
    /// storage) lands in the user's real data folder while tests run.
    func testTestHostDataDirectoryIsIsolatedFromRealData() {
        let real = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/finfra/fWarrangeData").standardizedFileURL.path
        let resolved = YAMLLayoutStorageService.resolveDefaultBaseDirectory().standardizedFileURL.path
        XCTAssertFalse(resolved.hasPrefix(real),
                       "test host must not resolve the real data directory: \(resolved)")
        XCTAssertNotNil(Env.configPath, "test host must run with an isolated fWarrangeCli_config")
    }

    /// Global hotkeys registered by the test host would collide with the user's running cliApp.
    func testTestHostDoesNotRegisterGlobalHotkeys() {
        XCTAssertTrue(Env.hotkeysDisabled, "test host must run with FWARRANGE_DISABLE_HOTKEYS=1")
    }

    // MARK: - #5 runtime-permission-loss (Issue96)

    /// A window action arriving without Accessibility must stop and tell the user.
    func testWindowActionWithoutPermissionIsBlockedAndAnnounced() {
        var announced = 0
        for action in [HotKeyAction.save, .restoreDefault, .restoreLast, .undo] {
            let proceed = AppState.passesAccessibilityGate(action, granted: false) { announced += 1 }
            XCTAssertFalse(proceed, "\(action) must not run without Accessibility")
        }
        XCTAssertEqual(announced, 4, "each blocked action must surface the permission-lost guide")
    }

    /// With permission granted nothing is announced and the action runs.
    func testWindowActionWithPermissionProceedsSilently() {
        var announced = 0
        let proceed = AppState.passesAccessibilityGate(.save, granted: true) { announced += 1 }
        XCTAssertTrue(proceed)
        XCTAssertEqual(announced, 0)
    }

    /// Opening the paidApp window needs no Accessibility — gating it would kill a working feature.
    func testShowMainWindowIsNotGated() {
        var announced = 0
        let proceed = AppState.passesAccessibilityGate(.showMainWindow, granted: false) { announced += 1 }
        XCTAssertTrue(proceed)
        XCTAssertEqual(announced, 0)
    }

    // MARK: - #6 tab-patch-bool-false (Issue80)

    private static let tabBoolFields = [
        "enableParallelRestore", "matchAreaMatchEnabled", "autoSaveOnSleep",
        "confirmBeforeDelete", "clickSwitchToMain", "launchAtLogin"
    ]

    /// Each Bool field patched to `false` must survive a reload from disk.
    func testTabPatchBoolFalseIsPersisted() {
        for key in Self.tabBoolFields {
            let dir = tmpDir.appendingPathComponent(key)
            let svc = YAMLSettingsService(baseDirectory: dir)
            svc.mutate { AppSettings.applySettingsPatch(&$0, body: [key: true]) }
            svc.mutate { AppSettings.applySettingsPatch(&$0, body: [key: false]) }
            let reloaded = AppSettings.fullSettingsDict(YAMLSettingsService(baseDirectory: dir).load())
            XCTAssertEqual(reloaded[key] as? Bool, false, "\(key)=false was not persisted")
        }
    }

    /// Concurrent PATCHes on different fields must not clobber each other (lost update).
    func testConcurrentTabPatchesDoNotLoseUpdates() {
        for round in 0..<3 {
            let dir = tmpDir.appendingPathComponent("concurrent\(round)")
            let seed = YAMLSettingsService(baseDirectory: dir)
            seed.mutate { s in
                for key in Self.tabBoolFields { AppSettings.applySettingsPatch(&s, body: [key: true]) }
            }
            let fields = Self.tabBoolFields
            DispatchQueue.concurrentPerform(iterations: fields.count) { i in
                // A fresh service per request, like independent REST handlers.
                YAMLSettingsService(baseDirectory: dir).mutate {
                    AppSettings.applySettingsPatch(&$0, body: [fields[i]: false])
                }
            }
            let reloaded = AppSettings.fullSettingsDict(YAMLSettingsService(baseDirectory: dir).load())
            for key in fields {
                XCTAssertEqual(reloaded[key] as? Bool, false, "round \(round): \(key) lost")
            }
        }
    }

    // MARK: - #7 change-tracker-records (Issue73)

    private func sampleWindow(id: Int) -> WindowInfo {
        WindowInfo(id: id, app: "Safari", window: "w\(id)", layer: 0,
                   pos: WindowPosition(x: 10, y: 20), size: WindowSize(width: 300, height: 200))
    }

    private func events(since seq: Int) -> [(type: String, target: String)] {
        ChangeTracker.shared.changes(since: seq).changes.map {
            (($0["type"] as? String) ?? "", ($0["target"] as? String) ?? "")
        }
    }

    /// Every LayoutManager CRUD path must publish to ChangeTracker so `/changes` polling sees it.
    @MainActor
    func testLayoutCrudPathsRecordChanges() throws {
        let manager = LayoutManager(storageService: YAMLLayoutStorageService(dataDirectoryURL: tmpDir))
        let name = "tdd-\(UUID().uuidString.prefix(8))"

        var base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.saveLayout(name: name, windows: [sampleWindow(id: 1), sampleWindow(id: 2)])
        XCTAssertTrue(events(since: base).contains { $0 == ("layout.created", name) }, "create")

        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.saveLayout(name: name, windows: [sampleWindow(id: 1), sampleWindow(id: 2)])
        XCTAssertTrue(events(since: base).contains { $0 == ("layout.updated", name) }, "update")

        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.removeWindows(layoutName: name, windowIds: [2])
        XCTAssertTrue(events(since: base).contains { $0 == ("layout.updated", name) }, "removeWindows")

        let renamed = name + "-r"
        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.renameLayout(oldName: name, newName: renamed)
        let renameEvents = events(since: base)
        XCTAssertTrue(renameEvents.contains { $0 == ("layout.deleted", name) }, "rename: old")
        XCTAssertTrue(renameEvents.contains { $0 == ("layout.created", renamed) }, "rename: new")

        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.deleteLayout(name: renamed)
        XCTAssertTrue(events(since: base).contains { $0 == ("layout.deleted", renamed) }, "delete")

        let a = name + "-a", b = name + "-b"
        try manager.saveLayout(name: a, windows: [sampleWindow(id: 3)])
        try manager.saveLayout(name: b, windows: [sampleWindow(id: 4)])
        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.deleteLayouts(names: [a, b])
        let bulk = events(since: base)
        XCTAssertTrue(bulk.contains { $0 == ("layout.deleted", a) } && bulk.contains { $0 == ("layout.deleted", b) },
                      "deleteLayouts")

        try manager.saveLayout(name: a, windows: [sampleWindow(id: 5)])
        base = ChangeTracker.shared.changes(since: nil).currentSeq
        try manager.deleteAllLayouts()
        XCTAssertTrue(events(since: base).contains { $0 == ("layout.deleted", "*") }, "deleteAll")
    }

    // MARK: - #8 owner-name-mismatch-restore (Issue71)

    /// VSCode: saved `app` is the CGWindowOwnerName, running app's localizedName is "Code".
    func testBundleIdWinsOverDifferentDisplayNames() {
        XCTAssertTrue(AppMatcher.matches(
            bundleIdentifier: "com.microsoft.VSCode",
            nameCandidates: ["Code", "Code", "Electron"],
            targetApp: "Visual Studio Code", targetBundleId: "com.microsoft.VSCode"))
    }

    /// Old layouts without bundleId still match through the bundle file name.
    func testLegacyLayoutMatchesThroughBundleFileName() {
        XCTAssertTrue(AppMatcher.matches(
            bundleIdentifier: "com.microsoft.VSCode",
            nameCandidates: ["Code", "Visual Studio Code", "Electron"],
            targetApp: "Visual Studio Code", targetBundleId: nil))
    }

    /// A different app with a different bundleId and unrelated names must not match.
    func testUnrelatedAppDoesNotMatch() {
        XCTAssertFalse(AppMatcher.matches(
            bundleIdentifier: "com.apple.Safari",
            nameCandidates: ["Safari", "Safari", "Safari"],
            targetApp: "Visual Studio Code", targetBundleId: "com.microsoft.VSCode"))
    }

    /// An empty saved app name must not act as a wildcard (every name has the "" prefix).
    func testEmptyTargetNameIsNotAWildcard() {
        XCTAssertFalse(AppMatcher.matches(
            bundleIdentifier: "com.apple.Safari",
            nameCandidates: ["Safari"],
            targetApp: "", targetBundleId: nil))
    }

    // MARK: - #9 config-defaults (isolated part of config-defaults-e2e)

    /// With no `_config.yml`, loading seeds the bundled defaults — same values fwc-test.sh Step 4 checks.
    func testMissingConfigIsSeededWithDefaults() throws {
        let svc = YAMLSettingsService(baseDirectory: tmpDir)
        _ = svc.load()
        let content = try String(contentsOf: tmpDir.appendingPathComponent("_config.yml"), encoding: .utf8)
        let expected: [String: String] = [
            "maxRetries": "5", "retryInterval": "0.5", "minimumMatchScore": "30",
            "enableParallelRestore": "true", "restServerPort": "3016", "logLevel": "5",
            "dataStorageMode": "host", "launchAtLogin": "true", "restServerEnabled": "true",
            "allowExternalAccess": "false", "allowedCIDR": "192.168.0.0/16", "autoSaveOnSleep": "true",
            "maxAutoSaves": "5", "restoreButtonStyle": "nameIcon", "confirmBeforeDelete": "true",
            "clickSwitchToMain": "false", "theme": "system", "appLanguage": "system"
        ]
        let lines = content.split(separator: "\n").map(String.init)
        for (key, value) in expected {
            let line = lines.first { $0.hasPrefix("\(key):") }
            let actual = line.map {
                $0.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
            }
            XCTAssertEqual(actual, value, "default \(key)")
        }
        XCTAssertTrue(lines.contains { $0.hasPrefix("saveShortcut:") }, "saveShortcut")
        XCTAssertTrue(lines.contains { $0.hasPrefix("restoreDefaultShortcut:") }, "restoreDefaultShortcut")
        XCTAssertGreaterThanOrEqual(lines.filter { $0.hasPrefix("  - \"") }.count, 2, "excludedApps")
    }

    // MARK: - #16 root-config-stays-at-root (Issue108 ②)

    /// The first launch moves legacy root layouts into the host folder, but `_config.yml`
    /// (and any `_`-prefixed file) is settings, not a layout — it must stay at the root.
    /// Moved into the host folder it showed up as a layout named `_config` and was wiped by delete-all.
    func testMigrationKeepsUnderscoreFilesAtRoot() throws {
        let fm = FileManager.default
        try "restServerPort: 3016\n".write(to: tmpDir.appendingPathComponent("_config.yml"), atomically: true, encoding: .utf8)
        try "- app: A\n".write(to: tmpDir.appendingPathComponent("legacy.yml"), atomically: true, encoding: .utf8)

        YAMLLayoutStorageService.migrateRootDataIfNeeded(baseDir: tmpDir, hostname: "testhost")

        XCTAssertTrue(fm.fileExists(atPath: tmpDir.appendingPathComponent("_config.yml").path), "_config.yml stays at the root")
        XCTAssertFalse(fm.fileExists(atPath: tmpDir.appendingPathComponent("testhost/_config.yml").path), "_config.yml is not moved")
        XCTAssertTrue(fm.fileExists(atPath: tmpDir.appendingPathComponent("testhost/legacy.yml").path), "legacy layout is migrated")
    }

    /// A fresh install has only `_config.yml` at the root — there is nothing to migrate.
    func testConfigOnlyRootIsNotMigrated() throws {
        let fm = FileManager.default
        try "restServerPort: 3016\n".write(to: tmpDir.appendingPathComponent("_config.yml"), atomically: true, encoding: .utf8)

        YAMLLayoutStorageService.migrateRootDataIfNeeded(baseDir: tmpDir, hostname: "testhost")

        XCTAssertTrue(fm.fileExists(atPath: tmpDir.appendingPathComponent("_config.yml").path), "_config.yml stays at the root")
        XCTAssertFalse(fm.fileExists(atPath: tmpDir.appendingPathComponent("testhost").path), "no host folder is created for a settings-only root")
    }

    // MARK: - #19 data-directory-setting-applies (Issue108 ①)

    /// `dataDirectoryPath` saved from paidApp settings must become the layout base (from the next start).
    func testDataDirectorySettingBecomesLayoutBase() {
        let custom = tmpDir.appendingPathComponent("custom-data")
        let base = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: custom.path, configBase: tmpDir.appendingPathComponent("cfg"), envPath: nil,
            allowedRoots: [tmpDir])

        // the base comes back canonical (/var → /private/var) — compare symlink-resolved (Issue115)
        XCTAssertEqual(base.resolvingSymlinksInPath().path, custom.resolvingSymlinksInPath().path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: custom.path), "the chosen folder is created")
    }

    /// `~` in the saved path is the user's home, not a folder named "~".
    func testDataDirectorySettingExpandsTilde() {
        let base = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: "~/fwc-tilde-\(UUID().uuidString)", configBase: tmpDir, envPath: nil)
        defer { try? FileManager.default.removeItem(at: base) }

        XCTAssertTrue(base.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path), base.path)
        XCTAssertFalse(base.path.contains("/~/"))
    }

    /// The env override (tests, demo setup) wins over the setting; no setting keeps the config base.
    func testEnvOverrideAndMissingSettingKeepConfigBase() {
        let cfg = tmpDir.appendingPathComponent("cfg")
        let env = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: tmpDir.appendingPathComponent("custom").path, configBase: cfg, envPath: cfg.path)
        let unset = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: nil, configBase: cfg, envPath: nil)
        let empty = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: "  ", configBase: cfg, envPath: nil)

        XCTAssertEqual(env, cfg)
        XCTAssertEqual(unset, cfg)
        XCTAssertEqual(empty, cfg)
    }

    // MARK: - #21 data-directory-path-guarded (Issue115)

    /// A path outside the allowed roots — or the root itself — must not become the layout base,
    /// and nothing may be created there.
    func testDataDirectoryRefusedOutsideAllowedRoots() {
        let cfg = tmpDir.appendingPathComponent("cfg")
        let outside = "/private/tmp/fwc-issue115-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: outside) }

        for raw in [outside, tmpDir.path, "relative/fwc-data", tmpDir.appendingPathComponent("../escape").path] {
            let base = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
                dataDirectoryPath: raw, configBase: cfg, envPath: nil, allowedRoots: [tmpDir])
            XCTAssertEqual(base, cfg, "\(raw) must fall back to the config base")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside), "a refused folder is not created")
    }

    /// A symlink inside an allowed root must not smuggle the base outside of it.
    func testDataDirectoryRefusedThroughSymlink() throws {
        let link = tmpDir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/private/tmp")
        let cfg = tmpDir.appendingPathComponent("cfg")
        let name = "fwc-issue115-\(UUID().uuidString)"
        let raw = link.appendingPathComponent(name).path
        // a regression would create the folder through the link — don't leave it behind
        defer { try? FileManager.default.removeItem(atPath: "/private/tmp/\(name)") }

        let base = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: raw, configBase: cfg, envPath: nil, allowedRoots: [tmpDir])
        XCTAssertEqual(base, cfg)
        if case .success = YAMLLayoutStorageService.validateDataDirectoryPath(raw, allowedRoots: [tmpDir]) {
            XCTFail("symlink escape accepted: \(raw)")
        }
    }

    /// Default roots: under home and /Volumes are fine; system folders and home itself are not.
    func testDataDirectoryDefaultRoots() {
        func accepted(_ raw: String) -> Bool {
            if case .success = YAMLLayoutStorageService.validateDataDirectoryPath(raw) { return true }
            return false
        }
        XCTAssertTrue(accepted("~/Documents/finfra/fWarrangeData"))
        XCTAssertTrue(accepted("/Volumes/fwc-issue115-drive/fWarrangeData"))
        // world-writable: another local account could plant the host folder (Issue115 verify)
        XCTAssertFalse(accepted("/Users/Shared/fWarrangeData"))
        XCTAssertFalse(accepted("/etc/fwc"))
        XCTAssertFalse(accepted("/"))
        XCTAssertFalse(accepted("/Volumes/../etc/fwc"))
        XCTAssertFalse(accepted(FileManager.default.homeDirectoryForCurrentUser.path))
    }

    /// Files are written into `{base}/{hostname}` (and `_share`), not into the base itself.
    /// If that subfolder is a symlink leading out of the base, the base must be refused.
    func testDataDirectoryRefusedWhenHostFolderEscapes() throws {
        let fm = FileManager.default
        let base = tmpDir.appendingPathComponent("base")
        let outside = tmpDir.appendingPathComponent("outside")   // still under the allowed root on purpose
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try fm.createSymbolicLink(atPath: base.appendingPathComponent("testhost").path, withDestinationPath: outside.path)
        let cfg = tmpDir.appendingPathComponent("cfg")

        let resolved = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: base.path, configBase: cfg, envPath: nil, allowedRoots: [tmpDir], hostname: "testhost")
        XCTAssertEqual(resolved, cfg, "a host folder that leaves the base must not be used")

        // a plain host folder is fine
        try fm.removeItem(at: base.appendingPathComponent("testhost"))
        let ok = YAMLLayoutStorageService.resolveLayoutBaseDirectory(
            dataDirectoryPath: base.path, configBase: cfg, envPath: nil, allowedRoots: [tmpDir], hostname: "testhost")
        XCTAssertEqual(ok.resolvingSymlinksInPath().path, base.resolvingSymlinksInPath().path)
    }

    /// REST PATCH must refuse an unsafe `dataDirectoryPath` instead of persisting it.
    func testSettingsPatchRefusesUnsafeDataDirectory() {
        XCTAssertNotNil(AppSettings.settingsPatchError(body: ["dataDirectoryPath": "/private/tmp/fwc"]))
        XCTAssertNotNil(AppSettings.settingsPatchError(body: ["dataDirectoryPath": "/", "theme": "dark"]))
        XCTAssertNil(AppSettings.settingsPatchError(body: ["dataDirectoryPath": "~/Documents/fwc"]))
        XCTAssertNil(AppSettings.settingsPatchError(body: ["dataDirectoryPath": ""]), "empty clears the setting")
        XCTAssertNil(AppSettings.settingsPatchError(body: ["dataDirectoryPath": NSNull()]))
        XCTAssertNil(AppSettings.settingsPatchError(body: ["theme": "dark"]))
    }

    /// A user-chosen base may hold foreign yml files — the legacy root migration must leave them alone.
    func testCustomLayoutBaseKeepsForeignYmlAtRoot() throws {
        let fm = FileManager.default
        let custom = tmpDir.appendingPathComponent("custom")
        try fm.createDirectory(at: custom, withIntermediateDirectories: true)
        try "services: {}\n".write(to: custom.appendingPathComponent("docker-compose.yml"), atomically: true, encoding: .utf8)

        YAMLLayoutStorageService.prepareHostLayoutBase(custom, configBase: tmpDir.appendingPathComponent("cfg"), hostname: "testhost")

        XCTAssertTrue(fm.fileExists(atPath: custom.appendingPathComponent("docker-compose.yml").path), "foreign yml stays put")
        XCTAssertFalse(fm.fileExists(atPath: custom.appendingPathComponent("testhost").path), "no host folder is created")
    }

    /// The config base itself still gets the legacy migration (Issue166_3 behaviour kept).
    func testConfigBaseStillMigratesLegacyLayouts() throws {
        let fm = FileManager.default
        try "- app: \"Safari\"\n".write(to: tmpDir.appendingPathComponent("legacy.yml"), atomically: true, encoding: .utf8)

        YAMLLayoutStorageService.prepareHostLayoutBase(tmpDir, configBase: tmpDir, hostname: "testhost")

        XCTAssertTrue(fm.fileExists(atPath: tmpDir.appendingPathComponent("testhost/legacy.yml").path))
    }

    // MARK: - #10 version-label-match (Issue89, Issue91)

    private var repoRoot: URL {
        // <root>/cli/fWarrangeCliTests/TDDPlaylistTests.swift
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// VERSION, the built app bundle, the brew formula label and the release metadata must agree.
    func testVersionSourcesAgree() throws {
        let version = try String(contentsOf: repoRoot.appendingPathComponent("VERSION"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(version.isEmpty)

        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        XCTAssertEqual(bundleVersion, version, "built app bundle version")

        let formula = try String(contentsOf: repoRoot.appendingPathComponent("cli/Formula/fwarrange-cli.rb"),
                                 encoding: .utf8)
        XCTAssertEqual(firstMatch(#"/cli-v([0-9.]+)/"#, in: formula), version, "formula release tag")
        XCTAssertEqual(firstMatch(#"fWarrangeCli-([0-9.]+)\.tar\.gz"#, in: formula), version, "formula tarball")

        let meta = try String(contentsOf: repoRoot.appendingPathComponent("cli/version-meta.yml"), encoding: .utf8)
        XCTAssertEqual(firstMatch(#"(?m)^version:\s*"([0-9.]+)""#, in: meta), version, "version-meta.yml")

        let projectYml = try String(contentsOf: repoRoot.appendingPathComponent("cli/project.yml"), encoding: .utf8)
        XCTAssertEqual(firstMatch(#"MARKETING_VERSION:\s*"([0-9.]+)""#, in: projectYml), version, "project.yml")
    }
}

// MARK: - rest-listener-lifecycle (prj5#Issue99 follow-up)

/// jma: cliApp accepted TCP on 3016 but never answered. Root cause — the App struct
/// created a second AppState (`@State` initial value read in `App.init`); that instance
/// started the REST listener and was then released, leaving an orphan NWListener whose
/// `newConnectionHandler` saw `self == nil` and silently dropped every connection.
final class RESTListenerLifecycleTests: XCTestCase {

    /// The test host is the app itself — it must build exactly one AppState.
    @MainActor
    func testAppStateIsCreatedOncePerProcess() {
        XCTAssertEqual(AppState.instanceCount, 1,
                       "App must own a single AppState; a second one starts an orphan REST listener")
    }

    /// Symptom check: the host's own REST server (FWARRANGE_PORT from the test plan) answers.
    func testTestHostRESTServerAnswersHealth() throws {
        let port = try XCTUnwrap(Env.port, "FWARRANGE_PORT must be injected by fWarrangeCli.xctestplan")
        let result = Self.get(port: port, path: "/api/v2/health", timeout: 3)
        XCTAssertEqual(result.status, 200, "host REST server did not answer: \(String(describing: result.error))")
    }

    /// A released server must not leave a listener that accepts and never answers.
    func testReleasedServerDoesNotLeaveBlackHoleListener() throws {
        let port = Self.freePort()
        var server: RESTServer? = RESTServer(handlers: Self.stubHandlers())
        server?.start(port: port)
        XCTAssertTrue(Self.waitUntil { Self.get(port: port, path: "/api/v2/health", timeout: 1).status == 200 },
                      "server never became ready")
        server = nil
        XCTAssertTrue(Self.waitUntil { Self.get(port: port, path: "/api/v2/health", timeout: 1).refused },
                      "port still accepts after the server was released (orphan listener)")
    }

    /// Calling start twice must not orphan the first listener: stop() has to free the port.
    func testStartTwiceThenStopReleasesPort() throws {
        let port = Self.freePort()
        let server = RESTServer(handlers: Self.stubHandlers())
        server.start(port: port)
        XCTAssertTrue(Self.waitUntil { Self.get(port: port, path: "/api/v2/health", timeout: 1).status == 200 })
        server.start(port: port)
        XCTAssertTrue(Self.waitUntil { Self.get(port: port, path: "/api/v2/health", timeout: 1).status == 200 })
        server.stop()
        XCTAssertTrue(Self.waitUntil { Self.get(port: port, path: "/api/v2/health", timeout: 1).refused },
                      "port still accepts after stop() — the first listener was orphaned")
    }

    // MARK: helpers

    struct GetResult { var status: Int?; var error: Error?; var data: Data?
        var refused: Bool { (error as? URLError)?.code == .cannotConnectToHost } }

    static func get(port: UInt16, path: String, timeout: TimeInterval) -> GetResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var result = GetResult()
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: URL(string: "http://127.0.0.1:\(port)\(path)")!) { data, resp, err in
            result.data = data
            result.status = (resp as? HTTPURLResponse)?.statusCode
            result.error = err
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + timeout + 2)
        return result
    }

    static func waitUntil(seconds: TimeInterval = 5, _ cond: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if cond() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return false
    }

    static func freePort() -> UInt16 { UInt16.random(in: 40000...49999) }

    static func stubHandlers() -> RESTServerHandlers {
        RESTServerHandlers(
            captureCurrentWindows: { _ in [] },
            restoreWindows: { _, _, _, _, _, _, _ in [] },
            runningAppNames: { [] },
            isAccessibilityGranted: { true },
            getLayouts: { [] },
            loadMetadataList: {},
            storageServiceLoad: { _ in throw URLError(.fileDoesNotExist) },
            saveLayout: { _, _ in },
            nextDailySequenceName: { "stub" },
            renameLayout: { _, _ in },
            deleteLayout: { _ in },
            deleteAllLayouts: {},
            removeWindows: { _, _ in },
            getSettings: { [:] },
            getDataDirectoryPath: { NSTemporaryDirectory() },
            getSettingsBasePath: { NSTemporaryDirectory() },
            getDefaultLayoutName: { nil },
            setDefaultLayoutName: { _ in },
            updateShortcuts: { _ in [:] },
            getFullSettings: { [:] },
            patchSettings: { _ in [:] },
            getExcludedApps: { [] },
            setExcludedApps: { $0 },
            addExcludedApps: { $0 },
            removeExcludedApps: { _ in [] },
            resetExcludedApps: { [] },
            factoryResetSettings: { [:] },
            getShortcutsDisplay: { [:] },
            getLogFilePath: { NSTemporaryDirectory() },
            applyApiSettings: { _, port, _, _ in (true, port ?? 0, false, "") },
            listModes: { [] },
            loadMode: { _ in throw URLError(.fileDoesNotExist) },
            createMode: { _, _, _, _ in throw URLError(.fileDoesNotExist) },
            updateMode: { _, _ in throw URLError(.fileDoesNotExist) },
            deleteMode: { _ in },
            activateMode: { _ in throw URLError(.fileDoesNotExist) },
            getActiveModeName: { nil },
            getRestoreStats: { [:] },
            resetRestoreStats: {},
            getNormalizeRules: { [] },
            updateNormalizeRules: { _ in [] }
        )
    }
}

/// tdd accessibility-boot-listing (Issue104 · prj25 Issue237 이식): 미승인으로 부팅한 새 프로세스는
/// 시스템 권한 요청을 정확히 1회 보내 손쉬운 사용 목록에 올라간다. 승인 상태면 묻지 않는다.
// MARK: - a11y-guide-keeps-rest-alive (Issue110)

/// The accessibility guide is an `NSAlert.runModal()` — a nested run loop in modal-panel mode.
/// REST v2 handlers hop to the main queue (`DispatchQueue.main.async`). If the guide itself is
/// started from a main-queue block, the serial main queue cannot drain until the alert closes and
/// every REST v2 request hangs (jma, TCC reset → brew launch: `/api/v2/layouts` 000 for as long as
/// the guide was up). The presenter must schedule the alert so that main-queue work keeps running.
final class AccessibilityGuideSchedulingTests: XCTestCase {

    func testMainQueueWorkRunsWhileGuideIsUp() {
        let done = expectation(description: "guide stand-in finished")
        var mainQueueRan = false

        AccessibilityGuidePresenter.schedule {
            // stand-in for a REST v2 handler queued while the guide is shown
            DispatchQueue.main.async { mainQueueRan = true }
            // stand-in for NSAlert.runModal(): spin a nested run loop in modal-panel mode
            let deadline = Date().addingTimeInterval(2)
            while !mainQueueRan && Date() < deadline {
                RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.05))
            }
            XCTAssertTrue(mainQueueRan, "main-queue work must run while the modal guide is up")
            done.fulfill()
        }

        wait(for: [done], timeout: 10)
    }

    // MARK: - #22 a11y-guide-single-alert (Issue116)

    override func tearDown() {
        AccessibilityGuidePresenter.runModal = { $0.runModal() }
        super.tearDown()
    }

    /// Because guides run as run-loop blocks (Issue110), a guide requested while another is up
    /// runs inside the open alert's modal loop. It must not stack a second alert.
    func testGuideIsNotStackedWhileOneIsUp() {
        let closed = expectation(description: "first guide closed")
        var presented = 0
        AccessibilityGuidePresenter.runModal = { _ in
            presented += 1
            if presented == 1 {
                AccessibilityGuidePresenter.show(openSettings: {})
                AccessibilityGuidePresenter.showPermissionLost()
                // run-loop blocks run in order — once this one ran, the two requests above were serviced
                var serviced = false
                AccessibilityGuidePresenter.schedule { serviced = true }
                // stand-in for runModal's nested loop — the requests above get serviced in here
                let deadline = Date().addingTimeInterval(5)
                while !serviced && Date() < deadline {
                    RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.05))
                }
                XCTAssertTrue(serviced, "the nested requests must have been serviced, or the count proves nothing")
                closed.fulfill()
            }
            return .alertSecondButtonReturn   // "나중에" — no settings, no restart
        }

        AccessibilityGuidePresenter.show(openSettings: {})
        wait(for: [closed], timeout: 10)

        XCTAssertEqual(presented, 1, "only one accessibility alert may be up at a time")
    }

    /// The guard is released when the alert closes — a later request shows again.
    func testGuideShowsAgainAfterClosing() {
        let both = expectation(description: "two guides closed")
        both.expectedFulfillmentCount = 2
        var presented = 0
        AccessibilityGuidePresenter.runModal = { _ in
            presented += 1
            both.fulfill()
            return .alertSecondButtonReturn
        }

        AccessibilityGuidePresenter.show(openSettings: {})
        AccessibilityGuidePresenter.show(openSettings: {})
        wait(for: [both], timeout: 10)

        XCTAssertEqual(presented, 2)
    }
}

final class AccessibilityBootListingTests: XCTestCase {

    func testUngrantedBootRequestsListingOnce() {
        var requests = 0
        let requested = AccessibilityBootListing.runIfNeeded(
            isGranted: { false },
            requestListing: { requests += 1 }
        )
        XCTAssertTrue(requested)
        XCTAssertEqual(requests, 1)
    }

    func testGrantedBootDoesNotAsk() {
        var requests = 0
        let requested = AccessibilityBootListing.runIfNeeded(
            isGranted: { true },
            requestListing: { requests += 1 }
        )
        XCTAssertFalse(requested)
        XCTAssertEqual(requests, 0)
    }

    // MARK: - #29 test-host-no-a11y-guide (Issue133)

    private func bootEvents(granted: Bool, testHost: Bool) -> [String] {
        var events: [String] = []
        AccessibilityBootListing.boot(
            isGranted: { granted },
            isTestHost: testHost,
            requestListing: { events.append("listing") },
            showGuide: { events.append("guide") }
        )
        return events
    }

    /// An ungranted boot asks for listing and shows the guide — in a real launch.
    func testUngrantedRealBootListsAndGuides() {
        XCTAssertEqual(bootEvents(granted: false, testHost: false), ["listing", "guide"])
    }

    /// The XCTest host must not raise a real modal guide: it holds the presenter's guard and
    /// swallows the guide tests' own `show()` calls (jma, TCC reset → 4 failures).
    func testTestHostBootRaisesNothing() {
        XCTAssertEqual(bootEvents(granted: false, testHost: true), [])
    }

    func testGrantedBootRaisesNothing() {
        XCTAssertEqual(bootEvents(granted: true, testHost: false), [])
    }
}

// MARK: - official-build-marker (Issue105)

/// DISTRIBUTION-TERMS §1(b) applies only to Official Build Components. If an official
/// build and a source build are indistinguishable, the terms have nothing to apply to.
/// The components live in `cli/resources/official/` and are copied into the bundle only
/// when the official build scripts pass `FWARRANGE_OFFICIAL_BUILD=YES`.
final class OfficialBuildMarkerTests: XCTestCase {

    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfficialBuildMarkerTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private var cliRoot: URL {
        // <root>/cli/fWarrangeCliTests/TDDPlaylistTests.swift
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testResourcesWithBannerAreOfficialBuild() throws {
        let official = tmpDir.appendingPathComponent("Official")
        try FileManager.default.createDirectory(at: official, withIntermediateDirectories: true)
        try "Finfra Official Build\n".write(to: official.appendingPathComponent("official-build.txt"),
                                             atomically: true, encoding: .utf8)
        XCTAssertEqual(OfficialBuild.distribution(resourcesURL: tmpDir), "Finfra Official Build")
    }

    func testResourcesWithoutBannerAreSourceBuild() throws {
        XCTAssertEqual(OfficialBuild.distribution(resourcesURL: tmpDir), "Source Build")
        XCTAssertEqual(OfficialBuild.distribution(resourcesURL: nil), "Source Build")
        let official = tmpDir.appendingPathComponent("Official")
        try FileManager.default.createDirectory(at: official, withIntermediateDirectories: true)
        try "  \n".write(to: official.appendingPathComponent("official-build.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(OfficialBuild.distribution(resourcesURL: tmpDir), "Source Build", "blank banner")
    }

    /// The checked-in component must produce the marker the terms refer to.
    func testRepoBannerSaysFinfraOfficialBuild() throws {
        let banner = try String(contentsOf: cliRoot.appendingPathComponent("resources/official/official-build.txt"),
                                encoding: .utf8)
        XCTAssertEqual(banner.split(separator: "\n").first.map(String.init), "Finfra Official Build")
    }

    /// A plain Xcode build — what anyone gets from `git clone` — must not ship the components.
    func testTestHostIsSourceBuild() throws {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("Official").path),
                       "a source build must not contain Official Build Components")
        XCTAssertEqual(OfficialBuild.current, "Source Build")
    }

    /// `fWarrangeCli --version` prints GET /cli/version — the marker has to be in that payload.
    func testCLIVersionResponseCarriesDistribution() throws {
        let port = try XCTUnwrap(Env.port, "FWARRANGE_PORT must be injected by fWarrangeCli.xctestplan")
        let result = RESTListenerLifecycleTests.get(port: port, path: "/api/v2/cli/version", timeout: 3)
        XCTAssertEqual(result.status, 200, String(describing: result.error))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(result.data)) as? [String: Any])
        let data = try XCTUnwrap(json["data"] as? [String: Any])
        XCTAssertEqual(data["distribution"] as? String, "Source Build")
    }

    // MARK: build-phase script (the official/source branch itself)

    private func runInjector(official: Bool) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [cliRoot.appendingPathComponent("_tool/fwc-official-components.sh").path]
        var env = ["PATH": "/usr/bin:/bin",
                   "SRCROOT": cliRoot.path,
                   "TARGET_BUILD_DIR": tmpDir.path,
                   "UNLOCALIZED_RESOURCES_FOLDER_PATH": "App.app/Contents/Resources"]
        if official { env["FWARRANGE_OFFICIAL_BUILD"] = "YES" }
        process.environment = env
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private var injectedDir: URL { tmpDir.appendingPathComponent("App.app/Contents/Resources/Official") }

    func testOfficialBuildScriptCopiesComponentsAndTerms() throws {
        XCTAssertEqual(try runInjector(official: true), 0)
        for name in ["official-build.txt", "LICENSE", "NOTICE", "TRADEMARK.md", "DISTRIBUTION-TERMS.md",
                     "DISTRIBUTION-TERMS_ko.md", "COMMERCIAL.md"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: injectedDir.appendingPathComponent(name).path),
                          "official build must carry \(name)")
        }
        XCTAssertEqual(OfficialBuild.distribution(resourcesURL: injectedDir.deletingLastPathComponent()),
                       "Finfra Official Build")
    }

    /// DerivedData is shared between official and source builds — a source build must
    /// remove components left behind by an earlier official build.
    func testSourceBuildScriptRemovesStaleComponents() throws {
        try FileManager.default.createDirectory(at: injectedDir, withIntermediateDirectories: true)
        try "stale".write(to: injectedDir.appendingPathComponent("official-build.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try runInjector(official: false), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: injectedDir.path))
    }
}

// MARK: - brew-handoff-keeps-primary (Issue109)

/// An `open`-launched instance hands its primary role to the brew service and exits.
/// That handoff is only valid if launchd can actually spawn the service binary:
/// with brew present but the formula missing (README source build) or with
/// `brew services start` failing, the app used to exit anyway and vanish in 0.55s.
/// Every outside effect (defaults, launchctl, brew, exit) is injected — no real brew call.
final class BrewHandoffTests: XCTestCase {

    private var events: [String] = []
    private var tmpDir: URL!

    override func setUpWithError() throws {
        events = []
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrewHandoffTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    /// `open` launch · service not loaded · brew at /fake/bin/brew.
    private func environment(formulaInstalled: Bool, startStatus: Int32) -> BrewServiceSync.StartEnvironment {
        BrewServiceSync.StartEnvironment(
            optOut: { nil },
            isLaunchedByLaunchd: { false },
            isServiceLoaded: { false },
            findBrewPath: { "/fake/bin/brew" },
            isFormulaInstalled: { [unowned self] _ in events.append("formula?"); return formulaInstalled },
            startService: { [unowned self] _ in events.append("start"); return (startStatus, "") },
            flushLog: { [unowned self] in events.append("flush") },
            exitProcess: { [unowned self] in events.append("exit") }
        )
    }

    /// Issue106: the XCTest host runs AppState like the real app. It must skip the brew sync before
    /// asking launchctl or brew anything — a real `brew services start` handoff (or its nested
    /// `waitUntilExit` run loop) inside the test host broke isolation and left the host hanging.
    func testTestHostSkipsBrewSyncBeforeTouchingBrew() {
        var env = environment(formulaInstalled: true, startStatus: 0)
        env.isServiceLoaded = { [unowned self] in events.append("loaded?"); return false }
        env.findBrewPath = { [unowned self] in events.append("brew?"); return "/fake/bin/brew" }
        env.isTestHost = { true }

        let outcome = BrewServiceSync.onAppStart(env)

        XCTAssertEqual(outcome, .skipped)
        XCTAssertEqual(events, [], "no launchctl / brew query, no start, no exit in the test host")
    }

    /// The live environment recognises this very process as the test host.
    func testLiveEnvironmentDetectsTestHost() {
        XCTAssertTrue(BrewServiceSync.StartEnvironment.live.isTestHost())
    }

    /// jma R1 row 3: brew binary present, formula not installed.
    func testMissingFormulaDoesNotHandOffOrExit() {
        let outcome = BrewServiceSync.onAppStart(environment(formulaInstalled: false, startStatus: 0))
        XCTAssertEqual(outcome, .skipped)
        XCTAssertFalse(events.contains("start"), "must not call brew services start without the formula")
        XCTAssertFalse(events.contains("exit"))
    }

    /// Issue137: a Debug build run from DerivedData (all-clear, /run) handed itself off to the brew
    /// service — launchd then ran the installed Release binary, so the suite tested the wrong app and
    /// REST went silent during the swap (jma full run: API 19-25 empty). Hand off only when launchd
    /// would run this very binary.
    func testForeignBinaryDoesNotHandOff() {
        var env = environment(formulaInstalled: true, startStatus: 0)
        env.isServiceBinary = { [unowned self] _ in events.append("same-binary?"); return false }

        let outcome = BrewServiceSync.onAppStart(env)

        XCTAssertEqual(outcome, .skipped)
        XCTAssertEqual(events, ["formula?", "same-binary?"], "no brew services start, no exit")
    }

    /// The installed app reached through a symlink (/Applications/_nowage_app → brew opt → Cellar)
    /// is the service binary; another copy of the bundle is not.
    func testServiceBinaryComparesResolvedBundlePaths() throws {
        let cellar = tmpDir.appendingPathComponent("Cellar/fwarrange-cli/1.2.0/fWarrangeCli.app")
        let other = tmpDir.appendingPathComponent("DerivedData/Debug/fWarrangeCli.app")
        try FileManager.default.createDirectory(at: cellar, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let opt = tmpDir.appendingPathComponent("opt/fwarrange-cli")
        try FileManager.default.createDirectory(at: opt.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: opt, withDestinationURL: cellar.deletingLastPathComponent())
        let appLink = tmpDir.appendingPathComponent("Applications/fWarrangeCli.app")
        try FileManager.default.createDirectory(at: appLink.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: appLink, withDestinationURL: opt.appendingPathComponent("fWarrangeCli.app"))

        let service = opt.appendingPathComponent("fWarrangeCli.app").path
        XCTAssertTrue(BrewServiceSync.isSameBundle(cellar.path, service))
        XCTAssertTrue(BrewServiceSync.isSameBundle(appLink.path, service))
        XCTAssertFalse(BrewServiceSync.isSameBundle(other.path, service))
    }

    /// Formula present but `brew services start` fails (e.g. untrusted tap).
    func testFailedServiceStartKeepsProcessAsPrimary() {
        let outcome = BrewServiceSync.onAppStart(environment(formulaInstalled: true, startStatus: 1))
        XCTAssertEqual(outcome, .keptPrimary)
        XCTAssertEqual(events, ["formula?", "start"])
    }

    /// Successful handoff exits — but only after the pending log lines are written.
    func testSuccessfulHandoffFlushesLogBeforeExit() {
        let outcome = BrewServiceSync.onAppStart(environment(formulaInstalled: true, startStatus: 0))
        XCTAssertEqual(outcome, .handedOff)
        XCTAssertEqual(events, ["formula?", "start", "flush", "exit"])
    }

    /// The formula counts as installed only if the service executable launchd would run exists.
    func testFormulaInstalledIsJudgedByServiceExecutable() throws {
        let brew = tmpDir.appendingPathComponent("bin/brew").path
        XCTAssertFalse(BrewServiceSync.isFormulaInstalled(brewPath: brew))

        let exe = tmpDir.appendingPathComponent(
            "opt/\(BrewServiceSync.formulaName)/fWarrangeCli.app/Contents/MacOS/fWarrangeCli")
        try FileManager.default.createDirectory(at: exe.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: exe.path, contents: Data(), attributes: [.posixPermissions: 0o755])
        XCTAssertTrue(BrewServiceSync.isFormulaInstalled(brewPath: brew))
    }

    /// `exit` right after an async log call used to drop the line (Issue109: no trace of the exit).
    /// The test host config sets logLevel 5 (file logging off), so raise it for this test.
    /// A backlog of lines makes the unflushed read lose the race deterministically.
    func testLoggerFlushWritesPendingLines() throws {
        let saved = Logger.shared.currentLogLevel
        Logger.shared.setLogLevel(.info)
        defer { Logger.shared.currentLogLevel = saved }

        let marker = "brew-handoff-flush-\(UUID().uuidString)"
        for i in 0..<300 { logW("brew-handoff-flush backlog \(i)") }
        logW(marker)
        Logger.shared.flush()
        let path = (Logger.shared.getLogFilePath() as NSString).expandingTildeInPath
        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains(marker))
    }
}

// MARK: - #23 storage-name-no-traversal (Issue117)

/// Layout and mode names become file names (`{dir}/{name}.yml`). A name with `/` must not
/// reach outside the storage folder — REST takes these names without a token.
final class StorageNameTraversalTests: XCTestCase {

    private var tmpDir: URL!
    private var dataDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StorageNameTraversalTests_\(UUID().uuidString)")
        dataDir = tmpDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent(name).path)
    }

    func testLayoutSaveRefusesTraversalName() {
        let storage = YAMLLayoutStorageService(dataDirectoryURL: dataDir)
        XCTAssertThrowsError(try storage.save(name: "../escape", windows: []))
        XCTAssertFalse(exists("escape.yml"), "nothing may be written outside the layout folder")
    }

    func testLayoutRenameRefusesTraversalName() throws {
        let storage = YAMLLayoutStorageService(dataDirectoryURL: dataDir)
        try storage.save(name: "ok", windows: [])
        XCTAssertThrowsError(try storage.rename(oldName: "ok", newName: "../moved"))
        XCTAssertFalse(exists("moved.yml"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataDir.appendingPathComponent("ok.yml").path))
    }

    func testLayoutDeleteRefusesTraversalName() throws {
        try "- app: \"x\"\n".write(to: tmpDir.appendingPathComponent("victim.yml"), atomically: true, encoding: .utf8)
        let storage = YAMLLayoutStorageService(dataDirectoryURL: dataDir)
        XCTAssertThrowsError(try storage.delete(name: "../victim"))
        XCTAssertTrue(exists("victim.yml"), "a file outside the layout folder must survive")
    }

    func testModeSaveRefusesTraversalName() {
        let base = tmpDir.appendingPathComponent("modebase")
        let storage = YAMLModeStorageService(baseDirectory: base)
        // modes live in {base}/{host}/modes — three levels up is tmpDir
        XCTAssertThrowsError(try storage.save(Mode(name: "../../../mode-escape", icon: "x", shortcut: nil, layoutRef: "x")))
        XCTAssertFalse(exists("mode-escape.yml"))
    }

    /// The single check REST uses before touching storage (capture name · rename newName · mode name).
    func testStorageNameRejection() {
        for bad in ["../x", "a/b", "/abs", "", "  ", ".", "..", "nul\0x", String(repeating: "a", count: 252)] {
            XCTAssertNotNil(StorageName.rejection(bad), "must refuse: \(bad.prefix(20))")
        }
        for good in ["Work Setup", "작업 1", "v1.2 layout", "..hidden-ish", "a:b", String(repeating: "a", count: 251)] {
            XCTAssertNil(StorageName.rejection(good), "must accept: \(good.prefix(20))")
        }
    }

    /// A whitespace-only name saved by an older build must stay openable, deletable and
    /// renamable — only *new* names get the full rule; existing ones only the escape check.
    func testLegacyBlankNameStaysManageable() throws {
        let storage = YAMLLayoutStorageService(dataDirectoryURL: dataDir)
        try "- app: \"x\"\n".write(to: dataDir.appendingPathComponent(" .yml"), atomically: true, encoding: .utf8)

        XCTAssertNoThrow(try storage.load(name: " "))
        XCTAssertNoThrow(try storage.rename(oldName: " ", newName: "rescued"))
        XCTAssertNoThrow(try storage.delete(name: "rescued"))
        XCTAssertThrowsError(try storage.save(name: " ", windows: []), "a new blank name is still refused")
        XCTAssertThrowsError(try storage.delete(name: "../victim"), "existing-item paths still refuse escapes")
    }

    /// Ordinary names keep working (spaces, unicode, dots inside).
    func testOrdinaryNamesStillWork() throws {
        let storage = YAMLLayoutStorageService(dataDirectoryURL: dataDir)
        for name in ["Work Setup", "작업 1", "v1.2 layout", "2026-10-04_001"] {
            try storage.save(name: name, windows: [])
            XCTAssertNoThrow(try storage.load(name: name))
        }
    }
}

// MARK: - #24 verify-failed-best-effort (Issue114 ①)

/// A window that was found and moved but failed the 3px position check must keep its
/// match info when the retry loop ends — at the last attempt *or* by the early exit.
/// Before the fix the early exit skipped the last-attempt branch, so a single TextEdit
/// window (height snapped to line units) was reported as `noMatch` → `windowNotFound`.
final class RestoreLeftoverTests: XCTestCase {

    private func target(_ id: Int, app: String = "TextEdit") -> WindowInfo {
        WindowInfo(id: id, app: app, window: "Untitled \(id)", layer: 0,
                   pos: WindowPosition(x: 100, y: 100), size: WindowSize(width: 600, height: 400))
    }

    func testVerifyFailedTargetIsBestEffortWithMatchKept() {
        let t = target(1)
        let r = RestoreLeftover.resolve(
            pending: [t],
            verifyFailures: [.init(target: t, title: "Untitled 1", matchType: .exactTitle, score: 90,
                                   actual: CGRect(x: 100, y: 100, width: 600, height: 390))])  // line-height snap

        XCTAssertEqual(r.bestEffort.count, 1)
        XCTAssertTrue(r.unmatched.isEmpty)
        let result = r.bestEffort[0]
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.matchType, .exactTitle)
        XCTAssertEqual(result.score, 90)
        XCTAssertEqual(result.matchedTitle, "Untitled 1")
        XCTAssertEqual(result.targetWindow, t)
    }

    func testTargetWithoutMatchStaysUnmatched() {
        let t = target(2)
        let r = RestoreLeftover.resolve(pending: [t], verifyFailures: [])
        XCTAssertTrue(r.bestEffort.isEmpty)
        XCTAssertEqual(r.unmatched, [t])
    }

    /// Only recorded targets are best-effort; a stale record for a target that is no
    /// longer pending (it succeeded later) is ignored.
    func testOnlyPendingRecordedTargetsAreBestEffort() {
        let failed = target(3), missing = target(4, app: "Notes"), done = target(5)
        let r = RestoreLeftover.resolve(
            pending: [failed, missing],
            verifyFailures: [
                .init(target: failed, title: "Untitled 3", matchType: .windowID, score: 100,
                      actual: CGRect(x: 100, y: 100, width: 600, height: 392)),
                .init(target: done, title: "Untitled 5", matchType: .windowID, score: 100)
            ])
        XCTAssertEqual(r.bestEffort.map(\.targetWindow), [failed])
        XCTAssertEqual(r.unmatched, [missing])
    }
}

// MARK: - #26 best-effort-has-a-bound (Issue121)

/// prj16 R1 (jma): a TextEdit window restored to 200,200 800×500 stayed at 200,40 1077×660 and the API
/// still said `succeeded` — Issue114's best-effort accepted any verify failure. Best effort is for
/// line-height snapping (a few px), not for a window that never got there.
final class RestoreBestEffortBoundTests: XCTestCase {

    private let target = WindowInfo(id: 1804, app: "TextEdit", window: "testBoard.txt", layer: 0,
                                    pos: WindowPosition(x: 200, y: 200), size: WindowSize(width: 800, height: 500))

    func testLargeDeviationIsReportedAsFailureWithMatchKept() {
        let r = RestoreLeftover.resolve(pending: [target], verifyFailures: [
            .init(target: target, title: "testBoard.txt", matchType: .windowID, score: 100,
                  actual: CGRect(x: 200, y: 40, width: 1077, height: 660))])

        XCTAssertTrue(r.bestEffort.isEmpty, "a window 160px / 277px off is not a success")
        XCTAssertEqual(r.offTarget.count, 1)
        XCTAssertFalse(r.offTarget[0].success)
        XCTAssertEqual(r.offTarget[0].matchType, .windowID, "match info is kept — it was found, just not placed")
        XCTAssertEqual(r.offTarget[0].score, 100)
        XCTAssertTrue(r.unmatched.isEmpty, "found windows must not fall to the Moom fallback / noMatch")
        XCTAssertEqual(RESTServer.classifyRestoreFailure(result: r.offTarget[0], minimumScore: 30,
                                                         runningAppNames: ["TextEdit"], runningBundleIDs: []),
                       "axOperationFailed")
    }

    func testLineHeightSnapIsStillBestEffort() {
        let r = RestoreLeftover.resolve(pending: [target], verifyFailures: [
            .init(target: target, title: "testBoard.txt", matchType: .windowID, score: 100,
                  actual: CGRect(x: 200, y: 200, width: 800, height: 486))])
        XCTAssertEqual(r.bestEffort.count, 1)
        XCTAssertTrue(r.offTarget.isEmpty)
    }

    func testUnmeasuredVerifyFailureIsNotASuccess() {
        let r = RestoreLeftover.resolve(pending: [target], verifyFailures: [
            .init(target: target, title: "testBoard.txt", matchType: .windowID, score: 100, actual: nil)])
        XCTAssertTrue(r.bestEffort.isEmpty, "unknown geometry cannot be called a success")
        XCTAssertEqual(r.offTarget.count, 1)
    }
}

// MARK: - #25 restart-comes-back (Issue119)

/// `POST /api/v2/cli/restart` only terminated and relied on launchd KeepAlive — the instance never came
/// back. jma showed that anything the app spawns dies with it, so the comeback is an independent launchd
/// job (`launchctl submit`) that waits for this PID, then kickstarts the service or re-opens the bundle.
final class AppRestarterTests: XCTestCase {

    override func tearDown() {
        AppRestarter.resetSeams()
        super.tearDown()
    }

    func testPlanForBrewServiceKickstartsTheSameLabel() {
        let p = AppRestarter.plan(pid: 123, uid: 501, bundlePath: "/opt/x.app", serviceLabel: "sh.brew.fwarrange-cli")
        XCTAssertEqual(p.path, .brewService)
        XCTAssertEqual(p.jobLabel, "kr.finfra.fWarrangeCli.relaunch.123")
        XCTAssertTrue(p.script.contains("kill -0 123"), "must wait for this PID to exit: \(p.script)")
        XCTAssertTrue(p.script.contains("/bin/launchctl kickstart gui/501/sh.brew.fwarrange-cli"), p.script)
        XCTAssertTrue(p.script.hasSuffix("/bin/launchctl remove kr.finfra.fWarrangeCli.relaunch.123"), "job removes itself")
        XCTAssertFalse(p.script.contains("/usr/bin/open"))
    }

    func testPlanForOpenInstanceReopensTheBundle() {
        let p = AppRestarter.plan(pid: 7, uid: 501, bundlePath: "/Applications/it's here.app", serviceLabel: nil)
        XCTAssertEqual(p.path, .openRelaunch)
        XCTAssertTrue(p.script.contains("kill -0 7"))
        XCTAssertTrue(p.script.contains("/usr/bin/open '/Applications/it'\\''s here.app'"), "bundle path must be shell-quoted: \(p.script)")
        XCTAssertFalse(p.script.contains("kickstart"))
    }

    /// The helper must be scheduled before quitting — and a failed schedule must not quit.
    func testRestartSchedulesHelperThenTerminates() {
        var events: [String] = []
        AppRestarter.managedServiceLabel = { nil }
        AppRestarter.submit = { label, _ in events.append("submit:\(label)"); return true }
        AppRestarter.terminate = { events.append("terminate") }

        XCTAssertEqual(AppRestarter.restart(reason: "test"), .openRelaunch)
        XCTAssertEqual(events, ["submit:kr.finfra.fWarrangeCli.relaunch.\(getpid())", "terminate"])
    }

    func testFailedSchedulingKeepsTheAppRunning() {
        var terminated = false
        AppRestarter.managedServiceLabel = { "sh.brew.fwarrange-cli" }
        AppRestarter.submit = { _, _ in false }
        AppRestarter.terminate = { terminated = true }

        AppRestarter.restart(reason: "test")
        XCTAssertFalse(terminated, "without a helper, quitting would be a plain stop")
    }

    /// jma: the brew-managed restart still came back as `none` — `applicationWillTerminate` ran its own
    /// `brew services stop` (Issue51) without the handoff guard, unloading the service the helper
    /// was about to kickstart. Termination sync must have one decision point that honours the restart.
    func testTerminateSyncSkipsBrewStopDuringRestart() {
        defer { BrewServiceSync.endManagedRelaunch() }
        XCTAssertEqual(BrewServiceSync.terminateStopArguments(launchAtLogin: true, siblingAlive: false),
                       ["services", "stop", "fwarrange-cli", "--keep"])
        XCTAssertEqual(BrewServiceSync.terminateStopArguments(launchAtLogin: false, siblingAlive: false),
                       ["services", "stop", "fwarrange-cli"])

        BrewServiceSync.beginManagedRelaunch()
        XCTAssertNil(BrewServiceSync.terminateStopArguments(launchAtLogin: true, siblingAlive: false),
                     "a restarting instance must leave the brew service loaded")
    }

    /// jma reboot: paidApp opened a cliApp before launchd spawned the RunAtLoad instance. The launchd
    /// winner terminated that sibling (Issue131), and the sibling's terminate sync ran
    /// `brew services stop --keep` — unloading the winner too, so no cliApp was left (Issue135).
    /// An instance that quits while a sibling is still alive is being retired, not stopped by the user.
    func testRetiredDuplicateLeavesBrewServiceLoaded() {
        XCTAssertNil(BrewServiceSync.terminateStopArguments(launchAtLogin: true, siblingAlive: true))
        XCTAssertNil(BrewServiceSync.terminateStopArguments(launchAtLogin: false, siblingAlive: true))
        XCTAssertFalse(BrewServiceSync.shouldSyncStopOnTerminate(siblingAlive: true),
                       "the menu Quit path must use the same decision")
    }

    /// A lone instance quit by the user still syncs brew to stopped (Issue51 behaviour kept).
    func testLoneInstanceQuitStillStopsBrew() {
        XCTAssertTrue(BrewServiceSync.shouldSyncStopOnTerminate(siblingAlive: false))
    }

    /// jma green run 1 still failed: the launchd winner terminates the sibling ~50 ms after it is spawned,
    /// before LaunchServices lists it — `NSRunningApplication` saw no sibling and the stop went through
    /// (`bootout initiated by: launchctl<-ruby<-fWarrangeCli[open pid]`). launchd's own table already
    /// carries the winner's PID, so a running service process that is not me counts as a sibling.
    func testServicePIDIsReadFromLaunchctlList() {
        let list = "PID\tStatus\tLabel\n-\t78\thomebrew.mxcl.libvirt\n19854\t0\tsh.brew.fwarrange-cli\n"
        XCTAssertEqual(BrewServiceSync.servicePID(fromLaunchctlList: list), 19854)
        XCTAssertNil(BrewServiceSync.servicePID(fromLaunchctlList: "-\t0\tsh.brew.fwarrange-cli\n"),
                     "loaded but not running is no sibling")
        XCTAssertNil(BrewServiceSync.servicePID(fromLaunchctlList: ""))
    }

    func testRunningServiceProcessOtherThanMeIsASibling() {
        XCTAssertTrue(BrewServiceSync.isSiblingAlive(myPID: 100, servicePID: 200, otherAppVisible: false),
                      "the just-spawned launchd winner, not yet in NSRunningApplication")
        XCTAssertFalse(BrewServiceSync.isSiblingAlive(myPID: 100, servicePID: 100, otherAppVisible: false),
                       "the launchd instance quitting itself is a user stop")
        XCTAssertFalse(BrewServiceSync.isSiblingAlive(myPID: 100, servicePID: nil, otherAppVisible: false))
        XCTAssertTrue(BrewServiceSync.isSiblingAlive(myPID: 100, servicePID: nil, otherAppVisible: true))
    }

    /// The REST endpoint must use that path — not a bare terminate.
    func testRESTRestartGoesThroughAppRestarter() throws {
        let scheduled = expectation(description: "helper scheduled")
        AppRestarter.managedServiceLabel = { nil }
        AppRestarter.submit = { _, script in
            XCTAssertTrue(script.contains("kill -0 \(getpid())"))
            scheduled.fulfill(); return true
        }
        AppRestarter.terminate = { }   // the test host must survive

        let port = RESTListenerLifecycleTests.freePort()
        let server = RESTServer(handlers: RESTListenerLifecycleTests.stubHandlers())
        server.start(port: port)
        defer { server.stop() }
        XCTAssertTrue(RESTListenerLifecycleTests.waitUntil {
            RESTListenerLifecycleTests.get(port: port, path: "/api/v2/health", timeout: 1).status == 200
        })

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/v2/cli/restart")!)
        req.httpMethod = "POST"
        req.setValue("true", forHTTPHeaderField: "X-Confirm")
        let responded = expectation(description: "200")
        var body = ""
        URLSession(configuration: .ephemeral).dataTask(with: req) { data, resp, _ in
            XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
            body = String(data: data ?? Data(), encoding: .utf8) ?? ""
            responded.fulfill()
        }.resume()

        wait(for: [responded, scheduled], timeout: 10)
        XCTAssertFalse(body.contains("KeepAlive"), "response must not claim launchd KeepAlive: \(body)")
    }
}

// MARK: - same-instant-duplicate-recheck (Issue131)

/// Issue131: two launch paths that fire in the same instant (`launchctl kickstart` + `open -a`)
/// both pass the launch-time check because neither is registered in NSRunningApplication yet
/// (TOCTOU). A delayed recheck runs the same rule again: the launchd-spawned instance terminates
/// the others and rebinds REST; a non-launchd instance yields only to an older one so two `open`
/// launches never both exit.
final class SingleInstanceRecheckTests: XCTestCase {

    private var events: [String] = []

    override func setUp() {
        events = []
    }

    private func environment(launchd: Bool, myPID: pid_t, others: [pid_t]) -> SingleInstanceGuard.RecheckEnvironment {
        SingleInstanceGuard.RecheckEnvironment(
            isLaunchedByLaunchd: { launchd },
            myPID: myPID,
            otherPIDs: { others },
            terminateOthers: { [unowned self] pids in events.append("terminate \(pids.map(String.init).joined(separator: ","))") },
            exitSelf: { [unowned self] in events.append("exit") },
            rebindREST: { [unowned self] in events.append("rebind") }
        )
    }

    /// The launch-time rule is unchanged: others seen at launch are older, so a non-launchd
    /// instance always yields and a launchd one always wins.
    func testLaunchDecisionKeepsExistingRule() {
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: false, myPID: 50, otherPIDs: [], atLaunch: true), .stay)
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: true, myPID: 50, otherPIDs: [], atLaunch: true), .stay)
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: true, myPID: 50, otherPIDs: [60, 70], atLaunch: true), .terminateOthers)
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: false, myPID: 50, otherPIDs: [60], atLaunch: true), .exitSelf)
    }

    /// On recheck a non-launchd instance yields only to an older PID — of two same-instant `open`
    /// launches exactly one survives, never zero.
    func testRecheckNonLaunchdYieldsOnlyToOlderInstance() {
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: false, myPID: 200, otherPIDs: [100], atLaunch: false), .exitSelf)
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: false, myPID: 100, otherPIDs: [200], atLaunch: false), .stay)
        XCTAssertEqual(SingleInstanceGuard.decide(iAmLaunchd: true, myPID: 300, otherPIDs: [100, 200], atLaunch: false), .terminateOthers)
    }

    /// The launchd winner terminates the duplicates first, then rebinds REST — the loser may have
    /// held port 3016 (jma repro: launchd instance alive without REST).
    func testRecheckWinnerTerminatesOthersThenRebindsREST() {
        let decision = SingleInstanceGuard.recheck(environment(launchd: true, myPID: 300, others: [100, 101]))
        XCTAssertEqual(decision, .terminateOthers)
        XCTAssertEqual(events, ["terminate 100,101", "rebind"])
    }

    func testRecheckLoserExitsWithoutTouchingOthers() {
        let decision = SingleInstanceGuard.recheck(environment(launchd: false, myPID: 200, others: [100]))
        XCTAssertEqual(decision, .exitSelf)
        XCTAssertEqual(events, ["exit"])
    }

    func testRecheckAloneDoesNothing() {
        let decision = SingleInstanceGuard.recheck(environment(launchd: true, myPID: 300, others: []))
        XCTAssertEqual(decision, .stay)
        XCTAssertEqual(events, [])
    }

    /// One recheck runs per delay (a late registration is still caught by the later one).
    func testScheduledRechecksRunOncePerDelay() {
        let done = expectation(description: "two rechecks")
        done.expectedFulfillmentCount = 2
        var env = environment(launchd: true, myPID: 300, others: [])
        env.otherPIDs = { done.fulfill(); return [] }
        SingleInstanceGuard.scheduleRechecks(delays: [0.01, 0.05], environment: env)
        wait(for: [done], timeout: 2.0)
    }

    // MARK: - modal-blocks-terminate (Issue131 ②)

    /// Fake process table: who is alive, who was force-terminated.
    private final class Box {
        var alive: Set<pid_t>
        var forced: [pid_t] = []
        init(alive: Set<pid_t>) { self.alive = alive }
    }

    /// jma E2E 0/10: an instance showing the accessibility alert (`runModal`) accepts the terminate
    /// request (`terminate()` → true) but never quits, so both instances stayed and the loser kept
    /// port 3016. A process still alive after the polite wait must be force-terminated.
    func testInstanceIgnoringTerminateIsForceTerminated() {
        let box = Box(alive: [100, 101])
        let ops = SingleInstanceGuard.TerminationOps(
            terminate: { pid in if pid == 101 { box.alive.remove(pid) }; return true },
            forceTerminate: { pid in box.forced.append(pid); box.alive.remove(pid) },
            isAlive: { box.alive.contains($0) },
            sleep: { _ in }
        )
        let survivors = SingleInstanceGuard.terminateAndWait([100, 101], politeTimeout: 3, ops: ops)
        XCTAssertEqual(box.forced, [100], "only the instance that ignored the request is forced")
        XCTAssertEqual(survivors, [])
    }

    func testPoliteInstancesAreNotForced() {
        let box = Box(alive: [100])
        let ops = SingleInstanceGuard.TerminationOps(
            terminate: { pid in box.alive.remove(pid); return true },
            forceTerminate: { pid in box.forced.append(pid) },
            isAlive: { box.alive.contains($0) },
            sleep: { _ in }
        )
        XCTAssertEqual(SingleInstanceGuard.terminateAndWait([100], politeTimeout: 3, ops: ops), [])
        XCTAssertEqual(box.forced, [])
    }
}
