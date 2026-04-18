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

    // v2 settings
    var getFullSettings: () -> [String: Any]
    var patchSettings: (_ body: [String: Any]) -> [String: Any]
    var getExcludedApps: () -> [String]
    var setExcludedApps: (_ apps: [String]) -> [String]
    var addExcludedApps: (_ apps: [String]) -> [String]
    var removeExcludedApps: (_ apps: [String]) -> [String]
    var resetExcludedApps: () -> [String]
    var factoryResetSettings: () -> [String: Any]
    var getShortcutsDisplay: () -> [String: String]
    var getLogFilePath: () -> String
    /// Called when API-tab settings change (port/external/CIDR).
    /// Returns the effective state after the server applies the change.
    var applyApiSettings: (_ enabled: Bool?, _ port: Int?, _ external: Bool?, _ cidr: String?) -> (isRunning: Bool, port: Int, external: Bool, cidr: String)

    // UI 상태
    var setHideMenuBar: (_ hide: Bool) -> Void
    var getHideMenuBar: () -> Bool

    // Mode 관련
    var listModes: () throws -> [ModeMetadata]
    var loadMode: (_ name: String) throws -> Mode
    var createMode: (_ name: String, _ icon: String, _ shortcut: String?, _ layoutRef: String) throws -> Mode
    var updateMode: (_ name: String, _ body: [String: Any]) throws -> Mode
    var deleteMode: (_ name: String) throws -> Void
    var activateMode: (_ name: String) async throws -> (mode: Mode, restoreResults: [WindowMatchResult])
    var getActiveModeName: () -> String?
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
    static let apiV2BasePath = "/api/v2"

    // MARK: - CLI 상태

    private let startedAt = Date()

    // MARK: - PaidApp 라이프사이클 (Issue192 Phase A)

    /// paidApp 라이프사이클 상태 저장소. register/unregister/status 엔드포인트 백엔드.
    let paidAppStore: PaidAppStateStore

    /// paidApp 라우터. HTTP 파싱은 RESTServer, 비즈니스 로직은 Router가 담당.
    private let paidAppRouter: PaidAppRouter

    // MARK: - 초기화

    init(
        handlers: RESTServerHandlers,
        paidAppStore: PaidAppStateStore = PaidAppStateStore(),
        paidAppSenderResolver: @escaping PaidAppRouter.SenderBundleIdResolver = PaidAppRouter.defaultSenderResolver
    ) {
        self.handlers = handlers
        self.paidAppStore = paidAppStore
        self.paidAppRouter = PaidAppRouter(
            store: paidAppStore,
            senderBundleIdResolver: paidAppSenderResolver
        )
    }

    // MARK: - 서버 시작/중지

    func start(port: UInt16? = nil) {
        if let port = port {
            self.port = port
        }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
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

            if request.path == "/api/v1/cli/status" || request.path == "/" {
                logV("[RESTServer] \(request.method) \(request.path) from \(connection.endpoint)")
            } else {
                logD("[RESTServer] \(request.method) \(request.path) from \(connection.endpoint)")
            }

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

        // Health Check (GET / 또는 GET /api/v1/health, /api/v2/health)
        if method == "GET" && (path == "/" || path == "\(base)/health" || path == "\(Self.apiV2BasePath)/health") {
            handleHealthCheck(completion: completion)
            return
        }

        // v2 라우팅: /api/v2/* (v1 엔드포인트는 경로 치환하여 그대로 재사용)
        if path.hasPrefix("\(Self.apiV2BasePath)/") {
            if routeV2(method: method, path: path, request: request, completion: completion) {
                return
            }
            // v2 전용이 아닌 엔드포인트는 v1 라우터로 폴백
            let rewritten = "\(base)" + String(path.dropFirst(Self.apiV2BasePath.count))
            let rewrittenRequest = request.withPath(rewritten)
            routeRequest(rewrittenRequest, completion: completion)
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

    // MARK: - v2 라우팅

    /// v2 전용 설정 엔드포인트 라우팅. 처리 여부를 반환.
    private func routeV2(method: String, path: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) -> Bool {
        let base = Self.apiV2BasePath

        // 변경 시퀀스 조회
        if method == "GET" && path == "\(base)/changes" {
            let since = request.queryString.flatMap { parseQueryParam($0, key: "since") }.flatMap { Int($0) }
            let result = ChangeTracker.shared.changes(since: since)
            completion(.ok(json: ["currentSeq": result.currentSeq, "changes": result.changes]))
            return true
        }

        // 전체 설정
        if path == "\(base)/settings" {
            if method == "GET" {
                completion(.ok(json: ["status": "ok", "data": handlers.getFullSettings()]))
                return true
            }
            if method == "PATCH" {
                let body = request.jsonBody() ?? [:]
                let updated = handlers.patchSettings(body)
                ChangeTracker.shared.record(type: "settings.changed", target: "all")
                completion(.ok(json: ["status": "ok", "data": updated]))
                return true
            }
        }

        // 탭별 설정: General / Restore / API / Advanced 는 동일 PATCH 경로로 처리
        let tabPaths: [String: [String]] = [
            "\(base)/settings/general": ["appLanguage", "dataStorageMode", "dataDirectoryPath", "launchAtLogin", "theme"],
            "\(base)/settings/restore": ["maxRetries", "retryInterval", "minimumMatchScore", "enableParallelRestore"],
            "\(base)/settings/advanced": ["logLevel", "autoSaveOnSleep", "maxAutoSaves", "restoreButtonStyle", "confirmBeforeDelete", "showInCmdTab", "clickSwitchToMain"]
        ]
        if let fields = tabPaths[path] {
            if method == "GET" {
                let full = handlers.getFullSettings()
                var data: [String: Any] = [:]
                for k in fields { if let v = full[k] { data[k] = v } }
                if path.hasSuffix("/restore") { data["excludedApps"] = handlers.getExcludedApps() }
                if path.hasSuffix("/advanced") { data["logFilePath"] = handlers.getLogFilePath() }
                completion(.ok(json: ["status": "ok", "data": data]))
                return true
            }
            if method == "PATCH" {
                guard let body = request.jsonBody() else {
                    completion(.badRequest(message: "JSON body가 필요합니다"))
                    return true
                }
                // 허용된 필드만 통과
                var filtered: [String: Any] = [:]
                for k in fields { if let v = body[k] { filtered[k] = v } }
                _ = handlers.patchSettings(filtered)
                // 탭 이름 추출 (ex: /settings/general → general)
                let section = path.split(separator: "/").last.map(String.init) ?? "unknown"
                ChangeTracker.shared.record(type: "settings.changed", target: section)
                let full = handlers.getFullSettings()
                var data: [String: Any] = [:]
                for k in fields { if let v = full[k] { data[k] = v } }
                if path.hasSuffix("/restore") { data["excludedApps"] = handlers.getExcludedApps() }
                if path.hasSuffix("/advanced") { data["logFilePath"] = handlers.getLogFilePath() }
                completion(.ok(json: ["status": "ok", "data": data]))
                return true
            }
        }

        // API 탭: 서버 재시작 트리거
        if path == "\(base)/settings/api" {
            if method == "GET" {
                let full = handlers.getFullSettings()
                let data: [String: Any] = [
                    "restServerEnabled": full["restServerEnabled"] ?? true,
                    "restServerPort": full["restServerPort"] ?? Int(port),
                    "allowExternalAccess": full["allowExternalAccess"] ?? allowExternal,
                    "allowedCIDR": full["allowedCIDR"] ?? allowedCIDR,
                    "isRunning": isRunning,
                    "effectivePort": Int(port)
                ]
                completion(.ok(json: ["status": "ok", "data": data]))
                return true
            }
            if method == "PATCH" {
                guard let body = request.jsonBody() else {
                    completion(.badRequest(message: "JSON body가 필요합니다"))
                    return true
                }
                let enabled = body["restServerEnabled"] as? Bool
                let newPort = body["restServerPort"] as? Int
                let external = body["allowExternalAccess"] as? Bool
                let cidr = body["allowedCIDR"] as? String
                if let p = newPort, p < 1 || p > 65535 {
                    completion(.badRequest(message: "포트 범위가 올바르지 않습니다"))
                    return true
                }
                let applied = handlers.applyApiSettings(enabled, newPort, external, cidr)
                ChangeTracker.shared.record(type: "settings.changed", target: "api")
                let data: [String: Any] = [
                    "restServerEnabled": enabled ?? true,
                    "restServerPort": applied.port,
                    "allowExternalAccess": applied.external,
                    "allowedCIDR": applied.cidr,
                    "isRunning": applied.isRunning,
                    "effectivePort": applied.port
                ]
                completion(.ok(json: ["status": "ok", "data": data]))
                return true
            }
        }

        // Excluded apps CRUD
        if path == "\(base)/settings/restore/excluded-apps" {
            switch method {
            case "GET":
                completion(.ok(json: ["status": "ok", "data": ["excludedApps": handlers.getExcludedApps()]]))
                return true
            case "PUT":
                let body = request.jsonBody() ?? [:]
                let apps = body["apps"] as? [String] ?? []
                let result = handlers.setExcludedApps(apps)
                ChangeTracker.shared.record(type: "settings.changed", target: "excludedApps")
                completion(.ok(json: ["status": "ok", "data": ["excludedApps": result]]))
                return true
            case "POST":
                let body = request.jsonBody() ?? [:]
                let apps = body["apps"] as? [String] ?? []
                let result = handlers.addExcludedApps(apps)
                ChangeTracker.shared.record(type: "settings.changed", target: "excludedApps")
                completion(.ok(json: ["status": "ok", "data": ["excludedApps": result]]))
                return true
            case "DELETE":
                let body = request.jsonBody() ?? [:]
                let apps = body["apps"] as? [String] ?? []
                let result = handlers.removeExcludedApps(apps)
                ChangeTracker.shared.record(type: "settings.changed", target: "excludedApps")
                completion(.ok(json: ["status": "ok", "data": ["excludedApps": result]]))
                return true
            default: break
            }
        }

        if method == "POST" && path == "\(base)/settings/restore/excluded-apps/reset" {
            let result = handlers.resetExcludedApps()
            ChangeTracker.shared.record(type: "settings.changed", target: "excludedApps")
            completion(.ok(json: ["status": "ok", "data": ["excludedApps": result]]))
            return true
        }

        // Factory reset
        if method == "POST" && path == "\(base)/settings/factory-reset" {
            guard request.header("X-Confirm") == "true" else {
                completion(.badRequest(message: "X-Confirm: true 헤더가 필요합니다"))
                return true
            }
            let data = handlers.factoryResetSettings()
            ChangeTracker.shared.record(type: "settings.changed", target: "all")
            completion(.ok(json: ["status": "ok", "data": data]))
            return true
        }

        // 전체 설정의 일부로 취급되는 shortcuts GET
        if method == "GET" && path == "\(base)/settings/shortcuts" {
            completion(.ok(json: ["status": "ok", "data": handlers.getShortcutsDisplay()]))
            return true
        }

        // --- Mode 엔드포인트 ---

        // GET /api/v2/modes — 모드 목록
        if method == "GET" && path == "\(base)/modes" {
            handleListModes(completion: completion)
            return true
        }

        // POST /api/v2/modes — 모드 생성
        if method == "POST" && path == "\(base)/modes" {
            handleCreateMode(request: request, completion: completion)
            return true
        }

        // /api/v2/modes/{name}/... 패턴 처리
        let modesPrefix = "\(base)/modes/"
        if path.hasPrefix(modesPrefix) {
            let remaining = String(path.dropFirst(modesPrefix.count))
            let parts = remaining.split(separator: "/", maxSplits: 2).map { String($0) }

            guard let modeName = parts.first?.removingPercentEncoding, !modeName.isEmpty else {
                completion(.badRequest(message: "모드 이름이 필요합니다"))
                return true
            }

            if parts.count == 1 {
                switch method {
                case "GET":
                    handleGetMode(name: modeName, completion: completion)
                case "PATCH":
                    handleUpdateMode(name: modeName, request: request, completion: completion)
                case "DELETE":
                    handleDeleteMode(name: modeName, completion: completion)
                default:
                    completion(.methodNotAllowed())
                }
                return true
            }

            if parts.count >= 2 && parts[1] == "activate" && method == "POST" {
                handleActivateMode(name: modeName, request: request, completion: completion)
                return true
            }
        }

        // GET /api/v2/status — 현재 활성 모드 포함
        if method == "GET" && path == "\(base)/status" {
            handleV2Status(completion: completion)
            return true
        }

        // --- PaidApp 라이프사이클 엔드포인트 (Issue192 Phase A) ---

        // POST /api/v2/paidapp/register
        if method == "POST" && path == "\(base)/paidapp/register" {
            handlePaidAppRegister(request: request, completion: completion)
            return true
        }

        // POST /api/v2/paidapp/unregister
        if method == "POST" && path == "\(base)/paidapp/unregister" {
            handlePaidAppUnregister(request: request, completion: completion)
            return true
        }

        // GET /api/v2/paidapp/status
        if method == "GET" && path == "\(base)/paidapp/status" {
            handlePaidAppStatus(completion: completion)
            return true
        }

        return false
    }

    // MARK: - PaidApp 핸들러 (Issue192 Phase A)

    private func handlePaidAppRegister(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let body = request.body, !body.isEmpty else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        let decoder = JSONDecoder()
        let req: PaidAppRegisterRequest
        do {
            req = try decoder.decode(PaidAppRegisterRequest.self, from: body)
        } catch {
            completion(.badRequest(message: "PaidAppRegisterRequest 파싱 실패: \(error)"))
            return
        }
        let result = paidAppRouter.register(request: req)
        switch result {
        case let .success(resp):
            completion(.ok(json: [
                "sessionId": resp.sessionId,
                "registeredAt": resp.registeredAt
            ]))
            logStateTransition(event: "register", pid: req.pid, sessionId: resp.sessionId)
        case let .forbidden(reason):
            logW(reason)
            completion(.forbidden(message: reason))
        case let .badRequest(reason):
            completion(.badRequest(message: reason))
        case let .notFound(reason):
            completion(.notFound(message: reason))
        }
    }

    private func handlePaidAppUnregister(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let body = request.body, !body.isEmpty else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        let decoder = JSONDecoder()
        let req: PaidAppUnregisterRequest
        do {
            req = try decoder.decode(PaidAppUnregisterRequest.self, from: body)
        } catch {
            completion(.badRequest(message: "PaidAppUnregisterRequest 파싱 실패: \(error)"))
            return
        }
        let result = paidAppRouter.unregister(request: req)
        switch result {
        case let .success(resp):
            completion(.ok(json: ["unregisteredAt": resp.unregisteredAt]))
            logStateTransition(event: "unregister", pid: req.pid, sessionId: req.sessionId)
        case let .forbidden(reason):
            logW(reason)
            completion(.forbidden(message: reason))
        case let .badRequest(reason):
            completion(.badRequest(message: reason))
        case let .notFound(reason):
            completion(.notFound(message: reason))
        }
    }

    private func handlePaidAppStatus(completion: @escaping (HTTPResponse) -> Void) {
        let resp = paidAppRouter.status()
        var json: [String: Any] = ["state": resp.state.rawValue]
        if let pid = resp.pid { json["pid"] = pid }
        if let v = resp.version { json["version"] = v }
        if let bp = resp.bundlePath { json["bundlePath"] = bp }
        if let sid = resp.sessionId { json["sessionId"] = sid }
        if let ra = resp.registeredAt { json["registeredAt"] = ra }
        completion(.ok(json: json))
    }

    /// `paidapp_state_transitions.log`에 상태 전환 기록 (Phase A-8 infra).
    /// 파일 쓰기 실패는 조용히 무시 (로깅 실패가 서버 동작을 막지 않음).
    private func logStateTransition(event: String, pid: Int32, sessionId: String) {
        let timestamp = ISO8601Formatter.string(from: Date())
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/finfra/fWarrangeData/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logFile = logDir.appendingPathComponent("paidapp_state_transitions.log")
        let line = "\(timestamp) event=\(event) pid=\(pid) sessionId=\(sessionId)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    // MARK: - Mode 핸들러

    /// GET /api/v2/modes
    private func handleListModes(completion: @escaping (HTTPResponse) -> Void) {
        do {
            let modes = try handlers.listModes()
            let data = modes.map { meta -> [String: Any] in
                var d: [String: Any] = [
                    "name": meta.name,
                    "icon": meta.icon,
                    "layoutRef": meta.layoutRef,
                    "fileDate": ISO8601Formatter.string(from: meta.fileDate)
                ]
                if let sc = meta.shortcut { d["shortcut"] = sc }
                return d
            }
            let activeMode = handlers.getActiveModeName()
            var response: [String: Any] = ["status": "ok", "data": data]
            if let active = activeMode { response["activeMode"] = active }
            completion(.ok(json: response))
        } catch {
            completion(.internalError(message: "모드 목록 조회 실패: \(error.localizedDescription)"))
        }
    }

    /// POST /api/v2/modes
    private func handleCreateMode(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let json = request.jsonBody(),
              let name = json["name"] as? String, !name.isEmpty else {
            completion(.badRequest(message: "name 필드가 필요합니다"))
            return
        }
        let icon = json["icon"] as? String ?? "rectangle.3.group"
        let shortcut = json["shortcut"] as? String
        let layoutRef = json["layout"] as? String ?? name

        do {
            let mode = try handlers.createMode(name, icon, shortcut, layoutRef)
            ChangeTracker.shared.record(type: "mode.created", target: name)
            completion(.ok(json: ["status": "ok", "data": modeToDict(mode)]))
        } catch {
            completion(.internalError(message: "모드 생성 실패: \(error.localizedDescription)"))
        }
    }

    /// GET /api/v2/modes/{name}
    private func handleGetMode(name: String, completion: @escaping (HTTPResponse) -> Void) {
        do {
            let mode = try handlers.loadMode(name)
            completion(.ok(json: ["status": "ok", "data": modeToDict(mode)]))
        } catch {
            completion(.notFound(message: "모드를 찾을 수 없습니다: '\(name)'"))
        }
    }

    /// PATCH /api/v2/modes/{name}
    private func handleUpdateMode(name: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let body = request.jsonBody() else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        do {
            let mode = try handlers.updateMode(name, body)
            ChangeTracker.shared.record(type: "mode.updated", target: name)
            completion(.ok(json: ["status": "ok", "data": modeToDict(mode)]))
        } catch {
            completion(.notFound(message: "모드 수정 실패: '\(name)'"))
        }
    }

    /// DELETE /api/v2/modes/{name}
    private func handleDeleteMode(name: String, completion: @escaping (HTTPResponse) -> Void) {
        do {
            try handlers.deleteMode(name)
            ChangeTracker.shared.record(type: "mode.deleted", target: name)
            completion(.ok(json: ["status": "ok", "data": ["deleted": name]]))
        } catch {
            completion(.notFound(message: "모드를 찾을 수 없습니다: '\(name)'"))
        }
    }

    /// POST /api/v2/modes/{name}/activate
    private func handleActivateMode(name: String, request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else {
                completion(.internalError(message: "서버가 해제되었습니다"))
                return
            }
            do {
                let result = try await self.handlers.activateMode(name)
                ChangeTracker.shared.record(type: "mode.activated", target: name)

                let succeeded = result.restoreResults.filter { $0.success }.count
                let total = result.restoreResults.count

                let data: [String: Any] = [
                    "mode": self.modeToDict(result.mode),
                    "restore": [
                        "total": total,
                        "succeeded": succeeded,
                        "failed": total - succeeded
                    ] as [String: Any]
                ]
                completion(.ok(json: ["status": "ok", "data": data]))
            } catch is ModeActivationError {
                completion(.conflict(message: "모드 전환이 이미 진행 중입니다"))
            } catch {
                completion(.notFound(message: "모드 전환 실패: \(error.localizedDescription)"))
            }
        }
    }

    /// GET /api/v2/status
    private func handleV2Status(completion: @escaping (HTTPResponse) -> Void) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let uptime = Int(Date().timeIntervalSince(startedAt))
        var data: [String: Any] = [
            "status": "ok",
            "app": "fWarrangeCli",
            "version": version,
            "port": Int(port),
            "uptimeSeconds": uptime,
            "isRunning": isRunning
        ]
        if let active = handlers.getActiveModeName() {
            data["activeMode"] = active
        }
        completion(.ok(json: data))
    }

    private func modeToDict(_ mode: Mode) -> [String: Any] {
        var d: [String: Any] = [
            "name": mode.name,
            "icon": mode.icon,
            "layoutRef": mode.layoutRef
        ]
        if let sc = mode.shortcut { d["shortcut"] = sc }
        if !mode.requiredApps.isEmpty {
            d["requiredApps"] = mode.requiredApps.map { app in
                ["bundleId": app.bundleId, "action": app.action.rawValue] as [String: Any]
            }
        }
        return d
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
                ChangeTracker.shared.record(type: "layout.created", target: name)
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
                ChangeTracker.shared.record(type: "layout.deleted", target: name)
                ChangeTracker.shared.record(type: "layout.created", target: newName)
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
                ChangeTracker.shared.record(type: "layout.deleted", target: name)
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
                ChangeTracker.shared.record(type: "layout.deleted", target: "*")
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
        ChangeTracker.shared.record(type: "shortcuts.changed", target: "shortcuts")
        completion(.ok(json: ["status": "ok", "data": applied]))
    }

    // MARK: - UI 상태

    /// PUT /api/v1/ui/state - UI 상태 변경
    private func handleSetUIState(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) {
        guard let body = request.jsonBody() else {
            completion(.badRequest(message: "JSON body가 필요합니다"))
            return
        }
        if let hide = body["hideMenuBar"] as? Bool {
            DispatchQueue.main.async {
                self.handlers.setHideMenuBar(hide)
            }
        }
        let current = handlers.getHideMenuBar()
        completion(.ok(json: ["status": "ok", "data": ["hideMenuBar": current]]))
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

    /// 새 path로 복제 (v2→v1 경로 재작성용)
    func withPath(_ newPath: String) -> HTTPRequest {
        return HTTPRequest(method: method, path: newPath, queryString: queryString, headers: headers, body: body)
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

    static func conflict(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 409, statusMessage: "Conflict", headers: [:], body: body)
    }

    static func internalError(message: String) -> HTTPResponse {
        let body = try? JSONSerialization.data(withJSONObject: ["status": "error", "error": message], options: .sortedKeys)
        return HTTPResponse(statusCode: 500, statusMessage: "Internal Server Error", headers: [:], body: body)
    }
}
