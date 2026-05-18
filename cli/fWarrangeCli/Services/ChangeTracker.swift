import Foundation

/// 변경 이벤트 한 건
struct ChangeEvent {
    let seq: Int
    let type: String
    let target: String
    let timestamp: Date
    /// Issue78: op.* 이벤트에 발급된 operation UUID. data-change 이벤트는 nil.
    let opId: String?

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "seq": seq,
            "type": type,
            "target": target,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        if let opId = opId {
            dict["opId"] = opId
        }
        return dict
    }
}

/// 서버 측 변경 시퀀스 추적기.
/// 레이아웃/설정 변경 시 record()를 호출하면 단조 증가 시퀀스 번호와 함께 이력을 기록.
/// GET /api/v2/changes?since={seq} 엔드포인트에서 사용.
final class ChangeTracker {
    static let shared = ChangeTracker()

    private var currentSeq: Int = 0
    private var history: [ChangeEvent] = []
    private let maxHistory = 100
    private let lock = NSLock()
    /// Issue73 Phase C: throttle 옵션 적용 시 동일 (type, target) 이벤트가 이 간격 이내면 무시
    private let throttleInterval: TimeInterval = 0.1

    private init() {}

    /// 변경 이벤트 기록. seq를 자동 증가시키고 링버퍼에 추가.
    /// Issue73 Phase C: throttle=true 시 동일 (type, target) 이벤트가 throttleInterval 이내면
    /// 새 seq를 발급하지 않고 직전 seq를 반환 (폭주 방지).
    @discardableResult
    func record(type: String, target: String, throttle: Bool = false, opId: String? = nil) -> Int {
        lock.lock()
        defer { lock.unlock() }

        if throttle {
            // 뒤에서부터 동일 (type, target) 이벤트 탐색
            for event in history.reversed() {
                if event.type == type && event.target == target {
                    if Date().timeIntervalSince(event.timestamp) < throttleInterval {
                        logD("[ChangeTracker] throttle skip type=\(type) target=\(target) (seq=\(event.seq) 재사용)")
                        return event.seq
                    }
                    break
                }
            }
        }

        currentSeq += 1
        let event = ChangeEvent(seq: currentSeq, type: type, target: target, timestamp: Date(), opId: opId)
        history.append(event)

        // 링버퍼: 최대 100건 유지
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }

        logD("[ChangeTracker] seq=\(currentSeq) type=\(type) target=\(target)\(opId.map { " opId=\($0)" } ?? "")")
        return currentSeq
    }

    /// since 이후의 변경 목록과 현재 시퀀스 번호를 반환.
    /// since가 nil이면 최근 10건 반환.
    func changes(since: Int?) -> (currentSeq: Int, changes: [[String: Any]]) {
        lock.lock()
        defer { lock.unlock() }

        let filtered: [ChangeEvent]
        if let since = since {
            filtered = history.filter { $0.seq > since }
        } else {
            filtered = Array(history.suffix(10))
        }

        return (currentSeq: currentSeq, changes: filtered.map { $0.toDict() })
    }
}
