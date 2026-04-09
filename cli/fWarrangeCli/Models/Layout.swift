import Foundation

/// 목록 표시용 경량 메타데이터 (YAML 본문 파싱 없이 생성)
struct LayoutMetadata: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String
    var windowCount: Int
    var fileDate: Date

    static func == (lhs: LayoutMetadata, rhs: LayoutMetadata) -> Bool {
        lhs.name == rhs.name
    }
}

/// 상세 보기용 전체 레이아웃 (YAML 파싱 포함)
struct Layout: Identifiable {
    let id: UUID = UUID()
    var name: String
    var windows: [WindowInfo]
    var fileDate: Date
    var windowCount: Int { windows.count }
}
