import XCTest
@testable import fWarrangeCli

/// Phase A-0 전제작업 — XCTest 타겟 동작 확인을 위한 최소 smoke test.
/// Phase A 구현이 시작되면 PaidAppStateStore, APIModels 등 실제 단위 테스트가 추가됨.
final class FWarrangeCliSmokeTests: XCTestCase {

    /// 테스트 번들이 앱 타겟을 @testable import 할 수 있는지 확인.
    func testRESTServerApiVersionConstant() {
        XCTAssertEqual(RESTServer.apiVersion, "v1", "API 버전 상수는 api-rules.md의 v1과 일치해야 함")
        XCTAssertEqual(RESTServer.apiBasePath, "/api/v1", "API 기본 경로 상수는 /api/v1이어야 함")
    }

    /// 테스트 호스트 앱 번들이 정상적으로 로딩되는지 확인.
    func testTestHostBundleLoaded() {
        XCTAssertNotNil(Bundle(for: Self.self), "테스트 번들이 로딩되어야 함")
    }
}
