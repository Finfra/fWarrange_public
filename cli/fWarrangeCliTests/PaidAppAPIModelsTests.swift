import XCTest
@testable import fWarrangeCli

/// Issue192 Phase A-2: PaidApp API 모델 JSON 라운드트립 테스트.
///
/// TDD RED: 본 파일 작성 시 `PaidAppRegisterRequest` 등이 존재하지 않아 컴파일 실패.
/// GREEN: Models/PaidAppAPIModels.swift 구현으로 통과.
final class PaidAppAPIModelsTests: XCTestCase {

    private var encoder: JSONEncoder!
    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    override func tearDown() {
        encoder = nil
        decoder = nil
        super.tearDown()
    }

    // MARK: - PaidAppRegisterRequest

    func testRegisterRequestRoundTrip() throws {
        let request = PaidAppRegisterRequest(
            pid: 12345,
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            startTime: "2026-04-18T09:15:42Z"
        )
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PaidAppRegisterRequest.self, from: data)
        XCTAssertEqual(decoded.pid, 12345)
        XCTAssertEqual(decoded.version, "1.14.3")
        XCTAssertEqual(decoded.bundlePath, "/Applications/_nowage_app/fWarrange.app")
        XCTAssertEqual(decoded.startTime, "2026-04-18T09:15:42Z")
    }

    func testRegisterRequestRejectsMissingPid() {
        let json = #"{"version":"1.0","bundlePath":"/a","startTime":"2026-04-18T09:15:42Z"}"#
        XCTAssertThrowsError(
            try decoder.decode(PaidAppRegisterRequest.self, from: Data(json.utf8))
        )
    }

    // MARK: - PaidAppRegisterResponse

    func testRegisterResponseRoundTrip() throws {
        let response = PaidAppRegisterResponse(
            sessionId: "550e8400-e29b-41d4-a716-446655440000",
            registeredAt: "2026-04-18T09:15:42Z",
            ok: true,
            cliVersion: "1.2.3",
            minPaidAppVersion: nil,
            compatible: true
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(PaidAppRegisterResponse.self, from: data)
        XCTAssertEqual(decoded.sessionId, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(decoded.registeredAt, "2026-04-18T09:15:42Z")
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.cliVersion, "1.2.3")
        XCTAssertNil(decoded.minPaidAppVersion)
        XCTAssertTrue(decoded.compatible)
    }

    // MARK: - PaidAppUnregisterRequest

    func testUnregisterRequestRoundTrip() throws {
        let request = PaidAppUnregisterRequest(
            pid: 12345,
            sessionId: "550e8400-e29b-41d4-a716-446655440000"
        )
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PaidAppUnregisterRequest.self, from: data)
        XCTAssertEqual(decoded.pid, 12345)
        XCTAssertEqual(decoded.sessionId, "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - PaidAppStatusResponse

    func testStatusResponseRunningRoundTrip() throws {
        let response = PaidAppStatusResponse(
            state: .running,
            pid: 12345,
            version: "1.14.3",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            sessionId: "550e8400-e29b-41d4-a716-446655440000",
            registeredAt: "2026-04-18T09:15:42Z"
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(PaidAppStatusResponse.self, from: data)
        XCTAssertEqual(decoded.state, .running)
        XCTAssertEqual(decoded.pid, 12345)
        XCTAssertEqual(decoded.version, "1.14.3")
        XCTAssertEqual(decoded.sessionId, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testStatusResponseNotRunningOmitsOptionalFields() throws {
        let response = PaidAppStatusResponse(state: .notRunning)
        let data = try encoder.encode(response)
        let json = String(decoding: data, as: UTF8.self)
        // not_running 상태에서는 pid/version/... 필드가 JSON에 나타나지 않아야 함
        XCTAssertFalse(json.contains("\"pid\""))
        XCTAssertFalse(json.contains("\"version\""))
        XCTAssertFalse(json.contains("\"sessionId\""))
        // decode 시에도 nil
        let decoded = try decoder.decode(PaidAppStatusResponse.self, from: data)
        XCTAssertEqual(decoded.state, .notRunning)
        XCTAssertNil(decoded.pid)
        XCTAssertNil(decoded.sessionId)
    }

    func testStatusResponseStateSerializesAsSnakeCase() throws {
        // openapi_v2.yaml enum: [running, not_running] — snake_case 유지
        let encoded = try encoder.encode(PaidAppStatusResponse(state: .notRunning))
        let json = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(json.contains("\"state\":\"not_running\""),
                      "state는 snake_case 'not_running'으로 직렬화되어야 함 (openapi_v2.yaml enum 대응)")
    }
}
