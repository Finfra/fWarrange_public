import Foundation

/// Issue78: long-running operation 진행 추적 SSOT.
/// - register(): UUID 발급 + .opStarted 발행. 직렬화 대상이 이미 진행 중이면 nil 반환 (호출자가 409 Conflict 응답).
/// - complete(): operation 제거 + .opFinished 또는 .opFailed 발행.
/// - list(): `GET /api/v2/operations` 응답용 스냅샷.
actor OperationRegistry {
    static let shared = OperationRegistry()

    private var inflight: [String: Operation] = [:]

    private init() {}

    /// register operation. 직렬화 대상 중복 시 nil 반환.
    /// nil 반환 시 호출자는 `409 Conflict` HTTP 응답으로 거절해야 함.
    @discardableResult
    func register(type: OpType, target: String) -> String? {
        if type.isSerial {
            // 동일 type이 이미 진행 중이면 거절
            let busy = inflight.values.contains { $0.type == type }
            if busy {
                logI("[OperationRegistry] reject \(type.rawValue) — already in progress")
                return nil
            }
        }

        let opId = UUID().uuidString
        let op = Operation(opId: opId, type: type, target: target, startedAt: Date())
        inflight[opId] = op

        ChangeTracker.shared.record(type: "op.started", target: target, opId: opId)
        logI("[OperationRegistry] start opId=\(opId) type=\(type.rawValue) target=\(target)")
        return opId
    }

    /// complete operation. success=true → op.finished, false → op.failed.
    func complete(opId: String, success: Bool, reason: String? = nil) {
        guard let op = inflight.removeValue(forKey: opId) else {
            logW("[OperationRegistry] complete called for unknown opId=\(opId)")
            return
        }

        let eventType = success ? "op.finished" : "op.failed"
        ChangeTracker.shared.record(type: eventType, target: op.target, opId: opId)
        logI("[OperationRegistry] \(eventType) opId=\(opId) type=\(op.type.rawValue) target=\(op.target)\(reason.map { " reason=\($0)" } ?? "")")
    }

    /// 직렬화용 스냅샷. `/api/v2/operations` 응답에 사용.
    func list() -> [Operation] {
        Array(inflight.values).sorted { $0.startedAt < $1.startedAt }
    }
}
