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

    // MARK: - 날짜별 시퀀스 이름 생성

    /// 오늘 날짜 prefix 기준으로 다음 시퀀스 번호가 붙은 레이아웃 이름을 생성함 (ex: "2026-04-12-3")
    func nextDailySequenceName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let datePrefix = formatter.string(from: date)
        let existingMax = layouts.compactMap { meta -> Int? in
            guard meta.name.hasPrefix("\(datePrefix)-") else { return nil }
            return Int(meta.name.dropFirst(datePrefix.count + 1))
        }.max() ?? 0
        return "\(datePrefix)-\(existingMax + 1)"
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
        // Issue73 Phase B: SSOT 이관 — 덮어쓰기 여부 판정 후 발행
        let existed = layouts.contains { $0.name == name }
        try storageService.save(name: name, windows: windows)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == name })
        loadDetail(name: name)
        ChangeTracker.shared.record(type: existed ? "layout.updated" : "layout.created", target: name)
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
        // Issue73 Phase B: SSOT 이관
        ChangeTracker.shared.record(type: "layout.deleted", target: name)
    }

    func deleteAllLayouts() throws {
        try storageService.deleteAll()
        layouts = []
        selectedMetadata = nil
        selectedLayoutDetail = nil
        // Issue73 Phase B: SSOT 이관 — 전체 삭제는 target="*"
        ChangeTracker.shared.record(type: "layout.deleted", target: "*")
    }

    func removeWindows(layoutName: String, windowIds: Set<Int>) throws {
        // removeWindows는 상세 데이터가 필요 → load 후 처리
        let layout = try storageService.load(name: layoutName)
        let filteredWindows = layout.windows.filter { !windowIds.contains($0.id) }
        try storageService.save(name: layoutName, windows: filteredWindows)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == layoutName })
        loadDetail(name: layoutName)
        // Issue73 Phase B: SSOT 이관 — Phase A 누락 발행 보강
        ChangeTracker.shared.record(type: "layout.updated", target: layoutName)
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
        // Issue73 Phase B+C: SSOT 이관 + 미니맵 드래그 등 연속 호출 폭주 방지 throttle
        ChangeTracker.shared.record(type: "layout.updated", target: layoutName, throttle: true)
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
        // Issue73 Phase B: SSOT 이관 — 각 name마다 layout.deleted
        for name in names {
            ChangeTracker.shared.record(type: "layout.deleted", target: name)
        }
    }

    func renameLayout(oldName: String, newName: String) throws {
        try storageService.rename(oldName: oldName, newName: newName)
        loadMetadataList()
        selectedMetadata = layouts.first(where: { $0.name == newName })
        loadDetail(name: newName)
        // Issue73 Phase B: SSOT 이관 — SSOT §6.4 매핑 (deleted oldName + created newName)
        ChangeTracker.shared.record(type: "layout.deleted", target: oldName)
        ChangeTracker.shared.record(type: "layout.created", target: newName)
    }
}
