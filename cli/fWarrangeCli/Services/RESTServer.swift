import Foundation
import Network
import AppKit

// MARK: - RESTServerProtocol

protocol RESTServerProtocol: AnyObject {
    var isRunning: Bool { get }
    var port: UInt16 { get set }
    var allowExternal: Bool { get set }
    var allowedCIDR: String { get set }
    func start(port: UInt16?)
    func stop()
}

// MARK: - RESTServerHandlers

/// RESTServer가 각 엔드포인트에서 필요로 하는 동작을 클로저로 주입받는 구조체.
/// WindowManager, LayoutManager 직접 의존성을 제거하여 역의존성 문제를 해결.
struct RESTServerHandlers {
    // WindowManager 관련
    var captureCurrentWindows: (_ filterApps: [String]?) -> [WindowInfo]
    var restoreWindows: (_ windows: [WindowInfo], _ maxRetries: Int, _ retryInterval: Double, _ minimumScore: Int, _ enableParallel: Bool) async -> [WindowMatchResult]
    var runningAppNames: () -> [String]
    var isAccessibilityGranted: () -> Bool

    // LayoutManager 관련
    var getLayouts: () -> [LayoutMetadata]
    var loadMetadataList: () -> Void
    var storageServiceLoad: (_ name: String) throws -> Layout
    var saveLayout: (_ name: String, _ windows: [WindowInfo]) throws -> Void
    var nextDailySequenceName: () -> String
    var renameLayout: (_ oldName: String, _ newName: String) throws -> Void
    var deleteLayout: (_ name: String) throws -> Void
    var deleteAllLayouts: () throws -> Void
    var removeWindows: (_ layoutName: String, _ windowIds: Set<Int>) throws -> Void

    // Settings 관련
    var getSettings: () -> [String: Any]
    var getDataDirectoryPath: () -> String
    var getSettingsBasePath: () -> String
    var getDefaultLayoutName: () -> String?
    var setDefaultLayoutName: (_ name: String?) -> Void
    var updateShortcuts: (_ body: [String: Any]) -> [String: String]
}

// MARK: - Notification.Name 확장 (fWarrangeCli용)

extension Notification.Name {
    static let restCaptureCompleted = Notification.Name("fWarrangeCli.RESTCaptureCompleted")
    static let restRestoreCompleted = Notification.Name("fWarrangeCli.RESTRestoreCompleted")
    static let restLayoutDeleted = Notification.Name("fWarrangeCli.RESTLayoutDeleted")
    static let restLayoutRenamed = Notification.Name("fWarrangeCli.RESTLayoutRenamed")
    static let fWarrangeCliShortcutsUpdated = Notification.Name("fWarrangeCli.ShortcutsUpdated")
}

// MARK: - RESTServer

@Observable
final class RESTServer: RESTServerProtocol {

    // MARK: - 공개 상태

    var isRunning = false
    var port: UInt16 = 3016
    var allowExternal: Bool = false
    var allowedCIDR: String = "192.168.0.0/16"

    // MARK: - 의존성

    private let handlers: RESTServerHandlers
    private var listener: NWListener?

    // MARK: - API 버전

    static let apiVersion = "v1"
    static let apiBasePath = "/api/v1"

    // MARK: - CLI 상태

    private let startedAt = Date()

    // MARK: - 초기화

    init(handlers: RESTServerHandlers) {
        self.handlers = handlers
    }

    // MARK: - 서버 시작/중지

    func start(port: UInt16? = nil) {
        if let port = port {
            self.port = port
        }

        do {
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: self.port) else {
                logE("[RESTServer] 유효하지 않은 포트: \(self.port)")
                return
            }
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            logE("[RESTServer] Listener 생성 실패: \(error)")
            return
        }

