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

    struct GetResult { var status: Int?; var error: Error?
        var refused: Bool { (error as? URLError)?.code == .cannotConnectToHost } }

    static func get(port: UInt16, path: String, timeout: TimeInterval) -> GetResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var result = GetResult()
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: URL(string: "http://127.0.0.1:\(port)\(path)")!) { _, resp, err in
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
}
