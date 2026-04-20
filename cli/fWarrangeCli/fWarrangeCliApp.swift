import SwiftUI

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

struct fWarrangeCliApp: App {
    @State private var appState = AppState()

    init() {
        logI("🚀 fWarrangeCli 시작")
        let state = appState
        DispatchQueue.main.async {
            state.initialize()
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { !appState.hideMenuBar },
            set: { appState.hideMenuBar = !$0 }
        )) {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(nsImage: Self.makeMenuBarIcon())
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }

    /// 메뉴바 아이콘: rectangle.3.group을 대각선으로 잘라 아래 부분을 숨김
    private static func makeMenuBarIcon() -> NSImage {
        let symbol = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "fWarrange")!
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // 대각선 위쪽만 보이도록 클리핑 영역 설정
            let clip = NSBezierPath()
            clip.move(to: NSPoint(x: 0, y: rect.height))                // 왼쪽 상단
            clip.line(to: NSPoint(x: rect.width, y: rect.height))       // 오른쪽 상단
            clip.line(to: NSPoint(x: rect.width, y: rect.height * 0.4)) // 오른쪽 40% 높이
            clip.line(to: NSPoint(x: 0, y: 0))                          // 왼쪽 하단
            clip.close()

            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            symbol.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()

            return true
        }
        image.isTemplate = true
        return image
    }
}
