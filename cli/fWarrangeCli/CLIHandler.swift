import Foundation

// MARK: - CLIHandler

/// CLI 커맨드 파싱 및 REST API 호출 핸들러.
/// CLI 인자가 있으면 해당 커맨드 실행 후 exit, 없으면 GUI 모드.
struct CLIHandler {

    // MARK: - 설정

    private static var host = "localhost"
    private static var port = 3016
    private static var pretty = false
    private static var quiet = false

    private static var baseURL: String { "http://\(host):\(port)/api/v2" }

    // MARK: - 진입점

    /// CLI 인자가 있으면 처리 후 true 반환. 없으면 false.
    static func handleIfNeeded() -> Bool {
        var args = Array(ProcessInfo.processInfo.arguments.dropFirst())
        guard !args.isEmpty else { return false }

        // 공통 옵션 파싱
        parseGlobalOptions(&args)
        guard !args.isEmpty else { return false }

        let command = args.removeFirst()
        handle(command: command, args: args)
        return true
    }

    // MARK: - 공통 옵션 파싱

    private static func parseGlobalOptions(_ args: inout [String]) {
        var filtered: [String] = []
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--port":
                i += 1
                if i < args.count { port = Int(args[i]) ?? 3016 }
            case "--host":
                i += 1
                if i < args.count { host = args[i] }
            case "--pretty":
                pretty = true
            case "--quiet", "-q":
                quiet = true
            default:
                // Xcode 디버거가 주입하는 Cocoa UserDefaults 인자 무시
                // (ex) -NSDocumentRevisionsDebugMode YES, -ApplePersistenceIgnoreState YES
                if arg.count >= 2, arg.hasPrefix("-"), !arg.hasPrefix("--"),
                   let second = arg.dropFirst().first, second.isUppercase {
                    if i + 1 < args.count { i += 1 }
                } else {
                    filtered.append(arg)
                }
            }
            i += 1
        }
        args = filtered
    }

    // MARK: - 커맨드 디스패치

    private static func handle(command: String, args: [String]) {
        switch command {
        // 정보
        case "--help", "-h":
            printHelp()
        case "--version", "-v":
            fetch("GET", path: "/cli/version")
        case "status":
            fetch("GET", path: "/cli/status")
        case "health":
            fetch("GET", path: "/")
        case "settings":
            fetch("GET", path: "/settings")

        // 레이아웃
        case "list":
            fetch("GET", path: "/layouts")
        case "show":
            guard let name = args.first else { exitError("<name> 필수") }
            fetch("GET", path: "/layouts/\(name.urlEncoded)")
        case "capture":
            var body: [String: Any] = [:]
            if let name = args.first { body["name"] = name }
            fetch("POST", path: "/capture", body: body)
        case "restore":
            let name = args.first ?? "default"
            fetch("POST", path: "/layouts/\(name.urlEncoded)/restore")
        case "rename":
            guard args.count >= 2 else { exitError("<old> <new> 필수") }
            fetch("PUT", path: "/layouts/\(args[0].urlEncoded)", body: ["newName": args[1]])
        case "delete":
            guard let name = args.first else { exitError("<name> 필수") }
            fetch("DELETE", path: "/layouts/\(name.urlEncoded)")
        case "delete-all":
            guard args.contains("--confirm") else { exitError("--confirm 플래그 필수") }
            fetch("DELETE", path: "/layouts", body: ["confirm": true])
        case "remove-windows":
            guard args.count >= 2 else { exitError("<name> <id> [...] 필수") }
            let name = args[0]
            let ids = args.dropFirst().compactMap { Int($0) }
            guard !ids.isEmpty else { exitError("유효한 window ID 필수") }
            fetch("POST", path: "/layouts/\(name.urlEncoded)/windows/remove", body: ["windowIds": ids])

        // 창 정보
        case "windows":
            var filterApps: String? = nil
            if let idx = args.firstIndex(of: "--filter"), idx + 1 < args.count {
                filterApps = args[idx + 1]
            }
            if let apps = filterApps {
                fetch("GET", path: "/windows/current?filter=\(apps.urlEncoded)")
            } else {
                fetch("GET", path: "/windows/current")
            }
        case "apps":
            fetch("GET", path: "/windows/apps")

        // 시스템
        case "accessibility":
            fetch("GET", path: "/status/accessibility")
        case "quit":
            guard args.contains("--confirm") else { exitError("--confirm 플래그 필수") }
            fetch("POST", path: "/cli/quit", body: ["confirm": true])

        // 모드
        case "mode":
            handleMode(args: args)
        case "switch":
            guard let name = args.first else { exitError("<name> 필수") }
            fetch("POST", path: "/modes/\(name.urlEncoded)/activate")

        // v2 API (Settings 탭 전���)
        case "v2":
            handleV2(args: args)

        default:
            printErr("오류: 알 수 없는 커맨드 '\(command)'")
            printHelp(exitCode: 1)
        }
    }

    // MARK: - Mode 디스패치

    private static func handleMode(args: [String]) {
        guard let sub = args.first else {
            // mode 단독 → 목록 표시
            fetch("GET", path: "/modes")
            return
        }
        let rest = Array(args.dropFirst())
        switch sub {
        case "list":
            fetch("GET", path: "/modes")
        case "create":
            guard let name = rest.first else { exitError("mode create <name> [--layout <layout>] [--icon <icon>] [--shortcut <shortcut>]") }
            var body: [String: Any] = ["name": name]
            var i = 1
            while i < rest.count {
                switch rest[i] {
                case "--layout":
                    i += 1; if i < rest.count { body["layout"] = rest[i] }
                case "--icon":
                    i += 1; if i < rest.count { body["icon"] = rest[i] }
                case "--shortcut":
                    i += 1; if i < rest.count { body["shortcut"] = rest[i] }
                default: break
                }
                i += 1
            }
            fetch("POST", path: "/modes", body: body)
        case "show":
            guard let name = rest.first else { exitError("mode show <name> 필수") }
            fetch("GET", path: "/modes/\(name.urlEncoded)")
        case "delete":
            guard let name = rest.first else { exitError("mode delete <name> 필수") }
            fetch("DELETE", path: "/modes/\(name.urlEncoded)")
        case "edit":
            guard let name = rest.first else { exitError("mode edit <name> <json> 필수") }
            guard rest.count >= 2 else { exitError("mode edit <name> <json> 필수") }
            fetch("PATCH", path: "/modes/\(name.urlEncoded)", body: parseJSONObject(rest[1]))
        default:
            exitError("알 수 없는 mode 서브커맨드: \(sub) (허용: list|create|show|delete|edit)")
        }
    }

    // MARK: - v2 디스패치

    private static func handleV2(args allArgs: [String]) {
        // allArgs는 "v2" 이후의 인자 배열 (handle(command:args:)에서 "v2"는 이미 소비됨)
        let args = allArgs
        guard let sub = args.first else {
            exitError("v2 서브커맨드 필수 (settings|excluded-apps|shortcuts|factory-reset)")
        }
        let rest = Array(args.dropFirst())
        switch sub {
        case "settings":
            handleV2Settings(rest)
        case "excluded-apps":
            handleV2ExcludedApps(rest)
        case "shortcuts":
            handleV2Shortcuts(rest)
        case "factory-reset":
            guard rest.contains("--confirm") else { exitError("--confirm 플래그 필수") }
            fetch("POST", path: "/settings/factory-reset",
                  headers: ["X-Confirm": "true"])
        default:
            exitError("알 수 없는 v2 서브커맨드: \(sub)")
        }
    }

    private static func handleV2Settings(_ args: [String]) {
        // 사용법:
        //   v2 settings                       → GET /settings
        //   v2 settings patch <json>          → PATCH /settings
        //   v2 settings <tab>                 → GET /settings/<tab>
        //   v2 settings <tab> patch <json>    → PATCH /settings/<tab>
        guard let first = args.first else {
            fetch("GET", path: "/settings")
            return
        }
        if first == "patch" {
            guard args.count >= 2 else { exitError("patch <json> 필수") }
            fetch("PATCH", path: "/settings",
                  body: parseJSONObject(args[1]))
            return
        }
        let tabs = ["general", "restore", "api", "advanced"]
        guard tabs.contains(first) else {
            exitError("알 수 없는 settings 탭: \(first) (허용: \(tabs.joined(separator: ","))")
        }
        if args.count == 1 {
            fetch("GET", path: "/settings/\(first)")
            return
        }
        guard args[1] == "patch" else {
            exitError("사용법: v2 settings \(first) [patch <json>]")
        }
        guard args.count >= 3 else { exitError("patch <json> 필수") }
        fetch("PATCH", path: "/settings/\(first)",
              body: parseJSONObject(args[2]))
    }

    private static func handleV2ExcludedApps(_ args: [String]) {
        // 사용법:
        //   v2 excluded-apps                  → GET
        //   v2 excluded-apps get              → GET
        //   v2 excluded-apps set <app> ...    → PUT (전체 교체)
        //   v2 excluded-apps add <app> ...    → POST
        //   v2 excluded-apps remove <app> ... → DELETE
        //   v2 excluded-apps reset            → POST /reset
        let base = "/settings/restore/excluded-apps"
        guard let action = args.first else {
            fetch("GET", path: base)
            return
        }
        let apps = Array(args.dropFirst())
        switch action {
        case "get":
            fetch("GET", path: base)
        case "set":
            guard !apps.isEmpty else { exitError("<app> ... 필수") }
            fetch("PUT", path: base, body: ["apps": apps])
        case "add":
            guard !apps.isEmpty else { exitError("<app> ... 필수") }
            fetch("POST", path: base, body: ["apps": apps])
        case "remove":
            guard !apps.isEmpty else { exitError("<app> ... 필수") }
            fetch("DELETE", path: base, body: ["apps": apps])
        case "reset":
            fetch("POST", path: "\(base)/reset")
        default:
            exitError("알 수 없는 excluded-apps 액션: \(action)")
        }
    }

    private static func handleV2Shortcuts(_ args: [String]) {
        // 사용법:
        //   v2 shortcuts [get]          → GET
        //   v2 shortcuts set <json>     → PUT
        if args.isEmpty || args[0] == "get" {
            fetch("GET", path: "/settings/shortcuts")
            return
        }
        if args[0] == "set" {
            guard args.count >= 2 else { exitError("set <json> 필수") }
            fetch("PUT", path: "/settings/shortcuts",
                  body: parseJSONObject(args[1]))
            return
        }
        exitError("사용법: v2 shortcuts [get|set <json>]")
    }

    private static func parseJSONObject(_ s: String) -> [String: Any] {
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else {
            exitError("유효한 JSON 객체가 아닙니다: \(s)")
        }
        return dict
    }

    // MARK: - HTTP 요청

    private static func fetch(
        _ method: String,
        path: String,
        body: Any? = nil,
        headers: [String: String] = [:]
    ) {
        // health 엔드포인트는 base 없이 root
        let urlString: String
        if path == "/" {
            urlString = "http://\(host):\(port)/"
        } else {
            urlString = "\(baseURL)\(path)"
        }

        guard let url = URL(string: urlString) else {
            exitError("유효하지 않은 URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var httpStatusCode: Int?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            httpStatusCode = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain &&
               (nsError.code == NSURLErrorCannotConnectToHost || nsError.code == -1004) {
                exitError("fWarrangeCli가 실행 중이 아닙니다 (포트 \(port))")
            }
            exitError("\(error.localizedDescription)")
        }

        guard let data = responseData else {
            exitError("응답 데이터 없음")
        }

        if quiet {
            let code = httpStatusCode ?? 0
            terminate(code >= 200 && code < 300 ? 0 : 1)
        }

        printJSON(data)
        let code = httpStatusCode ?? 0
        terminate(code >= 200 && code < 300 ? 0 : 1)
    }

    // MARK: - 출력

    private static func printJSON(_ data: Data) {
        if pretty {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: formatted, encoding: .utf8) {
                print(str)
                return
            }
        }
        if let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private static func terminate(_ code: Int32) -> Never {
        fflush(stdout)
        _exit(code)
    }

    private static func exitError(_ message: String) -> Never {
        printErr("오류: \(message)")
        terminate(1)
    }

    // MARK: - 도움말

    private static func printHelp(exitCode: Int32 = 0) {
        let help = """
        fWarrangeCli - Window arrangement helper daemon

        Usage: fWarrangeCli [command] [options]

        Commands:
          status                          Show daemon status
          health                          Health check
          settings                        Show app settings
          list                            List layouts
          show <name>                     Show layout detail
          capture [name]                  Capture and save current windows
          restore [name]                  Restore layout (default: 'default')
          rename <old> <new>              Rename layout
          delete <name>                   Delete layout
          delete-all --confirm            Delete all layouts
          remove-windows <name> <id> ...  Remove specific windows from layout
          windows [--filter <apps>]       List current windows
          apps                            List running apps
          accessibility                   Check accessibility permission
          quit --confirm                  Quit daemon

        Modes:
          mode [list]                       List modes
          mode create <name> [options]      Create mode (--layout, --icon, --shortcut)
          mode show <name>                  Show mode detail
          mode edit <name> <json>           Edit mode (JSON patch)
          mode delete <name>                Delete mode
          switch <name>                     Switch to mode (restore layout)

        v2 API (Settings):
          v2 settings [patch <json>]                       Full settings
          v2 settings <tab> [patch <json>]                 Tab: general|restore|api|advanced
          v2 excluded-apps [get]                           List excluded apps
          v2 excluded-apps set|add|remove <app>...         Update excluded apps
          v2 excluded-apps reset                           Reset to defaults
          v2 shortcuts [get]                               Get shortcuts
          v2 shortcuts set <json>                          Update shortcuts
          v2 factory-reset --confirm                       Factory reset all settings

        Options:
          -h, --help          Show this help
          -v, --version       Show version
          --port <port>       API port (default: 3016)
          --host <host>       API host (default: localhost)
          --pretty            Pretty-print JSON output
          -q, --quiet         Minimal output (exit code only)
        """
        print(help)
        terminate(exitCode)
    }
}

// MARK: - String Extension

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
