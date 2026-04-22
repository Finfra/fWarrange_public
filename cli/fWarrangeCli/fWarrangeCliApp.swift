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
    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.writeSessionEnd()
    }
}

struct fWarrangeCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    init() {
        logI("🚀 fWarrangeCli 시작")
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
