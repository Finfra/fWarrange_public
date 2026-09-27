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

    // MARK: - Issue99 갭 (fwarrange-1c 실측): REST 로 바뀐 defaultLayoutName 정리

    /// REST(PUT /settings/default-layout)로 기본 레이아웃을 바꾼 뒤 그 레이아웃을 삭제하면,
    /// self.settings 스냅샷이 아니라 **최신 저장값(load)** 기준으로 죽은 참조가 정리돼야 한다.
    @MainActor
    func testClearDeadDefaultLayoutViaLatestStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let svc = YAMLSettingsService(baseDirectory: dir)
        // REST 로 기본 레이아웃을 바꾼 상황 — 저장소만 갱신(프로세스 스냅샷과 불일치)
        _ = svc.mutate { $0.defaultLayoutName = "new-via-rest" }
        // 그 레이아웃 삭제 → 최신 저장값 기준으로 정리돼야 한다
        let updated = AppState.clearDeadDefaultLayout(deletedName: "new-via-rest", svc: svc)
        XCTAssertNotNil(updated, "삭제된 이름이 최신 defaultLayoutName 과 일치하면 정리해야 한다")
        XCTAssertNil(svc.load().defaultLayoutName, "삭제 후 defaultLayoutName 이 nil 로 정리돼야 한다")
    }

    /// 일치하지 않는 삭제는 defaultLayoutName 을 건드리지 않는다.
    @MainActor
    func testClearDeadDefaultLayoutIgnoresNonMatch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let svc = YAMLSettingsService(baseDirectory: dir)
        _ = svc.mutate { $0.defaultLayoutName = "keep" }
        let updated = AppState.clearDeadDefaultLayout(deletedName: "other", svc: svc)
        XCTAssertNil(updated, "일치하지 않으면 정리하지 않는다")
        XCTAssertEqual(svc.load().defaultLayoutName, "keep")
    }
}
