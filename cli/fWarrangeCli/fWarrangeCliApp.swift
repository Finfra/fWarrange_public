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
        // launchAtLogin=true → stop --keep (plist 유지, 재부팅 시 자동 시작) / false → stop (plist 제거)
        // 판정은 BrewServiceSync 단일 지점 (Issue119: 재시작 중이면 nil — 서비스를 unload 하지 않는다)
        guard let arguments = BrewServiceSync.terminateStopArguments(launchAtLogin: launchAtLogin) else {
            logI("[brew-sync] applicationWillTerminate — 재시작 중이라 brew services stop 생략")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // 에러 발생 시에도 로깅
            fputs("Issue51: brew services 제어 오류 — \(error.localizedDescription)\n", stderr)
        }
    }
}

/// 프로세스 단일 AppState 소유자.
/// `@State var appState = AppState()` 를 App.init 에서 읽으면 SwiftUI(LazyStatePropertyBox)가 설치하는
/// 인스턴스와 init 이 읽은 인스턴스가 갈라져 AppState 가 2개 생긴다. init 쪽 인스턴스가 REST 서버를 띄운 뒤
/// 해제되면 3016 에 고아 listener 가 남아 연결을 받고도 응답하지 않는다 (prj5#Issue99 후속, jma 실측).
@MainActor
enum AppRuntime {
    static let appState = AppState()
}

struct fWarrangeCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        logI("🚀 fWarrangeCli 시작")
        let state = AppRuntime.appState
        appDelegate.settingsService = state.settingsService

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
