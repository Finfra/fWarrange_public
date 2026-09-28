import Foundation

/// Issue39 재설계: `brew services` (launchd) ↔ 메뉴바 앱 상태를 4-quadrant 매트릭스로 동기화.
///
/// 집행 지점:
/// * `onAppStart()` — 앱 시작 시 호출. brew 가 `stopped` 상태면 `brew services start` 로 승격.
///                    이미 `started` 면 skip. (매트릭스: app start 행)
/// * `onAppStop(timeout:)` — 앱 종료 시 동기 호출. brew 가 `started` 상태면 `brew services stop` 으로 강등.
///                           이미 `stopped` 면 skip. 호출부가 이어서 `NSApplication.terminate` 수행.
///                           (매트릭스: app stop 행)
///
/// brew 측 트리거(brew start/stop × 앱 실행 중) 에 대한 중복 방지는
/// `SingleInstanceGuard` + Formula `keep_alive: successful_exit: false` 가 담당.
enum BrewServiceSync {

    static let formulaName = "fwarrange-cli"

    /// Issue95: Homebrew 가 서비스 label 규약을 `homebrew.mxcl.{formula}` 에서
    /// `sh.brew.{formula}` 로 바꿨다. 어느 한쪽으로 고정하면 다른 규약이 깔린 머신에서
    /// 판정이 전부 빗나가고, `onAppStart()` 의 skip 조건 두 개가 동시에 무너져
    /// handoff 무한 루프(기동 불가)로 이어진다.
    /// 따라서 **두 규약을 모두 인식**하며, 세 소비처
    /// (`BrewServiceSync`·`SingleInstanceGuard`·`LoginItemService`)는
    /// 아래 `isServiceLabel(_:)` 하나만 쓴다. label 문자열을 다시 하드코딩하지 말 것.
    static let knownServiceLabels = [
        "sh.brew.\(formulaName)",       // 신규 규약 (Homebrew 6.0.21-126 이후)
        "homebrew.mxcl.\(formulaName)"  // 구 규약
    ]

    /// 로그 표기용 대표 label. 판정에는 쓰지 않는다 — 판정은 `isServiceLabel(_:)`.
    static var serviceLabel: String { knownServiceLabels[0] }
    /// 명시적 `false` 일 때만 Phase 3 를 skip. 미설정·`true` 는 활성.
    static let optOutKey = "fwc.autoStartBrewService"

    static let brewCandidates = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    // MARK: - Handoff (open 경로 → launchd-bootstrap 위임)

    /// open/심링크 기동 경로에서 launchd-bootstrap 인스턴스에 primary 를 위임.
    /// brew services start 를 동기 호출 → launchd 가 새 프로세스 spawn →
    /// 현재 프로세스는 로그 flush 뒤 Foundation.exit(0) 으로 clean 종료.
    /// `handoffInProgress = true` 로 applicationWillTerminate 의 brew stop race 차단.
    ///
    /// Issue109: `brew services start` 가 실패하면 승계할 프로세스가 없다 — exit 하지 않고
    /// 현재 프로세스가 primary 로 남는다. 예전에는 rc 와 무관하게 exit 해 앱이 기동 직후 사라졌다.
    private static var handoffInProgress = false

    /// `onAppStart` 가 바깥 세계(UserDefaults·launchctl·brew·exit)를 만지는 지점.
    /// 테스트는 가짜로 바꿔 끼워 실 brew 를 부르지 않는다 (Issue109).
    struct StartEnvironment {
        var optOut: () -> Bool?
        var isLaunchedByLaunchd: () -> Bool
        var isServiceLoaded: () -> Bool
        var findBrewPath: () -> String?
        var isFormulaInstalled: (String) -> Bool
        var startService: (String) -> (Int32, String)
        var flushLog: () -> Void
        var exitProcess: () -> Void
        /// XCTest host process — it must never touch the real brew service (Issue106)
        var isTestHost: () -> Bool = { false }

        static let live = StartEnvironment(
            optOut: { UserDefaults.standard.object(forKey: optOutKey) as? Bool },
            isLaunchedByLaunchd: { BrewServiceSync.isLaunchedByLaunchd() },
            isServiceLoaded: { BrewServiceSync.isServiceLoaded() },
            findBrewPath: { BrewServiceSync.findBrewPath() },
            isFormulaInstalled: { BrewServiceSync.isFormulaInstalled(brewPath: $0) },
            startService: { runCommandWithStatus($0, args: ["services", "start", formulaName]) },
            flushLog: { Logger.shared.flush() },
            exitProcess: { Foundation.exit(0) },
            isTestHost: { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }
        )
    }

    enum StartOutcome: Equatable {
        case skipped      // 동기화 대상 아님 — 현재 프로세스 그대로
        case keptPrimary  // handoff 실패 — 현재 프로세스가 primary 유지
        case handedOff    // launchd 인스턴스에 위임하고 exit
    }

