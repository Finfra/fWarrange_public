import XCTest
@testable import fWarrangeCli

/// Issue192 Phase A-4: `PaidAppRouter` — REST 엔드포인트의 비즈니스 로직 계층.
///
/// `RESTServer`는 HTTP 파싱/응답 직렬화만 담당하고, 실제 register/unregister/status
/// 로직은 이 라우터로 위임. 발신자 검증은 외부 주입 클로저 `senderBundleIdResolver`로
/// 처리되어 테스트에서 Mock 가능.
final class PaidAppRouterTests: XCTestCase {

    private var store: PaidAppStateStore!
    private var validSenderBundleId: String?
    private var router: PaidAppRouter!

    override func setUp() {
        super.setUp()
        store = PaidAppStateStore()
        validSenderBundleId = "kr.finfra.fWarrange"
        router = PaidAppRouter(store: store) { [weak self] _ in
            self?.validSenderBundleId
        }
    }

    override func tearDown() {
        router = nil
        store = nil
        super.tearDown()
    }

    // MARK: - /paidapp/register

    func testRegisterWithValidSenderSucceeds() throws {
        let clientSessionId = UUID().uuidString
        let request = PaidAppRegisterRequest(
            pid: 12345,
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            startTime: "2026-04-18T09:15:42Z",
            sessionId: clientSessionId
        )
        let result = router.register(request: request)
        switch result {
        case let .success(response):
            XCTAssertFalse(response.sessionId.isEmpty)
            XCTAssertFalse(response.registeredAt.isEmpty)
        case .forbidden, .badRequest, .notFound:
            XCTFail("정상 발신자 register는 성공해야 함, 실제: \(result)")
        }
    }

    func testRegisterUsesClientProvidedSessionId() {
        let clientSessionId = UUID().uuidString
        let request = PaidAppRegisterRequest(
            pid: 12345,
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            startTime: "2026-04-18T09:15:42Z",
            sessionId: clientSessionId
        )
        guard case let .success(response) = router.register(request: request) else {
            return XCTFail("register 실패")
        }
        XCTAssertEqual(response.sessionId, clientSessionId, "응답 sessionId는 client가 제공한 UUID여야 함")
    }

    func testRegisterWithWrongSenderBundleIdFails403() {
        validSenderBundleId = "kr.finfra.fSnippet"  // 타 앱 위장
        let request = PaidAppRegisterRequest(
            pid: 12345,
            version: "1.0",
            bundlePath: "/path",
            startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        )
        let result = router.register(request: request)
        if case .forbidden = result {
            // ok
        } else {
            XCTFail("타 앱 bundleId는 403 거부해야 함, 실제: \(result)")
        }
        // Store는 .notRunning 유지
        if case .notRunning = store.currentState() { /* ok */ }
        else { XCTFail("거부 후에도 Store는 .notRunning 유지해야 함") }
    }

    func testRegisterWithNonexistentPidFails403() {
        validSenderBundleId = nil  // 프로세스 조회 실패
        let request = PaidAppRegisterRequest(
            pid: 99999,
            version: "1.0",
            bundlePath: "/path",
            startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        )
        let result = router.register(request: request)
        if case .forbidden = result {
            // ok
        } else {
            XCTFail("존재하지 않는 pid는 403, 실제: \(result)")
        }
    }

    // MARK: - /paidapp/unregister

    func testUnregisterWithMatchingSessionSucceeds() {
        // 먼저 등록
        let regResult = router.register(request: PaidAppRegisterRequest(
            pid: 12345, version: "1.0", bundlePath: "/p", startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        ))
        guard case let .success(regResp) = regResult else {
            return XCTFail("사전 register 실패")
        }

        // Unregister
        let unReq = PaidAppUnregisterRequest(pid: 12345, sessionId: regResp.sessionId)
        let result = router.unregister(request: unReq)
        switch result {
        case let .success(resp):
            XCTAssertFalse(resp.unregisteredAt.isEmpty)
        default:
            XCTFail("정상 unregister는 성공해야 함, 실제: \(result)")
        }
        if case .notRunning = store.currentState() { /* ok */ }
        else { XCTFail("unregister 후 .notRunning") }
    }

    func testUnregisterWithForgedSessionIdFails403() {
        _ = router.register(request: PaidAppRegisterRequest(
            pid: 12345, version: "1.0", bundlePath: "/p", startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        ))
        let result = router.unregister(request: PaidAppUnregisterRequest(
            pid: 12345, sessionId: "forged-uuid-000"
        ))
        if case .forbidden = result { /* ok */ }
        else { XCTFail("위조 sessionId는 403, 실제: \(result)") }
    }

    func testUnregisterOnNotRunningFails404() {
        let result = router.unregister(request: PaidAppUnregisterRequest(
            pid: 1, sessionId: "anything"
        ))
        if case .notFound = result { /* ok */ }
        else { XCTFail(".notRunning 상태의 unregister는 404, 실제: \(result)") }
    }

    // MARK: - /paidapp/status

    func testStatusReturnsNotRunningWhenEmpty() {
        let resp = router.status()
        XCTAssertEqual(resp.state, .notRunning)
        XCTAssertNil(resp.pid)
    }

    func testStatusReturnsRunningAfterRegister() {
        guard case let .success(reg) = router.register(request: PaidAppRegisterRequest(
            pid: 12345, version: "1.14.3", bundlePath: "/p", startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        )) else { return XCTFail("register 실패") }

        let resp = router.status()
        XCTAssertEqual(resp.state, .running)
        XCTAssertEqual(resp.pid, 12345)
        XCTAssertEqual(resp.version, "1.14.3")
        XCTAssertEqual(resp.sessionId, reg.sessionId)
    }

    // MARK: - 발신자 검증 클로저 호출 확인

    func testValidatorIsCalledWithRequestPid() {
        var receivedPid: Int32?
        let captureRouter = PaidAppRouter(store: store) { pid in
            receivedPid = pid
            return "kr.finfra.fWarrange"
        }
        _ = captureRouter.register(request: PaidAppRegisterRequest(
            pid: 54321, version: "1.0", bundlePath: "/p", startTime: "2026-04-18T09:00:00Z",
            sessionId: UUID().uuidString
        ))
        XCTAssertEqual(receivedPid, 54321)
    }
}
