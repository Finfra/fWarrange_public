import Foundation

/// Issue192 Phase A-2: paidApp ↔ cliApp 라이프사이클 REST 채널의 Codable 모델.
/// openapi_v2.yaml의 PaidAppRegisterRequest / PaidAppRegisterResponse /
/// PaidAppUnregisterRequest / PaidAppUnregisterResponse / PaidAppStatusResponse
/// 스키마와 1:1 대응.

struct PaidAppRegisterRequest: Codable, Equatable {
    let pid: Int32
    let version: String
    let bundlePath: String
    let startTime: String  // ISO8601 초 정밀도 (PID 재사용 cycle 대응 2중 검증 핵심)
}

struct PaidAppRegisterResponse: Codable, Equatable {
    let sessionId: String   // cliApp이 발급한 UUID
    let registeredAt: String
}

struct PaidAppUnregisterRequest: Codable, Equatable {
    let pid: Int32
    let sessionId: String
}

struct PaidAppUnregisterResponse: Codable, Equatable {
    let unregisteredAt: String
}

enum PaidAppLifecycleState: String, Codable, Equatable {
    case running
    case notRunning = "not_running"  // openapi_v2.yaml enum snake_case 유지
}

struct PaidAppStatusResponse: Codable, Equatable {
    let state: PaidAppLifecycleState
    let pid: Int32?
    let version: String?
    let bundlePath: String?
    let sessionId: String?
    let registeredAt: String?

    init(
        state: PaidAppLifecycleState,
        pid: Int32? = nil,
        version: String? = nil,
        bundlePath: String? = nil,
        sessionId: String? = nil,
        registeredAt: String? = nil
    ) {
        self.state = state
        self.pid = pid
        self.version = version
        self.bundlePath = bundlePath
        self.sessionId = sessionId
        self.registeredAt = registeredAt
    }
}
