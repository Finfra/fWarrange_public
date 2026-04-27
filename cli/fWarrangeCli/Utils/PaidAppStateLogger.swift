import Foundation

/// Issue214_3: paidApp 상태 전이 및 발신자 검증 거부 사례 영속 감사 로깅.
///
/// SSOT: `_doc_design/paid_cli_protocol.md` §3.5
///
/// - 싱글턴 + 직렬 DispatchQueue (thread-safe)
/// - JSONL append-only 파일 (한 줄당 한 이벤트)
/// - 5 MB 회전 정책 (`.1` ~ `.5` 슬롯, 최대 5개 보관)
/// - 타임스탬프: ISO8601 ms 정밀도
/// - IO 실패는 logE 후 swallow (본 흐름 영향 금지)
///
/// 호출 진입점:
/// - `PaidAppRouter.register/unregister` 성공/실패 분기
/// - `PaidAppStateStore.register` 내부 stale 처리
/// - `AppState.observePaidAppTermination` → `unregisterAllForBundleId` cleanup
final class PaidAppStateLogger {
    static let shared = PaidAppStateLogger()

    enum Event {
        case register(
            pid: Int32,
            bundleId: String,
            version: String,
            bundlePath: String,
            sessionId: String,
            startTime: String
        )
        case unregister(pid: Int32, sessionId: String, reason: String)
        case cleanup(bundleId: String, pid: Int32?, reason: String)
        case rejected(
            stage: Int,
            pid: Int32,
            claimedBundleId: String?,
            actualBundleId: String?,
            reason: String
        )
        case replaced(oldSessionId: String, newSessionId: String, oldPid: Int32, newPid: Int32)
    }

    private let queue = DispatchQueue(label: "kr.finfra.fWarrangeCli.PaidAppStateLogger")
    private let fileURL: URL
    private let maxBytes: Int = 5 * 1024 * 1024   // 5 MB
    private let maxSlots: Int = 5

    // MARK: - Initialization

    init(fileURL: URL? = nil) {
        if let customURL = fileURL {
            self.fileURL = customURL
        } else {
            // 기본값: ~/Documents/finfra/fWarrangeData/logs/paidapp_state_transitions.log
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let appRootPath = Env.configPath
                ?? documentsURL.appendingPathComponent("finfra/fWarrangeData").path
            let logDir = URL(fileURLWithPath: appRootPath).appendingPathComponent("logs")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
            self.fileURL = logDir.appendingPathComponent("paidapp_state_transitions.log")
        }
    }

    // MARK: - Public Interface

    func append(_ event: Event) {
        queue.async { [weak self] in
            self?.appendSync(event)
        }
    }

    // MARK: - Private Implementation