    private static func performHandoffStart(brewPath: String, env: StartEnvironment) -> StartOutcome {
        handoffInProgress = true
        logI("[brew-sync] performHandoffStart — brew services start 동기 호출 (성공 시 self-terminate)")
        let (rc, output) = env.startService(brewPath)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard rc == 0 else {
            handoffInProgress = false
            logW("[brew-sync] ⚠️ brew services start 실패 (rc=\(rc)) — exit 하지 않고 primary 유지: \(trimmed)")
            return .keptPrimary
        }
        logI("[brew-sync] ✅ brew services start 성공 → launchd-bootstrap 이 primary 승계: \(trimmed)")
        // exit 가 Logger 의 비동기 쓰기를 앞지르면 자체 종료가 로그에 남지 않는다 (Issue109).
        env.flushLog()
        env.exitProcess()
        return .handedOff
    }

    // MARK: - App Start → brew=started (매트릭스: app start 행)

    /// 앱 기동 직후 호출. brew 가 `stopped` 이면 `brew services start` 로 동기화.
    ///
    /// skip 조건:
    /// 1. `UserDefaults` optOutKey == false
    /// 2. launchd 가 이 프로세스를 기동 (XPC_SERVICE_NAME 매칭) — 무한 루프 방지
    /// 3. `launchctl list` 에 이미 로드됨 — brew state 이미 `started`
    /// 4. brew 바이너리 미존재
    /// 5. formula 미설치 — launchd 가 띄울 서비스 실행 파일이 없다 (Issue109: README 소스 빌드)
    ///
    /// open/심링크 경로에서 brew=stopped 이면 `performHandoffStart()` 로 위임 후 exit.
    /// 위임이 실패하면 exit 하지 않고 `.keptPrimary` 를 반환한다.
    @discardableResult
    static func onAppStart(_ env: StartEnvironment = .live) -> StartOutcome {
        // Issue106: the XCTest host runs AppState too — never query or hand off to the real brew service there
        if env.isTestHost() {
            logD("[brew-sync] onAppStart skip — XCTest host")
            return .skipped
        }

        if let optOut = env.optOut(), optOut == false {
            logI("[brew-sync] onAppStart skip — \(optOutKey)=false")
            return .skipped
        }

        if env.isLaunchedByLaunchd() {
            logD("[brew-sync] onAppStart skip — launchd 기동 프로세스 (XPC_SERVICE_NAME)")
            return .skipped
        }

        if env.isServiceLoaded() {
            logD("[brew-sync] onAppStart skip — brew state 이미 started (launchctl 에 서비스 로드됨)")
            return .skipped
        }

        guard let brewPath = env.findBrewPath() else {
            logI("[brew-sync] onAppStart skip — brew 미설치")
            return .skipped
        }

        guard env.isFormulaInstalled(brewPath) else {
            logI("[brew-sync] onAppStart skip — \(formulaName) formula 미설치 (brew 서비스로 승계 불가)")
            return .skipped
        }

        // open/심링크 경로 × brew=stopped: launchd-bootstrap 에 primary 위임 후 self-terminate.
        return performHandoffStart(brewPath: brewPath, env: env)
    }

    // MARK: - Restart (Issue96 권한 복구)

    /// launchd(brew services) 가 이 프로세스를 관리 중이면 `brew services restart` 로
    /// 재기동을 위임하고 `true` 를 반환한다. 반환 직후 현재 프로세스는 launchd 에 의해 종료된다.
    ///
    /// 종료 훅의 `brew services stop` 이 재시작과 경합해 서비스가 `stopped` 로 수렴하는 것을
    /// 막기 위해 handoff 플래그를 세운다(`onAppStop` 이 skip 됨).
    /// launchd 관리가 아니면 `false` — 호출부가 직접 재실행해야 한다.
    @discardableResult
    static func requestManagedRestart() -> Bool {
        guard isServiceLoaded(), let brewPath = findBrewPath() else {
            logI("[brew-sync] requestManagedRestart — launchd 관리 아님, 호출부 자체 재실행 필요")
            return false
        }
        handoffInProgress = true
        logI("[brew-sync] requestManagedRestart — brew services restart \(formulaName)")
        DispatchQueue.global(qos: .userInitiated).async {
            let (rc, output) = runCommandWithStatus(brewPath, args: ["services", "restart", formulaName])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if rc == 0 {
                logI("[brew-sync] ✅ brew services restart 성공: \(trimmed)")
            } else {
                logW("[brew-sync] ⚠️ brew services restart 실패 (rc=\(rc)): \(trimmed)")
            }
        }
        return true
    }

    // MARK: - App Stop → brew=stopped (매트릭스: app stop 행)