        // 바인딩 주소 (외부 허용 여부)
        if !allowExternal {
            // localhost 전용
            if let localPort = NWEndpoint.Port(rawValue: self.port) {
                listener?.parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host("127.0.0.1"),
                    port: localPort
                )
            }
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                logI("[RESTServer] 서버 시작 - 포트: \(self?.port ?? 0), 외부접근: \(self?.allowExternal == true)")
            case .failed(let error):
                logE("[RESTServer] 서버 실패: \(error)")
                self?.isRunning = false
            case .cancelled:
                self?.isRunning = false
                logI("[RESTServer] 서버 중지됨")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        logI("[RESTServer] 서버 중지 요청")
    }

    // MARK: - 연결 처리

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        receiveFullRequest(connection: connection, accumulated: Data()) { [weak self] data in
            guard let self = self, let data = data else {
                connection.cancel()
                return
            }

            guard let request = HTTPRequest.parse(from: data) else {
                let response = HTTPResponse.badRequest(message: "HTTP 파싱 실패")
                self.sendResponse(connection: connection, response: response)
                return
            }

            logV("[RESTServer] \(request.method) \(request.path) from \(connection.endpoint)")

            // CIDR 검사
            if self.allowExternal && !self.isAllowed(endpoint: connection.endpoint) {
                let response = HTTPResponse.forbidden(message: "접근 거부됨")
                self.sendResponse(connection: connection, response: response)
                return
            }

            self.routeRequest(request) { response in
                self.sendResponse(connection: connection, response: response)
            }
        }
    }

    /// HTTP 요청 전체 수신 (Content-Length 기반)
    private func receiveFullRequest(
        connection: NWConnection,
        accumulated: Data,
        completion: @escaping (Data?) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let error = error {
                logE("[RESTServer] 수신 에러: \(error)")
                completion(nil)
                return
            }

            var buffer = accumulated
            if let content = content {
                buffer.append(content)
            }

            // 헤더 완료 확인
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = Data(buffer[buffer.startIndex..<headerEnd.lowerBound])
                if let headerStr = String(data: headerData, encoding: .utf8) {
                    let contentLength = self?.parseContentLength(from: headerStr) ?? 0
                    let headerTotalLength = buffer.distance(from: buffer.startIndex, to: headerEnd.upperBound)
                    let bodyReceived = buffer.count - headerTotalLength

                    if bodyReceived >= contentLength || contentLength == 0 {
                        completion(buffer)
                        return
                    }
                }
            }

            if isComplete {
                completion(buffer.isEmpty ? nil : buffer)
                return
            }

            // 추가 데이터 수신
            self?.receiveFullRequest(connection: connection, accumulated: buffer, completion: completion)
        }
    }

    private func parseContentLength(from header: String) -> Int {
        for line in header.components(separatedBy: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private func sendResponse(connection: NWConnection, response: HTTPResponse) {
        let data = response.serialize()
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                logE("[RESTServer] 응답 전송 에러: \(error)")
            }
            connection.cancel()
        })
    }

    // MARK: - CIDR 보안

    private func isAllowed(endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        let ipString: String
        switch host {
        case .ipv4(let addr):
            ipString = "\(addr)"
        case .ipv6(let addr):
            ipString = "\(addr)"
        default:
            ipString = "\(host)"
        }

        // 로컬호스트 항상 허용
        if ipString == "127.0.0.1" || ipString == "::1" || ipString == "localhost" {
            return true
        }

        return matchesCIDR(ip: ipString, cidr: allowedCIDR)
    }

    private func matchesCIDR(ip: String, cidr: String) -> Bool {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let prefixLen = Int(parts[1]),
              prefixLen >= 0, prefixLen <= 32 else {
            return false
        }

        let cidrIP = String(parts[0])
        guard let ipNum = ipToUInt32(ip), let cidrNum = ipToUInt32(cidrIP) else {
            return false
        }

        let mask: UInt32 = prefixLen == 0 ? 0 : ~UInt32(0) << (32 - prefixLen)
        return (ipNum & mask) == (cidrNum & mask)
    }

    private func ipToUInt32(_ ip: String) -> UInt32? {
        let octets = ip.split(separator: ".").compactMap { UInt32($0) }
        guard octets.count == 4, octets.allSatisfy({ $0 <= 255 }) else { return nil }
        return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
    }

    // MARK: - 라우팅

    private func routeRequest(_ request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        let method = request.method
        let path = request.path
        let base = Self.apiBasePath

        // Health Check (GET / 또는 GET /api/v1/health)
        if method == "GET" && (path == "/" || path == "\(base)/health") {
            handleHealthCheck(completion: completion)
            return
        }

        // --- CLI 전용 엔드포인트 ---

        // GET /api/v1/cli/status
        if method == "GET" && path == "\(base)/cli/status" {
            handleCLIStatus(completion: completion)
            return
        }

        // GET /api/v1/cli/version
        if method == "GET" && path == "\(base)/cli/version" {
            handleCLIVersion(completion: completion)
            return
        }

        // POST /api/v1/cli/quit
        if method == "POST" && path == "\(base)/cli/quit" {
            handleCLIQuit(request: request, completion: completion)
            return
        }

        // --- 기존 엔드포인트 ---

        // GET /api/v1/settings
        if method == "GET" && path == "\(base)/settings" {
            handleGetSettings(completion: completion)
            return
        }

        // GET /api/v1/settings/default-layout
        if method == "GET" && path == "\(base)/settings/default-layout" {
            handleGetDefaultLayout(completion: completion)
            return
        }

        // PUT /api/v1/settings/default-layout
        if method == "PUT" && path == "\(base)/settings/default-layout" {
            handleSetDefaultLayout(request: request, completion: completion)
            return
        }

        // PUT /api/v1/settings/shortcuts
        if method == "PUT" && path == "\(base)/settings/shortcuts" {
            handleSetShortcuts(request: request, completion: completion)
            return
        }

        // GET /api/v1/layouts
        if method == "GET" && path == "\(base)/layouts" {
            handleGetLayouts(completion: completion)
            return
        }

        // DELETE /api/v1/layouts (전체삭제)
        if method == "DELETE" && path == "\(base)/layouts" {
            handleDeleteAllLayouts(request: request, completion: completion)
            return
        }

        // GET /api/v1/windows/current
        if method == "GET" && path.hasPrefix("\(base)/windows/current") {
            handleGetCurrentWindows(request: request, completion: completion)
            return
        }

        // GET /api/v1/windows/apps
        if method == "GET" && path == "\(base)/windows/apps" {
            handleGetApps(completion: completion)
            return
        }

        // GET /api/v1/status/accessibility
        if method == "GET" && path == "\(base)/status/accessibility" {
            handleGetAccessibility(completion: completion)
            return
        }

        // PUT /api/v1/ui/state
        if method == "PUT" && path == "\(base)/ui/state" {
            handleSetUIState(request: request, completion: completion)
            return
        }

        // POST /api/v1/capture
        if method == "POST" && path == "\(base)/capture" {
            handleCapture(request: request, completion: completion)
            return
        }

        // /api/v1/layouts/{name}/... 패턴 처리
        let layoutsPrefix = "\(base)/layouts/"
        if path.hasPrefix(layoutsPrefix) {
            let remaining = String(path.dropFirst(layoutsPrefix.count))
            let parts = remaining.split(separator: "/", maxSplits: 2).map { String($0) }

            guard let layoutName = parts.first?.removingPercentEncoding, !layoutName.isEmpty else {
                completion(.badRequest(message: "레이아웃 이름이 필요합니다"))
                return
            }

            if parts.count == 1 {
                // GET/PUT/DELETE /api/v1/layouts/{name}
                switch method {
                case "GET":
                    handleGetLayout(name: layoutName, completion: completion)
                case "PUT":
                    handleRenameLayout(name: layoutName, request: request, completion: completion)
                case "DELETE":
                    handleDeleteLayout(name: layoutName, completion: completion)
                default:
                    completion(.methodNotAllowed())
                }
                return
            }

            if parts.count >= 2 {
                let subPath = parts[1...].joined(separator: "/")

                // POST /api/v1/layouts/{name}/restore
                if method == "POST" && subPath == "restore" {
                    handleRestore(name: layoutName, request: request, completion: completion)
                    return
                }

                // POST /api/v1/layouts/{name}/windows/remove
                if method == "POST" && subPath == "windows/remove" {
                    handleRemoveWindows(name: layoutName, request: request, completion: completion)
                    return
                }
            }
        }

        completion(.notFound(message: "엔드포인트를 찾을 수 없습니다: \(method) \(path)"))
    }

    // MARK: - CLI 전용 핸들러

    /// GET /api/v1/cli/status - 서버 상태 (uptime, 버전, 포트)
    private func handleCLIStatus(completion: @escaping (HTTPResponse) -> Void) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let uptime = Date().timeIntervalSince(startedAt)
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60
        let uptimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        let body: [String: Any] = [
            "status": "ok",
            "app": "fWarrangeCli",
            "version": version,
            "port": Int(port),
            "uptime": uptimeString,
            "uptimeSeconds": Int(uptime),
            "isRunning": isRunning
        ]
        completion(.ok(json: body))
    }

    /// GET /api/v1/cli/version - 버전 정보
    private func handleCLIVersion(completion: @escaping (HTTPResponse) -> Void) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let body: [String: Any] = [
            "status": "ok",
            "data": [
                "app": "fWarrangeCli",
                "version": version,
                "build": build
            ] as [String: Any]
        ]
        completion(.ok(json: body))
    }

    /// POST /api/v1/cli/quit - 앱 종료 (X-Confirm 헤더 필수)
    private func handleCLIQuit(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard request.header("X-Confirm") == "true" else {
            completion(.badRequest(message: "X-Confirm: true 헤더가 필요합니다"))
            return
        }

        logI("[RESTServer] CLI quit 요청 수신 - 종료합니다")
        completion(.ok(json: ["status": "ok", "message": "fWarrangeCli 종료됨"]))

        // 응답 전송 후 잠시 대기 후 종료
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - 핸들러

    /// GET / 또는 GET /api/v1/health - Health Check
    private func handleHealthCheck(completion: @escaping (HTTPResponse) -> Void) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let uptime = Int(Date().timeIntervalSince(startedAt))
        let layoutCount = handlers.getLayouts().count
        let body: [String: Any] = [
            "status": "ok",
            "app": "fWarrangeCli",
            "version": version,
            "port": Int(port),
            "layout_count": layoutCount,
            "uptime_seconds": uptime
        ]
        completion(.ok(json: body))
    }

    /// GET /api/v1/layouts - 레이아웃 목록
    private func handleGetLayouts(completion: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.handlers.loadMetadataList()
            let list = self.handlers.getLayouts().map { meta -> [String: Any] in
                [
                    "name": meta.name,
                    "windowCount": meta.windowCount,
                    "fileDate": ISO8601Formatter.string(from: meta.fileDate)
                ]
            }
            completion(.ok(json: ["status": "ok", "data": list]))
        }
    }

    /// GET /api/v1/layouts/{name} - 레이아웃 상세
    private func handleGetLayout(name: String, completion: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            do {
                let layout = try self.handlers.storageServiceLoad(name)
                let windowsJSON = layout.windows.map { self.windowInfoToDict($0) }
                let data: [String: Any] = [
                    "name": layout.name,
                    "windowCount": layout.windowCount,
                    "fileDate": ISO8601Formatter.string(from: layout.fileDate),
                    "windows": windowsJSON
                ]
                completion(.ok(json: ["status": "ok", "data": data]))
            } catch {
                completion(.notFound(message: "레이아웃을 찾을 수 없습니다: '\(name)'"))
            }
        }
    }

    /// POST /api/v1/capture - 창 캡처 및 저장
    private func handleCapture(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        let json = request.jsonBody()
        let rawName = (json?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (rawName?.isEmpty ?? true) ? handlers.nextDailySequenceName() : rawName!
        let filterApps = json?["filterApps"] as? [String]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let windows = self.handlers.captureCurrentWindows(filterApps)

            do {
                try self.handlers.saveLayout(name, windows)
                NotificationCenter.default.post(name: .restCaptureCompleted, object: nil)
                let data: [String: Any] = [
                    "name": name,
                    "windowCount": windows.count,
                    "windows": windows.map { self.windowInfoToDict($0) }
                ]
                completion(.ok(json: ["status": "ok", "data": data]))
            } catch {
                completion(.internalError(message: "레이아웃 저장에 실패했습니다: '\(name)'"))
            }
        }
    }

    /// POST /api/v1/layouts/{name}/restore - 레이아웃 복구
    private func handleRestore(name: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        let json = request.jsonBody()
        let maxRetries = json?["maxRetries"] as? Int ?? 5
        let retryInterval = json?["retryInterval"] as? Double ?? 0.5
        let minimumScore = json?["minimumScore"] as? Int ?? 30
        let enableParallel = json?["enableParallel"] as? Bool ?? true

        Task { @MainActor [weak self] in
            guard let self else {
                completion(.internalError(message: "서버가 해제되었습니다"))
                return
            }
            do {
                // 접근성 권한 확인
                guard self.handlers.isAccessibilityGranted() else {
                    completion(.forbidden(message: "Accessibility 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 fWarrangeCli를 추가하세요."))
                    return
                }

                let layout = try self.handlers.storageServiceLoad(name)

                logI("[REST] restore 시작 - 레이아웃: '\(name)', 창 수: \(layout.windows.count)")

                let results = await self.handlers.restoreWindows(
                    layout.windows,
                    maxRetries,
                    retryInterval,
                    minimumScore,
                    enableParallel
                )

                NotificationCenter.default.post(name: .restRestoreCompleted, object: nil)

                let succeeded = results.filter { $0.success }.count
                let total = results.count

                logI("[REST] restore 완료 - 성공: \(succeeded)/\(total)")

                let data: [String: Any] = [
                    "total": total,
                    "succeeded": succeeded,
                    "failed": total - succeeded,
                    "results": results.map { result -> [String: Any] in
                        [
                            "app": result.targetWindow.app,
                            "window": result.targetWindow.window,
                            "matchedTitle": result.matchedTitle,
                            "matchType": "\(result.matchType)",
                            "score": result.score,
                            "success": result.success
                        ]
                    }
                ]

                completion(.ok(json: ["status": "ok", "data": data]))
            } catch {
                completion(.notFound(message: "레이아웃을 찾을 수 없습니다: \(name)"))
            }
        }
    }

    /// PUT /api/v1/layouts/{name} - 이름 변경
    private func handleRenameLayout(name: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let json = request.jsonBody(), let newName = json["newName"] as? String, !newName.isEmpty else {
            completion(.badRequest(message: "newName 필드가 필요합니다"))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.handlers.renameLayout(name, newName)
                NotificationCenter.default.post(name: .restLayoutRenamed, object: nil)
                completion(.ok(json: [
                    "status": "ok",
                    "data": ["oldName": name, "newName": newName]
                ]))
            } catch {
                completion(.notFound(message: "레이아웃 이름 변경 실패: '\(name)'을 찾을 수 없습니다"))
            }
        }
    }

    /// DELETE /api/v1/layouts/{name} - 레이아웃 삭제
    private func handleDeleteLayout(name: String, completion: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 존재 여부 사전 확인
            let exists = self.handlers.getLayouts().contains { $0.name == name }
            guard exists else {
                completion(.notFound(message: "레이아웃을 찾을 수 없습니다: '\(name)'"))
                return
            }

            do {
                try self.handlers.deleteLayout(name)
                NotificationCenter.default.post(name: .restLayoutDeleted, object: nil)
                completion(.ok(json: ["status": "ok", "data": ["deleted": name]]))
            } catch {
                completion(.internalError(message: "레이아웃 '\(name)' 삭제 중 오류가 발생했습니다"))
            }
        }
    }

    /// DELETE /api/v1/layouts - 전체 삭제
    private func handleDeleteAllLayouts(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard request.header("X-Confirm-Delete-All") == "true" else {
            completion(.badRequest(message: "X-Confirm-Delete-All: true 헤더가 필요합니다"))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            do {
                let count = self.handlers.getLayouts().count
                try self.handlers.deleteAllLayouts()
                NotificationCenter.default.post(name: .restLayoutDeleted, object: nil)
                completion(.ok(json: ["status": "ok", "data": ["deletedCount": count]]))
            } catch {
                completion(.internalError(message: "레이아웃 전체 삭제에 실패했습니다"))
            }
        }
    }

    /// POST /api/v1/layouts/{name}/windows/remove - 창 제거
    private func handleRemoveWindows(name: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let json = request.jsonBody(),
              let windowIds = json["windowIds"] as? [Int], !windowIds.isEmpty else {
            completion(.badRequest(message: "windowIds 배열이 필요합니다"))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            do {
                let beforeCount = (try? self.handlers.storageServiceLoad(name))?.windowCount ?? 0
                try self.handlers.removeWindows(name, Set(windowIds))
                let afterCount = (try? self.handlers.storageServiceLoad(name))?.windowCount ?? 0
                completion(.ok(json: [
                    "status": "ok",
                    "data": [
                        "layout": name,
                        "removedCount": beforeCount - afterCount,
                        "remainingCount": afterCount
                    ] as [String: Any]
                ]))
            } catch {
                completion(.internalError(message: "레이아웃 '\(name)'에서 창 제거에 실패했습니다"))
            }
        }
    }

    /// GET /api/v1/windows/current - 현재 창 목록 (저장 없이)
    private func handleGetCurrentWindows(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        // query parameter 파싱: ?filterApps=Safari,iTerm2
        var filterApps: [String]? = nil
        if let queryString = request.queryString,
           let filterValue = parseQueryParam(queryString, key: "filterApps") {
            filterApps = filterValue.split(separator: ",").map { String($0) }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let windows = self.handlers.captureCurrentWindows(filterApps)
            let data: [String: Any] = [
                "windowCount": windows.count,
                "windows": windows.map { self.windowInfoToDict($0) }
            ]
            completion(.ok(json: ["status": "ok", "data": data]))
        }
    }

    /// GET /api/v1/windows/apps - 실행 중 앱 목록
    private func handleGetApps(completion: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let apps = self.handlers.runningAppNames()
            completion(.ok(json: ["status": "ok", "data": ["apps": apps]]))
        }
    }

    /// GET /api/v1/status/accessibility - 접근성 권한 상태
    private func handleGetAccessibility(completion: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let granted = self.handlers.isAccessibilityGranted()
            completion(.ok(json: ["status": "ok", "data": ["granted": granted]]))
        }
    }

    // MARK: - Settings

    /// GET /api/v1/settings - 현재 설정값 조회
    private func handleGetSettings(completion: @escaping (HTTPResponse) -> Void) {
        var data = handlers.getSettings()
        data["settingsBasePath"] = handlers.getSettingsBasePath()
        data["dataDirectoryPath"] = handlers.getDataDirectoryPath()
        completion(.ok(json: ["status": "ok", "data": data]))
    }

    // MARK: - 기본 레이아웃

    /// GET /api/v1/settings/default-layout - 기본 레이아웃 이름 조회
    private func handleGetDefaultLayout(completion: @escaping (HTTPResponse) -> Void) {
        let name = handlers.getDefaultLayoutName() ?? "default"
        completion(.ok(json: ["status": "ok", "data": ["defaultLayoutName": name]]))
    }

    /// PUT /api/v1/settings/default-layout - 기본 레이아웃 이름 설정
    private func handleSetDefaultLayout(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let json = request.jsonBody(), let name = json["name"] as? String, !name.isEmpty else {
            completion(.badRequest(message: "name 필드가 필요합니다"))
            return
        }
        handlers.setDefaultLayoutName(name)
        completion(.ok(json: ["status": "ok", "data": ["defaultLayoutName": name]]))
    }

    /// PUT /api/v1/settings/shortcuts - 단축키 일괄 업데이트 및 HotKeyService 재등록
    private func handleSetShortcuts(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let json = request.jsonBody() else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        let applied = handlers.updateShortcuts(json)
        completion(.ok(json: ["status": "ok", "data": applied]))
    }

    // MARK: - UI 상태

    /// PUT /api/v1/ui/state - UI 상태 변경 (캡처 자동화용)
    private func handleSetUIState(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let body = request.jsonBody() else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        // body를 그대로 echo하여 적용된 상태 반환
        completion(.ok(json: ["status": "ok", "data": body]))
    }

    // MARK: - 유틸리티

    private func windowInfoToDict(_ w: WindowInfo) -> [String: Any] {
        [
            "id": w.id,
            "app": w.app,
            "window": w.window,
            "layer": w.layer,
            "pos": ["x": w.pos.x, "y": w.pos.y],
            "size": ["width": w.size.width, "height": w.size.height]
        ]
    }

    private func parseQueryParam(_ query: String, key: String) -> String? {
        let pairs = query.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, String(kv[0]) == key {
                return String(kv[1]).removingPercentEncoding
            }
        }
        return nil
    }
}

