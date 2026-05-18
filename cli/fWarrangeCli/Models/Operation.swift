import Foundation

/// Issue78: 진행 중 long-running operation 1건. `GET /api/v2/operations` 응답에 직렬화.
struct Operation {
    let opId: String
    let type: OpType
    let target: String
    let startedAt: Date

    func toDict(now: Date = Date()) -> [String: Any] {
        let elapsedMs = Int(now.timeIntervalSince(startedAt) * 1000.0)
        return [
            "opId": opId,
            "type": type.rawValue,
            "target": target,
            "startedAt": ISO8601DateFormatter().string(from: startedAt),
            "elapsedMs": max(0, elapsedMs)
        ]
    }
}
