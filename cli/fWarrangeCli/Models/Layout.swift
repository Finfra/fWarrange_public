import Foundation

/// 레이아웃 이름 규칙 SSOT
enum LayoutNaming {
    /// 자동 캡처(슬립/잠금) 레이아웃 이름 prefix. `auto-2026-06-15-1` 형태
    static let autoPrefix = "auto-"

    /// 이름이 자동 캡처 레이아웃인지 판정
    static func isAuto(_ name: String) -> Bool { name.hasPrefix(autoPrefix) }
}

/// 목록 표시용 경량 메타데이터 (YAML 본문 파싱 없이 생성)
struct LayoutMetadata: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String
    var windowCount: Int
    var fileDate: Date

    /// 자동 캡처(슬립/잠금) 레이아웃 여부 — 이름 prefix `auto-` 로 판정
    var isAuto: Bool { LayoutNaming.isAuto(name) }

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

    /// 자동 캡처(슬립/잠금) 레이아웃 여부 — 이름 prefix `auto-` 로 판정
    var isAuto: Bool { LayoutNaming.isAuto(name) }
}
