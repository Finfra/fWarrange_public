import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // Issue46: cliApp은 paidApp 미실행 시에만 표시됨 — cliOnly 섹션만 렌더링
        cliOnlySection

        Divider()

        statusSection

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
            BrewServiceSync.onAppStop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - cliOnly 모드

    @ViewBuilder
    private var cliOnlySection: some View {
        Button("fWarrange 앱 열기") {
            if !appState.launchPaidApp() {
                showPaidOnlyAlert()
            }
        }

        Button("설정 파일 폴더 열기") {
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
        Text("상태: \(appState.isRunning ? "실행 중" : "중지됨")")
        if appState.isRunning {
            Text("포트: \(appState.restServer.port)")
            Text("Uptime: \(appState.uptimeString)")
        }
    }

    // MARK: - fWarrange 미설치 안내

    private func showPaidOnlyAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "fWarrange를 찾을 수 없습니다"
        alert.informativeText = "fWarrange (App Store 버전)가 설치되어 있지 않습니다.\nApp Store에서 설치하거나, 이미 설치된 경우 앱을 직접 선택해주세요."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "App Store")
        alert.addButton(withTitle: "직접 찾기...")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "macappstore://apps.apple.com/app/fwarrange/id6744105753") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            let panel = NSOpenPanel()
            panel.title = "fWarrange.app 선택"
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
                    errorAlert.messageText = "잘못된 앱"
                    errorAlert.informativeText = "선택한 앱이 fWarrange가 아닙니다."
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        default:
            break
        }
    }
}
