import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button("About fWarrangeCli") {
            AboutWindowManager.shared.showAbout()
        }

        Button("Settings") {
            if !appState.tryLaunchPaidFeature() {
                showPaidOnlyAlert()
            }
        }

        Button("Management Window") {
            if !appState.tryLaunchPaidFeature() {
                showPaidOnlyAlert()
            }
        }

        Divider()

        Text("상태: \(appState.isRunning ? "실행 중" : "중지됨")")
        if appState.isRunning {
            Text("포트: \(appState.restServer.port)")
            Text("Uptime: \(appState.uptimeString)")
        }

        Divider()

        Toggle("로그인 시 자동 시작", isOn: Binding(
            get: { appState.settings.launchAtLogin ?? false },
            set: { appState.setLaunchAtLogin($0) }
        ))

        Divider()

        Button("로그 폴더 열기") {
            let logPath = Logger.shared.getLogFilePath()
            let url = URL(fileURLWithPath: (logPath as NSString).expandingTildeInPath)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

        Divider()

        Button("종료") {
            logI("👋 fWarrangeCli 종료")
            appState.restServer.stop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func showPaidOnlyAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Only support the paid version"
        alert.informativeText = "This feature requires fWarrange (App Store version).\nYou can get it from the App Store or locate an already installed copy."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "App Store")
        alert.addButton(withTitle: "Locate...")
        alert.addButton(withTitle: "Open Config in Finder")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // App Store 페이지 열기
            if let url = URL(string: "macappstore://apps.apple.com/app/fwarrange/id6744105753") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // 파일 선택 패널로 fWarrange.app 찾기
            let panel = NSOpenPanel()
            panel.title = "Select fWarrange.app"
            panel.allowedContentTypes = [.application]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            if panel.runModal() == .OK, let selectedURL = panel.url {
                // 선택한 앱의 Bundle ID 검증
                if let bundle = Bundle(url: selectedURL),
                   bundle.bundleIdentifier == "kr.finfra.fWarrange" {
                    NSWorkspace.shared.open(selectedURL)
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Invalid application"
                    errorAlert.informativeText = "The selected app is not fWarrange."
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        case .alertThirdButtonReturn:
            // 설정 파일을 Finder에서 보기
            let configPath = appState.settingsService.configFilePath
            let configURL = URL(fileURLWithPath: configPath)
            if FileManager.default.fileExists(atPath: configPath) {
                NSWorkspace.shared.activateFileViewerSelecting([configURL])
            } else {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
            }
        default:
            break
        }
    }
}
