import Foundation

enum RestoreStatus: Equatable {
    case idle
    case restoring(progress: Double, current: String)
    case completed(total: Int, succeeded: Int)
    case failed(message: String)

    static func == (lhs: RestoreStatus, rhs: RestoreStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.restoring(lp, lc), .restoring(rp, rc)):
            return lp == rp && lc == rc
        case let (.completed(lt, ls), .completed(rt, rs)):
            return lt == rt && ls == rs
        case let (.failed(lm), .failed(rm)):
            return lm == rm
        default:
            return false
        }
    }
}