    /// 메뉴바 "종료" 진입점에서 동기 호출. brew 가 `started` 이면 `brew services stop` 으로 동기화.
    ///
    /// 반환 후 호출부가 `NSApplication.terminate` 를 수행함.
    /// 타임아웃 초과 시 종료 흐름 지연 방지 위해 포기하고 반환.
    static func onAppStop(timeout: TimeInterval = 2.0) {
        if handoffInProgress {
            logI("[brew-sync] onAppStop skip — handoff in progress (brew stop 억제)")
            return
        }

        guard let brewPath = findBrewPath() else {
            logI("[brew-sync] onAppStop skip — brew 미설치")
            return
        }

        if !isServiceLoaded() {
            logD("[brew-sync] onAppStop skip — brew state 이미 stopped")
            return
        }

        logI("[brew-sync] brew services stop \(formulaName) — app stop × brew=started")

        let semaphore = DispatchSemaphore(value: 0)
        var result: (Int32, String) = (-999, "")
        DispatchQueue.global(qos: .userInitiated).async {
            result = runCommandWithStatus(brewPath, args: ["services", "stop", formulaName])
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            logW("[brew-sync] ⚠️ brew services stop 타임아웃 (\(timeout)s) — fallback terminate 진행")
            return
        }
        let trimmed = result.1.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.0 == 0 {
            logI("[brew-sync] ✅ brew services stop 성공 → brew=stopped: \(trimmed)")
        } else {
            logW("[brew-sync] ⚠️ brew services stop 실패 (rc=\(result.0)): \(trimmed)")
        }
    }

    // MARK: - 상태 판정

    /// brew services(launchctl bootstrap) 로 기동됐는지 판정.
    /// macOS GUI 앱은 `open`/Finder 기동이더라도 부모 PID 가 1(launchd) 이므로
    /// PPID 기반 판정은 상시 true 가 되어 무한 루프 방지 조건으로만 사용 불가.
    /// `XPC_SERVICE_NAME` 이 서비스 label 과 일치하는 경우만 launchd 기동으로 간주.
    static func isLaunchedByLaunchd() -> Bool {
        return isServiceLabel(ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"])
    }

    /// 주어진 문자열이 이 formula 의 launchd 서비스 label 인지 판정 (Issue95 단일 지점).
    ///
    /// 알려진 두 규약과 정확히 일치하거나, 마지막 컴포넌트가 formula 명이면 참이다.
    /// 후자는 brew 가 규약을 **또** 바꿔도 따라가기 위한 것으로, `*.fwarrange-cli` 를
    /// label 로 쓰는 다른 서비스는 사실상 존재하지 않으므로 오탐 위험이 낮다.
    static func isServiceLabel(_ candidate: String?) -> Bool {
        guard let candidate, !candidate.isEmpty else { return false }
        if knownServiceLabels.contains(candidate) { return true }
        return candidate.split(separator: ".").last.map(String.init) == formulaName
    }

    /// brew state == `started` 와 등가. `launchctl list` 출력의 label 컬럼을 판정한다.
    /// 출력은 `PID<TAB>Status<TAB>Label` 3컬럼이라 마지막 필드가 label 이다.
    static func isServiceLoaded() -> Bool {
        let output = runCommand("/bin/launchctl", args: ["list"]) ?? ""
        for line in output.split(separator: "\n") {
            guard let field = line.split(separator: "\t").last else { continue }
            if isServiceLabel(String(field).trimmingCharacters(in: .whitespaces)) { return true }
        }
        return false
    }

    /// `~/Library/LaunchAgents/` 에서 이 formula 의 서비스 plist 를 찾는다.
    /// 파일명이 곧 `{label}.plist` 이므로 label 판정을 그대로 재사용한다.
    /// 규약 전환기에는 구·신 파일이 함께 남을 수 있어 배열로 반환한다.
    static func launchAgentPlistURLs() -> [URL] {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents")
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return entries.filter {
            $0.pathExtension == "plist"
                && isServiceLabel($0.deletingPathExtension().lastPathComponent)
        }
    }

    /// formula 가 설치돼 launchd 가 띄울 서비스 실행 파일이 있는지 (Issue109).
    /// Formula `service` 블록의 `run` 경로(`{prefix}/opt/{formula}/fWarrangeCli.app/...`)를 그대로 본다.
    /// `brew list` 는 기동 경로의 메인 스레드에서 Ruby 를 한 번 더 띄우므로 파일 판정으로 대신한다.
    static func isFormulaInstalled(brewPath: String) -> Bool {
        let prefix = URL(fileURLWithPath: brewPath)
            .deletingLastPathComponent()   // bin
            .deletingLastPathComponent()   // {prefix}
        let executable = prefix
            .appendingPathComponent("opt/\(formulaName)/fWarrangeCli.app/Contents/MacOS/fWarrangeCli")
        return FileManager.default.isExecutableFile(atPath: executable.path)
    }

    static func findBrewPath() -> String? {
        for path in brewCandidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    // MARK: - 실행 헬퍼

    static func runCommand(_ executable: String, args: [String]) -> String? {
        let (rc, output) = runCommandWithStatus(executable, args: args)
        return rc == 0 ? output : nil
    }

    static func runCommandWithStatus(_ executable: String, args: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, "\(error)")
        }
    }
}
