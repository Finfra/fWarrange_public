import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    // settings.appLanguage 변경 시 SwiftUI가 자동 재렌더링 → 모든 L10n() 재계산
    private var lang: String { appState.effectiveLanguage }

    var body: some View {
        // Issue46: cliApp은 paidApp 미실행 시에만 표시됨 — cliOnly 섹션만 렌더링
        cliOnlySection

        Divider()

        statusSection

        Divider()

        Toggle(L10n("menu.launch_at_login", lang: lang), isOn: Binding(
            get: { appState.settings.launchAtLogin ?? false },
            set: { appState.setLaunchAtLogin($0) }
        ))

        Divider()

        Button(L10n("menu.open_log_folder", lang: lang)) {
            let logPath = Logger.shared.getLogFilePath()
            let url = URL(fileURLWithPath: (logPath as NSString).expandingTildeInPath)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

        Divider()

        Button(L10n("menu.quit", lang: lang)) {
            logI("👋 fWarrangeCli 종료")
            Logger.shared.writeSessionEnd()
            appState.restServer.stop()
            BrewServiceSync.onAppStop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - cliOnly 모드

    @ViewBuilder
    private var cliOnlySection: some View {
        Button(L10n("menu.open_paid_app", lang: lang)) {
            if !appState.launchPaidApp() {
                showPaidOnlyAlert()
            }
        }

        Button(L10n("menu.open_config_folder", lang: lang)) {
            let configPath = appState.settingsService.configFilePath
            let configURL = URL(fileURLWithPath: configPath)
            if FileManager.default.fileExists(atPath: configPath) {
                NSWorkspace.shared.activateFileViewerSelecting([configURL])
            } else {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
            }
        }
    }

    // MARK: - 공통 상태 섹션

    @ViewBuilder
    private var statusSection: some View {
        let statusText = appState.isRunning ? L10n("status.running", lang: lang) : L10n("status.stopped", lang: lang)
        Text("\(L10n("status.label", lang: lang)) \(statusText)")
        if appState.isRunning {
            Text("Port: \(appState.restServer.port)")
            Text("Uptime: \(appState.uptimeString)")
        }
    }

    // MARK: - fWarrange 미설치 안내

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
