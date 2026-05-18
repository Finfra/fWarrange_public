import Foundation

/// Issue78: long-running operation 종류. OpenAPI v2 `Operation.type` enum과 1:1 매칭.
/// 직렬화(capture/restore/factoryReset) 대상은 `isSerial == true`.
enum OpType: String, CaseIterable {
    case capture
    case restore
    case layoutDelete = "layout.delete"
    case layoutRename = "layout.rename"
    case settingsPatch = "settings.patch"
    case shortcutsSet = "shortcuts.set"
    case factoryReset

    /// 직렬화 대상 (동시 다발 금지) — capture/restore/factoryReset.
    /// 위반 시 핸들러는 409 Conflict 반환.
    var isSerial: Bool {
        switch self {
        case .capture, .restore, .factoryReset:
            return true
        default:
            return false
        }
    }
}
