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

    private static var baseURL: String { "http://\(host):\(port)/api/v1" }

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
            switch args[i] {
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
                filtered.append(args[i])
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
            guard let name = args.first else { exitError("<name> 필수") }
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

        default:
            printErr("오류: 알 수 없는 커맨드 '\(command)'")
            printHelp(exitCode: 1)
        }
    }

    // MARK: - HTTP 요청

    private static func fetch(
        _ method: String,
        path: String,
        body: Any? = nil
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
        request.timeoutInterval = 5

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
          restore <name>                  Restore layout
          rename <old> <new>              Rename layout
          delete <name>                   Delete layout
          delete-all --confirm            Delete all layouts
          remove-windows <name> <id> ...  Remove specific windows from layout
          windows [--filter <apps>]       List current windows
          apps                            List running apps
          accessibility                   Check accessibility permission
          quit --confirm                  Quit daemon

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
