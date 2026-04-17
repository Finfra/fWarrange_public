import Foundation

/// 작업 모드 — 레이아웃 + 단축키 + 아이콘을 묶는 컨텍스트 단위
struct Mode: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String
    var icon: String          // SF Symbol 이름 (ex: "laptopcomputer")
    var shortcut: String?     // 단축키 표시 문자열 (ex: "⌘F7")
    var layoutRef: String     // 참조할 Layout YAML 파일명 (확장자 제외)

    static func == (lhs: Mode, rhs: Mode) -> Bool {
        lhs.name == rhs.name
    }
}

/// 목록 표시용 경량 메타데이터
struct ModeMetadata: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String
    var icon: String
    var shortcut: String?
    var layoutRef: String
    var fileDate: Date

    static func == (lhs: ModeMetadata, rhs: ModeMetadata) -> Bool {
        lhs.name == rhs.name
    }
}
