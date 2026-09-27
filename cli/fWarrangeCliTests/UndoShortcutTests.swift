import XCTest
@testable import fWarrangeCli

/// Issue98 Undo 기능 — 순수 로직 검증(설정 기본값·액션 속성).
/// 스냅샷 캡처·복원은 windowManager(GUI/AX) 의존이라 여기서 다루지 않고 통합 검증으로 대체한다.
final class UndoShortcutTests: XCTestCase {

    /// Undo 단축키 기본값은 ⌃⌘F7 (신규라 기본값 부여 — 기존 4개는 nil).
    func testUndoShortcutDefaultIsControlCommandF7() {
        let cfg = AppSettings.defaults.undoShortcut
        XCTAssertNotNil(cfg, "undoShortcut 기본값이 있어야 한다")
        XCTAssertEqual(cfg?.displayString, "⌃⌘F7")
    }

    /// Undo 는 창 조작(AX)을 수반하므로 접근성 권한이 필요한 액션이다.
    func testUndoRequiresAccessibility() {
        XCTAssertTrue(HotKeyAction.undo.requiresAccessibility)
    }
}
