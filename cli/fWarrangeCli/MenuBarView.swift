import SwiftUI
import AppKit

// Issue58: menuBar_enhance.md SSOT — flat layout list + Daemon/Configuration submenus.
// Issue46 cliOnly branch removed: cliApp menu is always fully rendered (temporal exclusivity not applied for fWarrange — design doc §7.2.1/§7.4).
struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    // settings.appLanguage 변경 시 SwiftUI가 자동 재렌더링 → 모든 L10n() 재계산
    private var lang: String { appState.effectiveLanguage }

    // Recent layouts 표시 개수 (default layout 제외)
    private let recentLayoutLimit = 5

    var body: some View {
        // About
        Button(L10n("menu.about", lang: lang)) {
            AboutWindowManager.shared.showAbout()
        }

        Divider()

        // Restore Last / Restore Default
        restoreSection

        // Layout list (Default + Recent N + ...and K more)
        layoutListSection

        Divider()

        // Open Main Window / Save Window Layout
        mainActionsSection

        // 👻 Daemon submenu
        daemonSubmenu

        // ⚙️ Configuration submenu
        configSubmenu

        Divider()

        // Launch at Login toggle
        Toggle(L10n("menu.launch_at_login", lang: lang), isOn: Binding(
            get: { appState.settings.launchAtLogin ?? false },
            set: { appState.setLaunchAtLogin($0) }
        ))

        Divider()

        Button(L10n("menu.quit", lang: lang)) {
            logI("👋 fWarrangeCli 종료")
            appState.restServer.stop()
            BrewServiceSync.onAppStop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Restore (Last / Default)

    @ViewBuilder
    private var restoreSection: some View {
        Button(labelWithShortcut(
            "🔁 " + L10n("menu.restore_last", lang: lang),
            shortcut: appState.settings.restoreLastShortcut?.displayString
        )) {
            appState.handleHotKeyAction(.restoreLast)
        }

        Button(labelWithShortcut(
            "⭐ " + L10n("menu.restore_default", lang: lang),
            shortcut: appState.settings.restoreDefaultShortcut?.displayString
        )) {
            appState.handleHotKeyAction(.restoreDefault)
        }
    }

    // MARK: - Layout list (Default + Recent N + ...and K more)

    @ViewBuilder
    private var layoutListSection: some View {
        let entries = layoutEntries()
        ForEach(entries.visible, id: \.name) { entry in
            Button(entry.label) {
                appState.restoreLayoutByName(entry.name)
            }
        }
        if entries.moreCount > 0 {
            Text(String(format: L10n("menu.layout.more_count", lang: lang), entries.moreCount))
                .foregroundColor(.secondary)
        }
    }

    private struct LayoutEntry {
        let name: String
        let label: String
    }

    /// Default 레이아웃 + Recent N + (남은 K = moreCount) 구성
    private func layoutEntries() -> (visible: [LayoutEntry], moreCount: Int) {
        let metadataList = appState.layoutManager.layouts
        guard !metadataList.isEmpty else { return ([], 0) }

        let sorted = metadataList.sorted { $0.fileDate > $1.fileDate }
        let defaultName = appState.settings.defaultLayoutName
        var visible: [LayoutEntry] = []
        var seenNames = Set<String>()

        // Default 우선 노출
        if let defaultName,
           let defaultMeta = sorted.first(where: { $0.name == defaultName }) {
            let label = String(format: L10n("menu.layout.default_marker", lang: lang), "⭐ " + defaultMeta.name)
            visible.append(LayoutEntry(name: defaultMeta.name, label: label))
            seenNames.insert(defaultMeta.name)
        }

        // Recent N (Default 제외)
        for meta in sorted where !seenNames.contains(meta.name) {
            if visible.count >= recentLayoutLimit + (seenNames.isEmpty ? 0 : 1) { break }
            visible.append(LayoutEntry(name: meta.name, label: meta.name))
            seenNames.insert(meta.name)
        }

        let moreCount = max(0, metadataList.count - visible.count)
        return (visible, moreCount)
    }

    // MARK: - Main actions (Open Main Window / Save Window Layout)

    @ViewBuilder
    private var mainActionsSection: some View {
        Button(labelWithShortcut(
            L10n("menu.open_main_window", lang: lang),
            shortcut: appState.settings.showMainWindowShortcut?.displayString
        )) {
            // paidApp 감지 시 URL Scheme, 미감지 시 안내 다이얼로그
            if appState.detectPaidApp() != nil {
                _ = appState.launchPaidApp()
            } else {
                showPaidOnlyAlert()
            }
        }

        Button(labelWithShortcut(
            "📷 " + L10n("menu.save_layout", lang: lang),
            shortcut: appState.settings.saveShortcut?.displayString
        )) {
            appState.handleHotKeyAction(.save)
        }
    }

    // MARK: - 👻 Daemon submenu

    @ViewBuilder
    private var daemonSubmenu: some View {
        Menu("👻 " + L10n("menu.daemon.title", lang: lang)) {
            // Status line (단일 라인 응축)
            if appState.isRunning {
                Text(String(
                    format: L10n("menu.daemon.status_running", lang: lang),
                    appState.restServer.port,
                    appState.uptimeString
                ))
            } else {
                Text(L10n("menu.daemon.status_stopped", lang: lang))
            }

            Divider()

            Button(L10n("menu.daemon.restart", lang: lang)) {
                let port = UInt16(appState.settings.restServerPort ?? 3016)
                appState.restServer.stop()
                appState.restServer.start(port: port)
                logI("🔁 데몬 재시작: port \(port)")
            }

            // Pause/Resume: REST 엔드포인트 미존재 → 비활성화 (Issue58 plan §6.4)
            Button(L10n(appState.isRunning ? "menu.daemon.pause" : "menu.daemon.resume", lang: lang)) {
                // no-op (disabled)
            }
            .disabled(true)
        }
    }

    // MARK: - ⚙️ Configuration submenu

    @ViewBuilder
    private var configSubmenu: some View {
        Menu("⚙️ " + L10n("menu.config.title", lang: lang)) {
            // Settings… — paidApp 감지 시 URL Scheme 위임, 미감지 시 안내 다이얼로그
            // (cliApp 자체 Settings GUI 미보유 — paidApp 책임)
            Button(L10n("menu.config.settings", lang: lang)) {
                if appState.detectPaidApp() != nil {
                    appState.openPaidApp(action: "settings")
                } else {
                    showPaidOnlyAlert()
                }
            }

            Button(L10n("menu.config.open_file", lang: lang)) {
                let configPath = appState.settingsService.configFilePath
                let configURL = URL(fileURLWithPath: configPath)
                if FileManager.default.fileExists(atPath: configPath) {
                    NSWorkspace.shared.activateFileViewerSelecting([configURL])
                } else {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
                }
            }

            Button(L10n("menu.config.open_data", lang: lang)) {
                let dataDir = appState.layoutManager.dataDirectoryPath
                let dataURL = URL(fileURLWithPath: dataDir)
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dataURL.path)
            }

            Button(L10n("menu.open_log_folder", lang: lang)) {
                let logPath = Logger.shared.getLogFilePath()
                let url = URL(fileURLWithPath: (logPath as NSString).expandingTildeInPath)
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
        }
    }

    // MARK: - 라벨 + 단축키 표기 helper

    /// 라벨에 단축키를 우측 공백 정렬로 부착. 단축키가 없으면 라벨만 반환.
    /// SwiftUI Menu는 F-key 등 함수키를 keyboardShortcut으로 표현하기 어려워 텍스트 표기로 통일.
    private func labelWithShortcut(_ label: String, shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return label }
        return "\(label)    \(shortcut)"
    }

    // MARK: - paidApp 미감지 안내 (Settings·Open Main Window 공용)

    private func showPaidOnlyAlert() {
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
