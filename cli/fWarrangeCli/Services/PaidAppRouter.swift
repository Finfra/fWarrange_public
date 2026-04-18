import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Issue192 Phase A-4: paidApp 라이프사이클 REST 엔드포인트 비즈니스 로직.
///
/// `RESTServer`는 HTTP 파싱·응답 직렬화만 담당하고, 실제 상태 조작은 이 라우터로
/// 위임. 발신자 검증은 주입 가능 클로저 `senderBundleIdResolver`로 분리되어 테스트
/// 환경에서 Mock 처리 가능.
final class PaidAppRouter {

    /// REST 응답 종류. HTTP 상태 코드 매핑은 호출자(RESTServer)가 담당.
    enum RegisterResult {
        case success(PaidAppRegisterResponse)
        case forbidden(reason: String)   // 발신자 검증 실패 → 403
        case badRequest(reason: String)  // 스키마·파라미터 오류 → 400
        case notFound(reason: String)    // 상태 전이 불가 → 404
    }

    enum UnregisterResult {
        case success(PaidAppUnregisterResponse)
        case forbidden(reason: String)
        case badRequest(reason: String)
        case notFound(reason: String)
    }

    /// pid → bundleIdentifier 조회 클로저. 테스트에서 Mock 주입.
    /// 프로덕션 기본값은 `NSRunningApplication(processIdentifier:)`.
    typealias SenderBundleIdResolver = (_ pid: Int32) -> String?

    static let paidAppBundleId = "kr.finfra.fWarrange"

    private let store: PaidAppStateStore
    private let senderBundleIdResolver: SenderBundleIdResolver

    init(
        store: PaidAppStateStore,
        senderBundleIdResolver: @escaping SenderBundleIdResolver = PaidAppRouter.defaultSenderResolver
    ) {
        self.store = store
        self.senderBundleIdResolver = senderBundleIdResolver
    }

    // MARK: - Handlers

    func register(request: PaidAppRegisterRequest) -> RegisterResult {
        // 발신자 검증: pid가 실제 kr.finfra.fWarrange 프로세스인지 확인
        let resolvedBundleId = senderBundleIdResolver(request.pid)
        guard resolvedBundleId == Self.paidAppBundleId else {
            return .forbidden(
                reason: "paidapp/register 거부: pid=\(request.pid), 실제 bundleId=\(resolvedBundleId ?? "nil")"
            )
        }

        let sessionId = store.register(
            pid: request.pid,
            bundleId: Self.paidAppBundleId,
            startTime: request.startTime,
            version: request.version,
            bundlePath: request.bundlePath
        )

        // register가 새 세션을 발급한 직후 Store에서 registeredAt 조회
        guard case let .running(runtime) = store.currentState() else {
            // 극히 예외적 race: register 직후 상태가 변경됨. 서버 내부 문제로 보고.
            return .badRequest(reason: "상태 저장 실패 (concurrent)")
        }

        return .success(PaidAppRegisterResponse(
            sessionId: sessionId,
            registeredAt: runtime.registeredAt
        ))
    }

    func unregister(request: PaidAppUnregisterRequest) -> UnregisterResult {
        // 현재 상태 스냅샷 확인
        if case .notRunning = store.currentState() {
            return .notFound(reason: "등록된 paidApp 세션 없음")
        }

        let ok = store.unregister(pid: request.pid, sessionId: request.sessionId)
        if !ok {
            return .forbidden(reason: "sessionId 또는 pid 불일치 (위조 의심)")
        }

        let iso = Self.iso8601Now()
        return .success(PaidAppUnregisterResponse(unregisteredAt: iso))
    }

    func status() -> PaidAppStatusResponse {
        return store.statusResponse()
    }

    // MARK: - 기본 발신자 검증기 (프로덕션)

    static let defaultSenderResolver: SenderBundleIdResolver = { pid in
        #if canImport(AppKit)
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        #else
        return nil
        #endif
    }

    // MARK: - Helpers

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func iso8601Now() -> String {
        return iso8601Formatter.string(from: Date())
    }
}
