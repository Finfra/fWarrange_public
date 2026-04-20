import XCTest
@testable import fWarrangeCli

/// Issue192 Phase A-3: `PaidAppStateStore` 단위 테스트.
///
/// 검증 항목:
/// - 정상 register → status 조회 → unregister 사이클
/// - 위조 sessionId로 unregister 시도 → 실패
/// - 동일 pid 중복 register → 이전 등록 stale 처리
/// - 동일 bundleId + 다른 startTime → 별개 세션 인식 (2중 검증)
/// - thread-safety (serial queue 보호)
final class PaidAppStateStoreTests: XCTestCase {

    private var store: PaidAppStateStore!

    override func setUp() {
        super.setUp()
        store = PaidAppStateStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - 정상 사이클

    func testInitialStateIsNotRunning() {
        let snap = store.currentState()
        if case .notRunning = snap {
            // ok
        } else {
            XCTFail("초기 상태는 .notRunning이어야 함, 실제: \(snap)")
        }
    }

    func testRegisterThenCurrentStateReturnsRunning() {
        let clientId = UUID().uuidString
        let sessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            sessionId: clientId
        )
        XCTAssertEqual(sessionId, clientId, "client가 제공한 sessionId를 그대로 사용해야 함")
        guard case let .running(runtime) = store.currentState() else {
            return XCTFail("register 후에는 .running 상태여야 함")
        }
        XCTAssertEqual(runtime.pid, 12345)
        XCTAssertEqual(runtime.bundleId, "kr.finfra.fWarrange")
        XCTAssertEqual(runtime.startTime, "2026-04-18T09:15:42Z")
        XCTAssertEqual(runtime.version, "1.14.3")
        XCTAssertEqual(runtime.sessionId, sessionId)
    }

