import XCTest
@testable import fWarrangeCli

/// Issue98 Undo 기능 — 순수 로직 검증(설정 기본값·액션 속성).
/// 스냅샷 캡처·복원은 windowManager(GUI/AX) 의존이라 여기서 다루지 않고 통합 검증으로 대체한다.
final class UndoShortcutTests: XCTestCase {

    /// Undo 단축키 기본값은 미지정(nil) — jm4 실설정 기준 (Issue130). ⌃⌘F7 은 사용자가 지정하는 예시일 뿐이다.
    func testUndoShortcutDefaultIsUnassigned() {
        XCTAssertNil(AppSettings.defaults.undoShortcut, "undoShortcut 기본값은 미지정이어야 한다")
    }

    // MARK: - Issue130 기본 단축키 = jm4 실설정

    /// jm4 실측(2026-10-15): save ⌘F7 · restoreDefault ⇧⌘F7 · restoreLast ⌥⌘F7 · showMainWindow ⌥⇧⌘F7 · undo 미지정.
    private func assertJm4Shortcuts(_ s: AppSettings, _ context: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(s.saveShortcut?.displayString, "⌘F7", "\(context) save", file: file, line: line)
        XCTAssertEqual(s.restoreDefaultShortcut?.displayString, "⇧⌘F7", "\(context) restoreDefault", file: file, line: line)
        XCTAssertEqual(s.restoreLastShortcut?.displayString, "⌥⌘F7", "\(context) restoreLast", file: file, line: line)
        XCTAssertEqual(s.showMainWindowShortcut?.displayString, "⌥⇧⌘F7", "\(context) showMainWindow", file: file, line: line)
        XCTAssertNil(s.undoShortcut, "\(context) undo 는 미지정이어야 한다", file: file, line: line)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    /// 새로 설치한 사용자(설정 파일 없음)는 번들 시드에서 jm4 와 같은 단축키 5값을 받는다.
    func testBundledSeedShortcutsMatchJm4() throws {
        let svc = YAMLSettingsService(baseDirectory: try makeTempDir())
        assertJm4Shortcuts(svc.load(), "첫 기동 시드")
    }

    /// 값 뒤 인라인 주석(`# {showMain} ...`)이 있어도 단축키가 파싱된다 — 시드 파일이 이 형태라
    /// 파서가 못 읽으면 새 설치에서 «Open Main Window» 단축키가 조용히 비어 있었다.
    func testInlineCommentAfterQuotedShortcutIsIgnored() throws {
        let dir = try makeTempDir()
        let yml = """
        saveShortcut: "⌘F7"   # save
        showMainWindowShortcut: "⌥⇧⌘F7" # {showMain}     Open Main Window
        restoreLastShortcut: ⌥⌘F7 # unquoted
        dataDirectoryPath: "~/a # b"
        """
        try yml.write(to: dir.appendingPathComponent("_config.yml"), atomically: true, encoding: .utf8)
        let s = YAMLSettingsService(baseDirectory: dir).load()
        XCTAssertEqual(s.saveShortcut?.displayString, "⌘F7")
        XCTAssertEqual(s.showMainWindowShortcut?.displayString, "⌥⇧⌘F7")
        XCTAssertEqual(s.restoreLastShortcut?.displayString, "⌥⌘F7")
        XCTAssertEqual(s.dataDirectoryPath, "~/a # b", "따옴표 안의 # 는 주석이 아니다")
    }

    /// 공장 초기화는 «번들 시드 재복사» — 사용자가 바꾼 단축키는 시드 4종으로 복원되고 undo 는 비워진다.
    func testFactoryResetRestoresSeedShortcuts() throws {
        let svc = YAMLSettingsService(baseDirectory: try makeTempDir())
        _ = svc.mutate { s in
            s.saveShortcut = nil
            s.showMainWindowShortcut = KeyboardShortcutConfig.from(displayString: "⌃⇧⌘F7")
            s.undoShortcut = KeyboardShortcutConfig.from(displayString: "⌃⌘F7")
        }
        svc.resetToDefaults()
        assertJm4Shortcuts(svc.load(), "공장 초기화 후")
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