// MARK: - ISO8601 날짜 포매터

private let ISO8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

// MARK: - HTTP 요청 파서

private struct HTTPRequest {
    let method: String
    let path: String
    let queryString: String?
    let headers: [String: String]
    let body: Data?

    /// Raw HTTP 데이터에서 요청 파싱
    static func parse(from data: Data) -> HTTPRequest? {
        guard let headerEndRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            // 헤더만 있는 경우 (body 없음)
            return parseHeaderOnly(from: data)
        }

        let headerData = data[data.startIndex..<headerEndRange.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let bodyData = data[headerEndRange.upperBound...]
        return parseFromParts(headerString: headerString, body: bodyData.isEmpty ? nil : Data(bodyData))
    }

    private static func parseHeaderOnly(from data: Data) -> HTTPRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        return parseFromParts(headerString: str, body: nil)
    }

    private static func parseFromParts(headerString: String, body: Data?) -> HTTPRequest? {
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count >= 2 else { return nil }

        let method = String(requestParts[0])
        let fullPath = String(requestParts[1])

        // path와 query 분리
        var path: String
        var queryString: String?
        if let qIndex = fullPath.firstIndex(of: "?") {
            path = String(fullPath[fullPath.startIndex..<qIndex])
            queryString = String(fullPath[fullPath.index(after: qIndex)...])
        } else {
            path = fullPath
            queryString = nil
        }

        // URL 디코딩
        path = path.removingPercentEncoding ?? path

        // 헤더 파싱
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return HTTPRequest(
            method: method,
            path: path,
            queryString: queryString,
            headers: headers,
            body: body
        )
    }

    /// JSON body 파싱
    func jsonBody() -> [String: Any]? {
        guard let body = body, !body.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    /// 헤더 값 조회 (대소문자 무시)
    func header(_ name: String) -> String? {
        let lowerName = name.lowercased()
        for (key, value) in headers {
            if key.lowercased() == lowerName {
                return value
            }
        }
        return nil
    }
}

