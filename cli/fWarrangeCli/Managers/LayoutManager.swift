import Foundation
import CoreGraphics

@Observable @MainActor
final class LayoutManager {
    var layouts: [LayoutMetadata] = []
    var selectedMetadata: LayoutMetadata?
    var selectedLayoutDetail: Layout?
    var isLoadingDetail = false

    private let storageService: LayoutStorageService

    var dataDirectoryPath: String { storageService.dataDirectoryPath }

    init(storageService: LayoutStorageService) {
        self.storageService = storageService
    }

    // MARK: - 메타데이터 로드 (경량)

    func loadMetadataList() {
        do {
            layouts = try storageService.listLayoutMetadata()
            if let selected = selectedMetadata,
               !layouts.contains(where: { $0.name == selected.name }) {
                selectedMetadata = layouts.first
                selectedLayoutDetail = nil
            }
        } catch {
            layouts = []
        }
    }

    // MARK: - 상세 로드 (선택 시)

    func selectLayout(name: String) {
        selectedMetadata = layouts.first(where: { $0.name == name })
        loadDetail(name: name)
    }

    func loadDetail(name: String) {
        isLoadingDetail = true
        do {
            selectedLayoutDetail = try storageService.load(name: name)
        } catch {
            selectedLayoutDetail = nil
        }
        isLoadingDetail = false
    }

    // MARK: - 기존 호환 (loadAllLayouts)

    func loadAllLayouts() {
        loadMetadataList()
    }

    // MARK: - 직접 로드 (핫키 복구용)

    func storageServiceLoad(name: String) throws -> Layout {
        return try storageService.load(name: name)
    }

    // MARK: - CRUD

    func saveLayout(name: String, windows: [WindowInfo]) throws {
        try storageService.save(name: name, windows: windows)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == name })
        loadDetail(name: name)
    }

    func deleteLayout(name: String) throws {
        let wasSelected = selectedMetadata?.name == name
        try storageService.delete(name: name)
        loadMetadataList()
        if wasSelected {
            selectedMetadata = layouts.first
            if let first = selectedMetadata {
                loadDetail(name: first.name)
            } else {
                selectedLayoutDetail = nil
            }
        }
    }

    func deleteAllLayouts() throws {
        try storageService.deleteAll()
        layouts = []
        selectedMetadata = nil
        selectedLayoutDetail = nil
    }

    func removeWindows(layoutName: String, windowIds: Set<Int>) throws {
        // removeWindows는 상세 데이터가 필요 → load 후 처리
        let layout = try storageService.load(name: layoutName)
        let filteredWindows = layout.windows.filter { !windowIds.contains($0.id) }
        try storageService.save(name: layoutName, windows: filteredWindows)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == layoutName })
        loadDetail(name: layoutName)
    }

    func updateWindowPositions(layoutName: String, screenRect: CGRect, delta: CGSize) throws {
        logD("[LayoutManager] updateWindowPositions - layout: \(layoutName), screenRect: \(screenRect), delta: \(delta)")
        let layout = try storageService.load(name: layoutName)
        // 디버그: 각 윈도우 center 좌표 출력
        for w in layout.windows where w.layer == 0 {
            let cx = w.pos.x + w.size.width / 2
            let cy = w.pos.y + w.size.height / 2
            let inside = screenRect.contains(CGPoint(x: cx, y: cy))
            logD("[LayoutManager]   윈도우 '\(w.app)' center=(\(cx),\(cy)) inside=\(inside)")
        }
        var movedCount = 0
        let updatedWindows = layout.windows.map { window -> WindowInfo in
            let windowCenter = CGPoint(
                x: window.pos.x + window.size.width / 2,
                y: window.pos.y + window.size.height / 2
            )
            if screenRect.contains(windowCenter) {
                var updated = window
                updated.pos.x += delta.width
                updated.pos.y += delta.height
                movedCount += 1
                logD("[LayoutManager]   이동: \(window.app) '\(window.window)' (\(window.pos.x),\(window.pos.y)) → (\(updated.pos.x),\(updated.pos.y))")
                return updated
            }
            return window
        }
        logD("[LayoutManager] 총 \(layout.windows.count)개 중 \(movedCount)개 윈도우 이동")
        try storageService.save(name: layoutName, windows: updatedWindows)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == layoutName })
        loadDetail(name: layoutName)
    }

    // MARK: - 일괄 삭제

    /// 여러 레이아웃을 이름 목록으로 일괄 삭제
    func deleteLayouts(names: Set<String>) throws {
        for name in names {
            try storageService.delete(name: name)
        }
        loadMetadataList()
        // 선택된 항목이 삭제된 경우 첫 번째 레이아웃으로 이동
        if let selected = selectedMetadata, names.contains(selected.name) {
            selectedMetadata = layouts.first
            if let first = selectedMetadata {
                loadDetail(name: first.name)
            } else {
                selectedLayoutDetail = nil
            }
        }
    }

    func renameLayout(oldName: String, newName: String) throws {
        try storageService.rename(oldName: oldName, newName: newName)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == newName })
        loadDetail(name: newName)
    }
}