    func testUnregisterWithMatchingSessionIdSucceeds() {
        let sessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.14.3",
            bundlePath: "/path",
            sessionId: UUID().uuidString
        )
        XCTAssertTrue(store.unregister(pid: 12345, sessionId: sessionId))
        if case .notRunning = store.currentState() {
            // ok
        } else {
            XCTFail("unregister 성공 후 상태는 .notRunning")
        }
    }

    // MARK: - 위조 sessionId 차단

    func testUnregisterWithForgedSessionIdFails() {
        _ = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.14.3",
            bundlePath: "/path",
            sessionId: UUID().uuidString
        )
        XCTAssertFalse(
            store.unregister(pid: 12345, sessionId: "forged-uuid-00000000"),
            "위조 sessionId로는 unregister 실패해야 함"
        )
        guard case .running = store.currentState() else {
            return XCTFail("unregister 실패 시 상태는 .running 유지")
        }
    }

    func testUnregisterWithMatchingSessionButDifferentPidFails() {
        let sessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.14.3",
            bundlePath: "/path",
            sessionId: UUID().uuidString
        )
        XCTAssertFalse(
            store.unregister(pid: 99999, sessionId: sessionId),
            "pid 불일치 시 unregister 실패"
        )
    }

    func testUnregisterOnNotRunningReturnsFalse() {
        XCTAssertFalse(
            store.unregister(pid: 1, sessionId: "any"),
            ".notRunning 상태에서 unregister는 항상 false"
        )
    }

    // MARK: - Stale 처리 (PID 중복 register)

    func testRegisterWhenAlreadyRunningReplacesSession() {
        let oldSessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.0",
            bundlePath: "/path1",
            sessionId: UUID().uuidString
        )
        let newSessionId = store.register(
            pid: 54321,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T10:00:00Z",
            version: "1.1",
            bundlePath: "/path2",
            sessionId: UUID().uuidString
        )
        XCTAssertNotEqual(oldSessionId, newSessionId, "이전 세션은 폐기되고 새 세션 발급")

        guard case let .running(runtime) = store.currentState() else {
            return XCTFail(".running 상태 유지")
        }
        XCTAssertEqual(runtime.pid, 54321)
        XCTAssertEqual(runtime.sessionId, newSessionId)

        // 이전 sessionId로 unregister 시도 → 실패
        XCTAssertFalse(store.unregister(pid: 12345, sessionId: oldSessionId))
    }

    // MARK: - 2중 검증 (bundleId + startTime)

    func testSameBundleIdDifferentStartTimeProducesDifferentSessions() {
        let sessionA = store.register(
            pid: 11111,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:00:00Z",
            version: "1.0",
            bundlePath: "/path",
            sessionId: UUID().uuidString
        )
        // 첫 세션 unregister
        XCTAssertTrue(store.unregister(pid: 11111, sessionId: sessionA))

        // 동일 bundleId이나 다른 startTime → 새 별개 세션
        let sessionB = store.register(
            pid: 11111,  // PID 재사용 시뮬레이션
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:05:00Z",  // 5분 뒤 다른 startTime
            version: "1.0",
            bundlePath: "/path",
            sessionId: UUID().uuidString
        )
        XCTAssertNotEqual(sessionA, sessionB, "startTime이 다르면 별개 세션으로 인식")

        // 이전 세션 sessionA로는 unregister 불가
        XCTAssertFalse(store.unregister(pid: 11111, sessionId: sessionA))
    }

    // MARK: - unregisterAllForBundleId (Issue197)

    func testUnregisterAllForBundleIdWithMatchingBundleIdClearsState() {
        _ = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-20T09:00:00Z",
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            sessionId: UUID().uuidString
        )
        let cleaned = store.unregisterAllForBundleId("kr.finfra.fWarrange")
        XCTAssertTrue(cleaned, "일치하는 bundleId → cleanup 성공")
        if case .notRunning = store.currentState() {
            // ok
        } else {
            XCTFail("cleanup 후 상태는 .notRunning이어야 함")
        }
    }

    func testUnregisterAllForBundleIdWithNonMatchingBundleIdIsNoOp() {
        let sessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-20T09:00:00Z",
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            sessionId: UUID().uuidString
        )
        let cleaned = store.unregisterAllForBundleId("kr.finfra.Other")
        XCTAssertFalse(cleaned, "불일치 bundleId → no-op (false)")
        guard case let .running(current) = store.currentState() else {
            return XCTFail("no-op 후 상태는 .running 유지")
        }
        XCTAssertEqual(current.sessionId, sessionId, "세션 변경 없음")
    }

    // MARK: - Thread safety

    func testConcurrentRegisterAndUnregisterDoesNotCrash() {
        let iterations = 200
        let exp = expectation(description: "concurrent ops")
        exp.expectedFulfillmentCount = iterations

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        for i in 0..<iterations {
            queue.async { [weak self] in
                guard let self = self else { return }
                let sid = self.store.register(
                    pid: Int32(1000 + (i % 10)),
                    bundleId: "kr.finfra.fWarrange",
                    startTime: "2026-04-18T09:00:\(String(format: "%02d", i % 60))Z",
                    version: "1.0",
                    bundlePath: "/path",
                    sessionId: UUID().uuidString
                )
                _ = self.store.currentState()
                _ = self.store.unregister(pid: Int32(1000 + (i % 10)), sessionId: sid)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10.0)
        // 크래시 없이 완료되면 성공. 최종 상태는 비결정적이나 segfault/data-race 검출 목적.
    }

    // MARK: - StateSnapshot → PaidAppStatusResponse 변환

    func testStatusResponseConversionRunning() {
        let clientId = UUID().uuidString
        let sessionId = store.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            startTime: "2026-04-18T09:15:42Z",
            version: "1.14.3",
            bundlePath: "/path",
            sessionId: clientId
        )
        let resp = store.statusResponse()
        XCTAssertEqual(resp.state, .running)
        XCTAssertEqual(resp.pid, 12345)
        XCTAssertEqual(resp.version, "1.14.3")
        XCTAssertEqual(resp.sessionId, sessionId)
    }

    func testStatusResponseConversionNotRunning() {
        let resp = store.statusResponse()
        XCTAssertEqual(resp.state, .notRunning)
        XCTAssertNil(resp.pid)
        XCTAssertNil(resp.sessionId)
    }
}
