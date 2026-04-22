import SwiftUI
import AppKit

// CLI 인자가 있으면 SwiftUI 앱 초기화 전에 처리 후 종료
@main
struct AppEntry {
    static func main() {
        if CLIHandler.handleIfNeeded() {
            return
        }
        // Issue39 Phase4: 동일 Bundle ID 중복 인스턴스 차단.
        // LaunchServices 가 심링크/경로 차이로 별개 인스턴스를 허용하는 경우
        // (`open _nowage_app/...` + `brew services start` 조합) 를 런타임에서 방어.
        if SingleInstanceGuard.shouldTerminateAsDuplicate() {
            exit(0)
        }
        fWarrangeCliApp.main()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsService: SettingsService?

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.writeSessionEnd()

        // Issue51: 앱 종료 시 launchAtLogin 설정에 따라 brew services 제어
        if let settingsService = settingsService {
            let settings = settingsService.load()
            handleBrewServicesOnTerminate(launchAtLogin: settings.launchAtLogin ?? false)
        }
    }

    private func handleBrewServicesOnTerminate(launchAtLogin: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

        if launchAtLogin {
            // launchAtLogin=true → brew services stop --keep (daemon plist 유지, 재부팅 시 자동 시작)
            process.arguments = ["services", "stop", "fwarrange-cli", "--keep"]
        } else {
            // launchAtLogin=false → brew services stop (daemon plist 제거, 재부팅 시 미시작)
            process.arguments = ["services", "stop", "fwarrange-cli"]
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // 에러 발생 시에도 로깅
            fputs("Issue51: brew services 제어 오류 — \(error.localizedDescription)\n", stderr)
        }
    }
}

struct fWarrangeCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    init() {
        logI("🚀 fWarrangeCli 시작")

        // Issue51: AppDelegate에 settingsService 주입 (앱 종료 시 brew services 제어용)
        appDelegate.settingsService = appState.settingsService

        let state = appState
        DispatchQueue.main.async {
            state.initialize()
        }
    }

    var body: some Scene {
        // Issue46: paidApp 실행 중이면 paidApp이 자체 MenuBarExtra를 소유하므로 cliApp 메뉴바 숨김
        MenuBarExtra(isInserted: Binding(
            get: { appState.paidAppMonitor.state == .cliOnly },
            set: { _ in }
        )) {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(nsImage: appState.menuBarIcon)
                .renderingMode(appState.menuBarIconIsTemplate ? .template : .original)
        }
        .menuBarExtraStyle(.menu)
    }
}