    private func appendSync(_ event: Event) {
        // 회전 정책 체크
        rotateIfNeeded()

        // 이벤트 직렬화
        guard let jsonData = encodeEvent(event) else {
            logE("paidAppStateLogger: 이벤트 인코딩 실패")
            return
        }

        // 파일에 append (newline 포함)
        do {
            // 파일이 없으면 생성, 있으면 append
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }

            handle.seekToEndOfFile()
            handle.write(jsonData)
            handle.write("\n".data(using: .utf8) ?? Data())
        } catch {
            logE("paidAppStateLogger: 파일 쓰기 실패 - \(error.localizedDescription)")
            // swallow: 감사 로그 실패가 본 흐름을 막지 않음
        }
    }

    private func rotateIfNeeded() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attrs[.size] as? Int, fileSize >= maxBytes else {
                return  // 회전 필요 없음
            }
        } catch {
            // 파일 없음 또는 접근 오류 — 회전 스킵
            return
        }

        // 회전 수행
        performRotation()
    }

    private func performRotation() {
        do {
            let fm = FileManager.default

            // `.5` 존재 시 삭제
            let slot5 = URL(fileURLWithPath: fileURL.path + ".5")
            if fm.fileExists(atPath: slot5.path) {
                try fm.removeItem(at: slot5)
            }

            // 시프트: `.4→.5`, `.3→.4`, ..., `.1→.2`
            for i in stride(from: 4, through: 1, by: -1) {
                let oldURL = URL(fileURLWithPath: fileURL.path + ".\(i)")
                let newURL = URL(fileURLWithPath: fileURL.path + ".\(i + 1)")
                if fm.fileExists(atPath: oldURL.path) {
                    try? fm.removeItem(at: newURL)
                    try fm.moveItem(at: oldURL, to: newURL)
                }
            }

            // 현재 파일 → `.1`
            if fm.fileExists(atPath: fileURL.path) {
                let slot1 = URL(fileURLWithPath: fileURL.path + ".1")
                try? fm.removeItem(at: slot1)
                try fm.moveItem(at: fileURL, to: slot1)
            }

            // 새 파일 생성
            fm.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        } catch {
            logE("paidAppStateLogger: 회전 실패 - \(error.localizedDescription)")
            // swallow: 회전 실패가 append를 막지 않음
        }
    }

    private func encodeEvent(_ event: Event) -> Data? {
        let ts = iso8601NowMs()  // ms 정밀도

        struct Payload: Encodable {
            let ts: String
            let event: String
            // 이벤트별 필드: flat 저장 (jq 친화)
            let pid: Int32?
            let bundleId: String?
            let version: String?
            let bundlePath: String?
            let sessionId: String?
            let startTime: String?
            let reason: String?
            let stage: Int?
            let claimedBundleId: String?
            let actualBundleId: String?
            let oldSessionId: String?
            let newSessionId: String?
            let oldPid: Int32?
            let newPid: Int32?

            enum CodingKeys: String, CodingKey {
                case ts, event, pid, bundleId, version, bundlePath, sessionId, startTime
                case reason, stage, claimedBundleId, actualBundleId
                case oldSessionId, newSessionId, oldPid, newPid
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(ts, forKey: .ts)
                try container.encode(event, forKey: .event)
                if let v = pid { try container.encode(v, forKey: .pid) }
                if let v = bundleId { try container.encode(v, forKey: .bundleId) }
                if let v = version { try container.encode(v, forKey: .version) }
                if let v = bundlePath { try container.encode(v, forKey: .bundlePath) }
                if let v = sessionId { try container.encode(v, forKey: .sessionId) }
                if let v = startTime { try container.encode(v, forKey: .startTime) }
                if let v = reason { try container.encode(v, forKey: .reason) }
                if let v = stage { try container.encode(v, forKey: .stage) }
                if let v = claimedBundleId { try container.encode(v, forKey: .claimedBundleId) }
                if let v = actualBundleId { try container.encode(v, forKey: .actualBundleId) }
                if let v = oldSessionId { try container.encode(v, forKey: .oldSessionId) }
                if let v = newSessionId { try container.encode(v, forKey: .newSessionId) }
                if let v = oldPid { try container.encode(v, forKey: .oldPid) }
                if let v = newPid { try container.encode(v, forKey: .newPid) }
            }
        }

        let payload: Payload
        switch event {
        case let .register(pid, bundleId, version, bundlePath, sessionId, startTime):
            payload = Payload(
                ts: ts, event: "register", pid: pid, bundleId: bundleId, version: version,
                bundlePath: bundlePath, sessionId: sessionId, startTime: startTime,
                reason: nil, stage: nil, claimedBundleId: nil, actualBundleId: nil,
                oldSessionId: nil, newSessionId: nil, oldPid: nil, newPid: nil
            )
        case let .unregister(pid, sessionId, reason):
            payload = Payload(
                ts: ts, event: "unregister", pid: pid, bundleId: nil, version: nil,
                bundlePath: nil, sessionId: sessionId, startTime: nil,
                reason: reason, stage: nil, claimedBundleId: nil, actualBundleId: nil,
                oldSessionId: nil, newSessionId: nil, oldPid: nil, newPid: nil
            )
        case let .cleanup(bundleId, pid, reason):
            payload = Payload(
                ts: ts, event: "cleanup", pid: pid, bundleId: bundleId, version: nil,
                bundlePath: nil, sessionId: nil, startTime: nil,
                reason: reason, stage: nil, claimedBundleId: nil, actualBundleId: nil,
                oldSessionId: nil, newSessionId: nil, oldPid: nil, newPid: nil
            )
        case let .rejected(stage, pid, claimedBundleId, actualBundleId, reason):
            payload = Payload(
                ts: ts, event: "rejected", pid: pid, bundleId: nil, version: nil,
                bundlePath: nil, sessionId: nil, startTime: nil,
                reason: reason, stage: stage, claimedBundleId: claimedBundleId, actualBundleId: actualBundleId,
                oldSessionId: nil, newSessionId: nil, oldPid: nil, newPid: nil
            )
        case let .replaced(oldSessionId, newSessionId, oldPid, newPid):
            payload = Payload(
                ts: ts, event: "replaced", pid: nil, bundleId: nil, version: nil,
                bundlePath: nil, sessionId: nil, startTime: nil,
                reason: nil, stage: nil, claimedBundleId: nil, actualBundleId: nil,
                oldSessionId: oldSessionId, newSessionId: newSessionId, oldPid: oldPid, newPid: newPid
            )
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []  // compact 형식
            let jsonData = try encoder.encode(payload)
            return jsonData
        } catch {
            logE("paidAppStateLogger: JSON 인코딩 실패 - \(error.localizedDescription)")
            return nil
        }
    }

    private static let iso8601MsFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func iso8601NowMs() -> String {
        return Self.iso8601MsFormatter.string(from: Date())
    }
}
