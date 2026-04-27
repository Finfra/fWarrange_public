import Foundation

/// Issue192 Phase A-3: paidApp 라이프사이클 상태 저장소.
///
/// - 내부 상태: `.notRunning` 또는 `.running(runtime)`
/// - 2중 검증 (PID 재사용 cycle 대응): `bundleId + startTime(s)` 매칭.
///   PID는 재사용될 수 있으나 `bundleId + startTime(s)` 조합은 실질적으로 유일함.
/// - 위조 차단: unregister는 `pid + sessionId` 정확 일치가 필요.
/// - thread-safety: serial `DispatchQueue`로 모든 상태 접근 감쌈 (REST 요청과
///   NSWorkspace 알림이 동시 접근 가능).
///
/// sessionId는 `UUID().uuidString` — paidApp이 in-memory로 보관하며
/// `UserDefaults`에는 저장하지 않음 (세션 단위 수명).
final class PaidAppStateStore {

    struct Runtime: Equatable {
        let pid: Int32
        let bundleId: String
        let startTime: String       // ISO8601 초 정밀도
        let version: String
        let bundlePath: String
        let sessionId: String       // UUID
        let registeredAt: String    // ISO8601
    }

    enum State: Equatable {
        case notRunning
        case running(Runtime)
    }

    /// stale 세션 감지 시 호출되는 클로저. 기본값은 logger 호출 없음. AppState init에서 주입됨.
    typealias OnSessionReplaced = (String, String, Int32, Int32) -> Void

    private let queue = DispatchQueue(label: "kr.finfra.fWarrangeCli.PaidAppStateStore")
    private var state: State = .notRunning
    private var onSessionReplaced: OnSessionReplaced = { _, _, _, _ in }

    init(onSessionReplaced: @escaping OnSessionReplaced = { _, _, _, _ in }) {
        self.onSessionReplaced = onSessionReplaced
    }

    // MARK: - Register / Unregister / Snapshot

    /// paidApp의 `applicationDidFinishLaunching`에서 호출되는 REST 진입점.
    /// 이미 `.running`이면 기존 세션을 stale 처리하고 새 sessionId를 저장한다.
    /// - Parameter sessionId: client-side에서 생성한 UUID. 빈 문자열이면 서버가 생성.
    /// - Returns: 저장된 sessionId. 호출자는 이 값을 보관해야 unregister 가능.
    @discardableResult
    func register(
        pid: Int32,
        bundleId: String,
        startTime: String,
        version: String,
        bundlePath: String,
        sessionId clientSessionId: String
    ) -> String {
        return queue.sync {
            let sessionId = clientSessionId.isEmpty ? UUID().uuidString : clientSessionId
            let registeredAt = Self.iso8601Now()
            let runtime = Runtime(
                pid: pid,
                bundleId: bundleId,
                startTime: startTime,
                version: version,
                bundlePath: bundlePath,
                sessionId: sessionId,
                registeredAt: registeredAt
            )
            if case let .running(existing) = state, existing.sessionId != sessionId {
                // 기존 세션은 stale 처리. onSessionReplaced 클로저 호출
                self.onSessionReplaced(existing.sessionId, sessionId, existing.pid, pid)
            }
            state = .running(runtime)
            return sessionId
        }
    }

    /// paidApp의 `applicationWillTerminate`에서 호출되는 REST 진입점.
    /// 단계 ③ startTime 보조 검증 지원:
    /// - `pid + sessionId` 쌍이 일치하면 성공 (sessionId 우선, startTime 무시)
    /// - `sessionId` 불일치 시 `startTime`으로 fallback 검증 (±2s 관용)
    /// - `startTime` nil이면 기존 동작 (sessionId+pid만 검증)
    /// - Returns: `true` = 세션 해제 성공, `false` = 불일치 또는 `.notRunning`
    @discardableResult
    func unregister(pid: Int32, sessionId: String, startTime: String? = nil) -> Bool {
        return queue.sync {
            guard case let .running(current) = state else {
                return false
            }
            let pidMatch = current.pid == pid
            let sessionMatch = current.sessionId == sessionId
            let startTimeMatch = startTime.map { Self.startTimesWithinTolerance(current.startTime, $0) } ?? true

            // pid 반드시 일치해야 함
            guard pidMatch else {
                return false
            }

            // sessionId 일치 시 startTime 우회 (sessionId 우선)
            // sessionId 불일치 시 startTime 검증
            guard sessionMatch || startTimeMatch else {
                return false
            }

            state = .notRunning
            return true
        }
    }

    /// 현재 상태 스냅샷. REST `GET /paidapp/status`와 `NSWorkspace` 알림 처리에서 사용.
    func currentState() -> State {
        return queue.sync { state }
    }

    /// NSWorkspace 종료 알림 경로 — bundleId 매칭 Runtime 발견 시 `.notRunning` 전이.
    /// pid·sessionId 없이 bundleId만으로 강제 cleanup. `kill -9` 후 unregister 미호출 보완.
    /// - Returns: `true` = 세션 정리 성공, `false` = `.notRunning` 또는 bundleId 불일치
    @discardableResult
    func unregisterAllForBundleId(_ bundleId: String) -> Bool {
        return queue.sync {
            guard case let .running(current) = state,
                  current.bundleId == bundleId else {
                return false
            }
            state = .notRunning
            return true
        }
    }

    /// `PaidAppStatusResponse`로 변환. 다른 모듈이 내부 타입에 의존하지 않도록 경계에서 매핑.
    func statusResponse() -> PaidAppStatusResponse {
        switch currentState() {
        case .notRunning:
            return PaidAppStatusResponse(state: .notRunning)
        case let .running(r):
            return PaidAppStatusResponse(
                state: .running,
                pid: r.pid,
                version: r.version,
                bundlePath: r.bundlePath,
                sessionId: r.sessionId,
                registeredAt: r.registeredAt
            )
        }
    }

    // MARK: - Helpers

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]  // 초 정밀도, "Z" 표기
        return f
    }()

    private static func iso8601Now() -> String {
        return iso8601Formatter.string(from: Date())
    }

    /// 단계 ③ startTime 관용 비교 (±2초).
    /// ISO8601 문자열 두 개를 파싱해서 절대값 시간차가 2초 이내인지 검증.
    /// 파싱 실패는 false 반환 (안전한 실패).
    private static func startTimesWithinTolerance(_ time1: String, _ time2: String) -> Bool {
        guard let date1 = iso8601Formatter.date(from: time1),
              let date2 = iso8601Formatter.date(from: time2) else {
            return false
        }
        let diff = abs(date1.timeIntervalSince(date2))
        return diff <= 2.0
    }
}
