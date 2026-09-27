import SwiftUI
import AppKit

// CLI 인자가 있으면 SwiftUI 앱 초기화 전에 처리 후 종료
@main
struct AppEntry {
    static func main() {
        // XCTest 환경에서는 CLI 처리·중복차단을 건너뛰되 GUI RunLoop(fWarrangeCliApp.main)는 유지한다.
        // return 으로 조기 종료하거나 SingleInstanceGuard(brew 실행 중 = 중복)를 그대로 타면
        // exit 되어 test runner 연결 전에 host app 이 죽는다("Early unexpected exit"). (Issue99 테스트 인프라)
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests {
            if CLIHandler.handleIfNeeded() {
                return
            }
            // Issue39 Phase4: 동일 Bundle ID 중복 인스턴스 차단.
            // LaunchServices 가 심링크/경로 차이로 별개 인스턴스를 허용하는 경우
            // (`open _nowage_app/...` + `brew services start` 조합) 를 런타임에서 방어.
            if SingleInstanceGuard.shouldTerminateAsDuplicate() {
                exit(0)
            }
        }
        fWarrangeCliApp.main()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsService: SettingsService?
    let menuBarManager = MenuBarManager()

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.writeSessionEnd()

        // Issue51: 앱 종료 시 launchAtLogin 설정에 따라 brew services 제어
        if let settingsService = settingsService {
            let settings = settingsService.load()
            handleBrewServicesOnTerminate(launchAtLogin: settings.launchAtLogin ?? true)
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
        appDelegate.settingsService = appState.settingsService

        let state = appState
        let manager = appDelegate.menuBarManager
        // Issue62: NSStatusItem+NSMenu — initialize after AppState is ready
        DispatchQueue.main.async {
            state.initialize()
            manager.setup(appState: state)
        }
    }

    var body: some Scene {
        // Issue62: MenuBarExtra removed — NSStatusItem+NSMenu via MenuBarManager.
        // Settings scene kept as minimal SwiftUI anchor (LSUIElement=YES, no Dock icon).
        Settings { EmptyView() }
    }
}
