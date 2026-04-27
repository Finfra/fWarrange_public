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

    /// bundlePath → bundleIdentifier 조회 클로저 (단계 ②). 테스트에서 Mock 주입.
    /// 프로덕션 기본값은 `Bundle(url:)?.bundleIdentifier`.
    typealias BundleIdAtPathResolver = (_ url: URL) -> String?

    static let paidAppBundleId = "kr.finfra.fWarrange"

    private let store: PaidAppStateStore
    private let senderBundleIdResolver: SenderBundleIdResolver
    private let bundleIdAtPathResolver: BundleIdAtPathResolver

    init(
        store: PaidAppStateStore,
        senderBundleIdResolver: @escaping SenderBundleIdResolver = PaidAppRouter.defaultSenderResolver,
        bundleIdAtPathResolver: @escaping BundleIdAtPathResolver = PaidAppRouter.defaultBundleIdAtPathResolver
    ) {
        self.store = store
        self.senderBundleIdResolver = senderBundleIdResolver
        self.bundleIdAtPathResolver = bundleIdAtPathResolver
    }

    // MARK: - Handlers

    func register(request: PaidAppRegisterRequest) -> RegisterResult {
        // 단계 ① 발신자 검증: pid가 실제 kr.finfra.fWarrange 프로세스인지 확인
        let resolvedBundleId = senderBundleIdResolver(request.pid)
        guard resolvedBundleId == Self.paidAppBundleId else {
            let reason = "paidapp/register 거부: 단계=1, pid=\(request.pid), 실제 bundleId=\(resolvedBundleId ?? "nil")"
            logW(reason)
            PaidAppStateLogger.shared.append(.rejected(
                stage: 1,
                pid: request.pid,
                claimedBundleId: Self.paidAppBundleId,
                actualBundleId: resolvedBundleId,
                reason: reason
            ))
            return .forbidden(reason: reason)
        }

        // 단계 ② bundlePath 검증: bundlePath가 실제 kr.finfra.fWarrange 번들인지 확인
        let bundleURL = URL(fileURLWithPath: request.bundlePath)
        let bundleAtPath = bundleIdAtPathResolver(bundleURL)
        guard bundleAtPath == Self.paidAppBundleId else {
            let reason = "paidapp/register 거부: 단계=2, bundlePath=\(request.bundlePath), 실제 bundleId=\(bundleAtPath ?? "nil")"
            logW(reason)
            PaidAppStateLogger.shared.append(.rejected(
                stage: 2,
                pid: request.pid,
                claimedBundleId: Self.paidAppBundleId,
                actualBundleId: bundleAtPath,
                reason: reason
            ))
            return .forbidden(reason: reason)
        }

        let sessionId = store.register(
            pid: request.pid,
            bundleId: Self.paidAppBundleId,
            startTime: request.startTime,
            version: request.version,
            bundlePath: request.bundlePath,
            sessionId: request.sessionId
        )

        // register가 새 세션을 발급한 직후 Store에서 registeredAt 조회
        guard case let .running(runtime) = store.currentState() else {
            // 극히 예외적 race: register 직후 상태가 변경됨. 서버 내부 문제로 보고.
            return .badRequest(reason: "상태 저장 실패 (concurrent)")
        }

        // 감사 로그: register 성공 이벤트
        PaidAppStateLogger.shared.append(.register(
            pid: request.pid,
            bundleId: Self.paidAppBundleId,
            version: request.version,
            bundlePath: request.bundlePath,
            sessionId: sessionId,
            startTime: request.startTime
        ))

        let cliVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let minPaidAppVersion: String? = nil  // 추후 설정 연동
        return .success(PaidAppRegisterResponse(
            sessionId: sessionId,
            registeredAt: runtime.registeredAt,
            ok: true,
            cliVersion: cliVersion,
            minPaidAppVersion: minPaidAppVersion,
            compatible: true
        ))
    }

    func unregister(request: PaidAppUnregisterRequest) -> UnregisterResult {
        // 현재 상태 스냅샷 확인
        if case .notRunning = store.currentState() {
            return .notFound(reason: "등록된 paidApp 세션 없음")
        }

        // 단계 ③ startTime 보조 검증 (선택 사항, nil이면 기존 동작)
        let ok = store.unregister(
            pid: request.pid,
            sessionId: request.sessionId,
            startTime: request.startTime
        )
        if !ok {
            let reason = "paidapp/unregister 거부: 단계=3, pid=\(request.pid), sessionId 불일치 또는 startTime 관용도 초과"
            logW(reason)
            PaidAppStateLogger.shared.append(.rejected(
                stage: 3,
                pid: request.pid,
                claimedBundleId: Self.paidAppBundleId,
                actualBundleId: nil,
                reason: reason
            ))
            return .forbidden(reason: "sessionId 또는 pid 불일치, startTime 관용도 초과 (위조 의심)")
        }

        // 감사 로그: unregister 성공 이벤트
        PaidAppStateLogger.shared.append(.unregister(
            pid: request.pid,
            sessionId: request.sessionId,
            reason: "client"
        ))

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

    /// 단계 ② 기본 bundlePath 검증기 (프로덕션)
    static let defaultBundleIdAtPathResolver: BundleIdAtPathResolver = { url in
        return Bundle(url: url)?.bundleIdentifier
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