// MARK: - HTTP 응답 빌더

private struct HTTPResponse {
    let statusCode: Int
    let statusMessage: String
    let headers: [String: String]
    let body: Data?

    /// HTTP 응답 바이트열 직렬화
    func serialize() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n"
        response += "Content-Type: application/json; charset=utf-8\r\n"
        response += "Connection: close\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"

        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }

        let bodyData = body ?? Data()
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "\r\n"

        var data = Data(response.utf8)
        data.append(bodyData)
        return data
    }

    // MARK: - 편의 팩토리

    static func ok(json: Any) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        return HTTPResponse(statusCode: 200, statusMessage: "OK", headers: [:], body: body)
    }

    static func badRequest(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 400, statusMessage: "Bad Request", headers: [:], body: body)
    }

    static func forbidden(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 403, statusMessage: "Forbidden", headers: [:], body: body)
    }

    static func notFound(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 404, statusMessage: "Not Found", headers: [:], body: body)
    }

    static func methodNotAllowed() -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": "허용되지 않는 HTTP 메서드입니다"], options: .sortedKeys)
        return HTTPResponse(statusCode: 405, statusMessage: "Method Not Allowed", headers: [:], body: body)
    }

    static func internalError(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 500, statusMessage: "Internal Server Error", headers: [:], body: body)
    }
}
