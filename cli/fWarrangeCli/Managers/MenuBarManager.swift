import AppKit

// NSStatusItem + NSMenu based menu bar implementation.
// Replaces SwiftUI MenuBarExtra to enable standard F-key shortcuts with
// automatic right-aligned display via keyEquivalent + keyEquivalentModifierMask.
@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {
    // Default display shortcuts (menu-only; global hotkeys still require _config.yml — Issue61).
    private static let fallbackSave          = KeyboardShortcutConfig.from(displayString: "⌘F7")
    private static let fallbackRestoreLast   = KeyboardShortcutConfig.from(displayString: "⌥⌘F7")
    private static let fallbackRestoreDefault = KeyboardShortcutConfig.from(displayString: "⇧⌘F7")
    private static let fallbackShowMain      = KeyboardShortcutConfig.from(displayString: "⌃⇧⌘F7")
    private var statusItem: NSStatusItem?
    private weak var appState: AppState?

    nonisolated override init() {
        super.init()
    }

    func setup(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        rebuildMenu()
        observeIcon()
        observeLanguage()
    }

    func updateIcon() {
        guard let button = statusItem?.button, let state = appState else { return }
        let icon = state.menuBarIcon
        icon.isTemplate = state.menuBarIconIsTemplate
        button.image = icon
    }

    func rebuildMenu() {
        guard let state = appState else { return }
        let menu = NSMenu()
        menu.delegate = self
        buildMenuItems(menu: menu, state: state)
        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Update the same menu object in-place to avoid separator rendering issues
        // that occur when statusItem.menu is replaced while the menu is opening.
        guard let state = appState else { return }
        menu.removeAllItems()
        buildMenuItems(menu: menu, state: state)
    }

    // MARK: - Private: observation

    private func observeIcon() {
        guard let state = appState else { return }
        withObservationTracking {
            _ = state.menuBarIcon
            _ = state.menuBarIconIsTemplate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateIcon()
                self?.observeIcon()
            }
        }
    }

    private func observeLanguage() {
        guard let state = appState else { return }
        withObservationTracking {
            _ = state.effectiveLanguage
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.rebuildMenu()
                self?.observeLanguage()
            }
        }
    }

    // MARK: - Menu builder

    private func buildMenuItems(menu: NSMenu, state: AppState) {
        let lang = state.effectiveLanguage

        // About
        menu.addItem(makeItem(
            title: "ℹ️ " + L10n("menu.about", lang: lang),
            action: #selector(showAbout)
        ))

        menu.addItem(.separator())

        // Restore Last Layout
        menu.addItem(makeShortcutItem(
            title: "🔁 " + L10n("menu.restore_last", lang: lang),
            action: #selector(restoreLast),
            shortcut: state.settings.restoreLastShortcut ?? MenuBarManager.fallbackRestoreLast
        ))

        // Restore Default Layout
        menu.addItem(makeShortcutItem(
            title: "⭐ " + L10n("menu.restore_default", lang: lang),
            action: #selector(restoreDefault),
            shortcut: state.settings.restoreDefaultShortcut ?? MenuBarManager.fallbackRestoreDefault
        ))

        // Layout list (Default + Recent N + ...and K more)
        buildLayoutItems(menu: menu, state: state, lang: lang)

        menu.addItem(.separator())

        // Open Main Window
        menu.addItem(makeShortcutItem(
            title: "🖥️ " + L10n("menu.open_main_window", lang: lang),
            action: #selector(openMainWindow),
            shortcut: state.settings.showMainWindowShortcut ?? MenuBarManager.fallbackShowMain
        ))

        // Save Window Layout
        menu.addItem(makeShortcutItem(
            title: "📷 " + L10n("menu.save_layout", lang: lang),
            action: #selector(saveLayout),
            shortcut: state.settings.saveShortcut ?? MenuBarManager.fallbackSave
        ))

        // Daemon submenu
        menu.addItem(buildDaemonSubmenu(state: state, lang: lang))

        // Configuration submenu (Settings… is inside)
        menu.addItem(buildConfigSubmenu(state: state, lang: lang))

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = makeItem(
            title: "🚀 " + L10n("menu.launch_at_login", lang: lang),
            action: #selector(toggleLaunchAtLogin)
        )
        loginItem.state = (state.settings.launchAtLogin ?? false) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = makeItem(
            title: L10n("menu.quit", lang: lang),
            action: #selector(quitApp),
            keyEquivalent: "q",
            modifierMask: .command
        )
        menu.addItem(quitItem)
    }

    // MARK: - Layout list section

    private func buildLayoutItems(menu: NSMenu, state: AppState, lang: String) {
        let metadataList = state.layoutManager.layouts
        guard !metadataList.isEmpty else { return }

        let recentLimit = 5
        let sorted = metadataList.sorted { $0.fileDate > $1.fileDate }
        let defaultName = state.settings.defaultLayoutName
        var visible: [(name: String, label: String)] = []
        var seen = Set<String>()

        if let defaultName,
           let meta = sorted.first(where: { $0.name == defaultName }) {
            let label = String(format: L10n("menu.layout.default_marker", lang: lang), "⭐ " + meta.name)
            visible.append((meta.name, label))
            seen.insert(meta.name)
        } else if defaultName == nil {
            let unsetItem = NSMenuItem(title: L10n("menu.layout.unset_default", lang: lang), action: nil, keyEquivalent: "")
            unsetItem.isEnabled = false
            menu.addItem(unsetItem)
        }

        for meta in sorted where !seen.contains(meta.name) {
            if visible.count >= recentLimit + (seen.isEmpty ? 0 : 1) { break }
            visible.append((meta.name, meta.name))
            seen.insert(meta.name)
        }

        for entry in visible {
            let item = makeItem(title: entry.label, action: #selector(restoreLayout(_:)))
            item.representedObject = entry.name
            menu.addItem(item)
        }

        let moreCount = max(0, metadataList.count - visible.count)
        if moreCount > 0 {
            let moreItem = NSMenuItem(
                title: String(format: L10n("menu.layout.more_count", lang: lang), moreCount),
                action: nil,
                keyEquivalent: ""
            )
            moreItem.isEnabled = false
            menu.addItem(moreItem)
        }
    }

    // MARK: - Daemon submenu

    private func buildDaemonSubmenu(state: AppState, lang: String) -> NSMenuItem {
        let submenu = NSMenu()

        let statusText: String
        if state.isRunning {
            statusText = String(
                format: L10n("menu.daemon.status_running", lang: lang),
                state.restServer.port,
                state.uptimeString
            )
        } else {
            statusText = L10n("menu.daemon.status_stopped", lang: lang)
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        submenu.addItem(statusItem)

        submenu.addItem(.separator())

        submenu.addItem(makeItem(
            title: L10n("menu.daemon.restart", lang: lang),
            action: #selector(restartDaemon)
        ))

        // Pause/Resume REST API
        let isPaused = state.restServer.isApiPaused
        let pauseLabel = L10n(isPaused ? "menu.daemon.resume" : "menu.daemon.pause", lang: lang)
        let pauseItem = makeItem(title: pauseLabel, action: #selector(pauseResumeAPI))
        pauseItem.isEnabled = state.isRunning
        submenu.addItem(pauseItem)

        let container = NSMenuItem(
            title: "👻 " + L10n("menu.daemon.title", lang: lang),
            action: nil,
            keyEquivalent: ""
        )
        container.submenu = submenu
        return container
    }

    // MARK: - Configuration submenu

    private func buildConfigSubmenu(state: AppState, lang: String) -> NSMenuItem {
        let submenu = NSMenu()

        submenu.addItem(makeItem(
            title: "⚙️ " + L10n("menu.config.settings", lang: lang),
            action: #selector(openSettings)
        ))
        submenu.addItem(makeItem(
            title: "📄 " + L10n("menu.config.open_file", lang: lang),
            action: #selector(openConfigFile)
        ))
        submenu.addItem(makeItem(
            title: "📁 " + L10n("menu.config.open_data", lang: lang),
            action: #selector(openDataFolder)
        ))
        submenu.addItem(makeItem(
            title: "📋 " + L10n("menu.open_log_folder", lang: lang),
            action: #selector(openLogFolder)
        ))

        let container = NSMenuItem(
            title: "⚙️ " + L10n("menu.config.title", lang: lang),
            action: nil,
            keyEquivalent: ""
        )
        container.submenu = submenu
        return container
    }

    // MARK: - NSMenuItem factory helpers

    private func makeItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifierMask
        item.target = self
        return item
    }

    private func makeShortcutItem(
        title: String,
        action: Selector,
        shortcut: KeyboardShortcutConfig?
    ) -> NSMenuItem {
        let item: NSMenuItem
        if let shortcut {
            let parsed = KeySpecParser.parse(shortcut.displayString)
            item = NSMenuItem(title: title, action: action, keyEquivalent: parsed.key)
            item.keyEquivalentModifierMask = parsed.modifiers
        } else {
            item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        }
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func showAbout() {
        AboutWindowManager.shared.showAbout()
    }

    @objc private func restoreLast() {
        appState?.handleHotKeyAction(.restoreLast)
    }

    @objc private func restoreDefault() {
        appState?.handleHotKeyAction(.restoreDefault)
    }

    @objc private func restoreLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        appState?.restoreLayoutByName(name)
    }

    @objc private func openMainWindow() {
        guard let state = appState else { return }
        if state.detectPaidApp() != nil {
            _ = state.launchPaidApp()
        } else {
            // Defer to next run-loop so the menu fully closes before the modal alert appears.
            DispatchQueue.main.async { [weak self] in self?.showPaidOnlyAlert() }
        }
    }

    @objc private func saveLayout() {
        appState?.handleHotKeyAction(.save)
    }

    @objc private func restartDaemon() {
        guard let state = appState else { return }
        let port = UInt16(state.settings.restServerPort ?? 3016)
        state.restServer.stop()
        state.restServer.start(port: port)
        logI("🔁 데몬 재시작: port \(port)")
    }

    @objc private func pauseResumeAPI() {
        guard let state = appState else { return }
        if state.restServer.isApiPaused {
            state.restServer.resumeAPI()
        } else {
            state.restServer.pauseAPI()
        }
        rebuildMenu()
    }

    @objc private func openSettings() {
        guard let state = appState else { return }
        if state.detectPaidApp() != nil {
            state.openPaidApp(action: "settings")
        } else {
            DispatchQueue.main.async { [weak self] in self?.showPaidOnlyAlert() }
        }
    }

    @objc private func openConfigFile() {
        guard let state = appState else { return }
        let configPath = state.settingsService.configFilePath
        let configURL = URL(fileURLWithPath: configPath)
        if FileManager.default.fileExists(atPath: configPath) {
            NSWorkspace.shared.activateFileViewerSelecting([configURL])
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
        }
    }

    @objc private func openDataFolder() {
        guard let state = appState else { return }
        let dataDir = state.layoutManager.dataDirectoryPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dataDir)
    }

    @objc private func openLogFolder() {
        let logPath = Logger.shared.getLogFilePath()
        let url = URL(fileURLWithPath: (logPath as NSString).expandingTildeInPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    @objc private func toggleLaunchAtLogin() {
        guard let state = appState else { return }
        let current = state.settings.launchAtLogin ?? false
        state.setLaunchAtLogin(!current)
        rebuildMenu()
    }

    @objc private func quitApp() {
        guard let state = appState else {
            NSApplication.shared.terminate(nil)
            return
        }
        logI("👋 fWarrangeCli 종료")
        state.restServer.stop()
        BrewServiceSync.onAppStop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - paidApp 미감지 안내

    private func showPaidOnlyAlert() {
        guard let state = appState else { return }
        let lang = state.effectiveLanguage
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n("alert.paid_not_found.title", lang: lang)
        alert.informativeText = L10n("alert.paid_not_found.message", lang: lang)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n("alert.paid_not_found.app_store", lang: lang))
        alert.addButton(withTitle: L10n("alert.paid_not_found.browse", lang: lang))
        alert.addButton(withTitle: L10n("alert.paid_not_found.cancel", lang: lang))

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "macappstore://apps.apple.com/app/fwarrange/id6744105753") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            let panel = NSOpenPanel()
            panel.title = "fWarrange.app"
            panel.allowedContentTypes = [.application]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            if panel.runModal() == .OK, let selectedURL = panel.url {
                if let bundle = Bundle(url: selectedURL),
                   bundle.bundleIdentifier == "kr.finfra.fWarrange" {
                    NSWorkspace.shared.open(selectedURL)
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = L10n("alert.invalid_app.title", lang: lang)
                    errorAlert.informativeText = L10n("alert.invalid_app.message", lang: lang)
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        default:
            break
        }
    }
}
