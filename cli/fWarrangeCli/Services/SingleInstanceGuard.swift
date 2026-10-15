import AppKit
import Foundation

/// Issue39 Phase4 (2026-04-20 재정비): 동일 Bundle ID 의 다른 실행 인스턴스가 있을 때
/// **launchd-bootstrap 프로세스가 우선권** 을 갖도록 조정.
///
/// 배경: `open` 으로 기동된 앱이 `onAppStart` 에서 `brew services start` 를 호출하면
/// launchd 가 별도 프로세스를 spawn 함. 과거 구현은 신규 프로세스가 무조건 exit 하여
/// `brew services list` 가 `stopped` 로 남는 문제 발생 → launchd-bootstrap 프로세스가
/// 승자가 되도록 규칙 변경.
///
/// 판정 규칙 (`XPC_SERVICE_NAME` 이 서비스 label 인지로 launchd-spawned 여부 구분.
/// label 규약은 brew 버전마다 다르므로 `BrewServiceSync.isServiceLabel(_:)` 이 단일 판정 지점 — Issue95):
/// 1. 내가 launchd-spawned 이고 다른 인스턴스가 있으면 → **다른 인스턴스 terminate + 자신 계속 실행**
///    → brew state `started` 로 수렴
/// 2. 내가 launchd-spawned 가 아니고 다른 인스턴스가 있으면 → **자신 exit(0)**
///    → 기존 open 기동분 보존 (brew 측에서 수동 start 한 경우 등)
enum SingleInstanceGuard {

    /// What an instance does about the other running instances of its bundle ID.
    enum Decision: Equatable {
        case stay             // alone, or the others yield to me
        case terminateOthers  // launchd-spawned winner
        case exitSelf         // loser
    }

    /// Single decision point for the launch-time check and the delayed rechecks (Issue131).
    ///
    /// At launch every other instance is older, so a non-launchd instance always yields. On a
    /// recheck the others may be same-instant siblings, so a non-launchd instance yields only to an
    /// older (lower) PID — of two same-instant `open` launches exactly one survives, never zero.
    static func decide(iAmLaunchd: Bool, myPID: pid_t, otherPIDs: [pid_t], atLaunch: Bool) -> Decision {
        guard !otherPIDs.isEmpty else { return .stay }
        if iAmLaunchd { return .terminateOthers }
        if atLaunch { return .exitSelf }
        return otherPIDs.contains(where: { $0 < myPID }) ? .exitSelf : .stay
    }

    /// `true` 반환 시 호출부는 즉시 `exit(0)` 수행.
    /// 내가 승자(launchd-spawned) 인 경우 false 반환 + 다른 인스턴스 비동기 종료.
    static func shouldTerminateAsDuplicate() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return false
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = otherInstances(bundleID: bundleID, myPID: myPID)
        let pids = others.map(\.processIdentifier)

        switch decide(iAmLaunchd: isLaunchedByLaunchd(), myPID: myPID, otherPIDs: pids, atLaunch: true) {
        case .stay:
            return false
        case .terminateOthers:
            // 승자 경로: 기존 open-기동 프로세스들을 terminate 하고 자신이 survive.
            logW("[single-instance] launchd-spawned (PID \(myPID)) — 기존 인스턴스 terminate (PIDs: \(pids))")
            terminate(others)
            return false
        case .exitSelf:
            // 패자 경로: 기존 인스턴스 유지, 자신 exit.
            logW("[single-instance] non-launchd (PID \(myPID)) — 기존 인스턴스 유지 (PIDs: \(pids)), 자신 exit")
            others.first?.activate()
            return true
        }
    }

    // MARK: - Delayed recheck (Issue131)

    /// Seams for the recheck — `live` uses NSRunningApplication, `exit(0)` and the caller's REST rebind.
    struct RecheckEnvironment {
        var isLaunchedByLaunchd: () -> Bool
        var myPID: pid_t
        var otherPIDs: () -> [pid_t]
        var terminateOthers: ([pid_t]) -> Void
        var exitSelf: () -> Void
        /// Called after the duplicates are gone — the loser may have held the REST port.
        var rebindREST: () -> Void

        static func live(rebindREST: @escaping () -> Void) -> RecheckEnvironment {
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let myPID = ProcessInfo.processInfo.processIdentifier
            return RecheckEnvironment(
                isLaunchedByLaunchd: { SingleInstanceGuard.isLaunchedByLaunchd() },
                myPID: myPID,
                otherPIDs: { otherInstances(bundleID: bundleID, myPID: myPID).map(\.processIdentifier) },
                terminateOthers: { pids in
                    let others = otherInstances(bundleID: bundleID, myPID: myPID)
                        .filter { pids.contains($0.processIdentifier) }
                    terminate(others)
                },
                exitSelf: {
                    Logger.shared.flush()
                    exit(0)
                },
                rebindREST: rebindREST
            )
        }
    }

    /// Runs the same rule again after launch. A same-instant sibling that was not registered yet
    /// at launch (TOCTOU) is visible now.
    @discardableResult
    static func recheck(_ env: RecheckEnvironment) -> Decision {
        let pids = env.otherPIDs()
        let decision = decide(iAmLaunchd: env.isLaunchedByLaunchd(), myPID: env.myPID,
                              otherPIDs: pids, atLaunch: false)
        switch decision {
        case .stay:
            break
        case .terminateOthers:
            logW("[single-instance] 재확인 — launchd 승자 (PID \(env.myPID)), 늦게 보인 인스턴스 terminate (PIDs: \(pids)) 후 REST 재bind")
            env.terminateOthers(pids)
            env.rebindREST()
        case .exitSelf:
            logW("[single-instance] 재확인 — 패자 (PID \(env.myPID)), 우선 인스턴스 유지 (PIDs: \(pids)), 자신 exit")
            env.exitSelf()
        }
        return decision
    }

    /// Schedules one recheck per delay on the main queue.
    static func scheduleRechecks(delays: [TimeInterval], environment: RecheckEnvironment) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                recheck(environment)
            }
        }
    }

    /// True when another instance of this bundle is still alive — the caller is quitting as a retired
    /// duplicate, so it must not stop the brew service the survivor runs under (Issue135).
    static func hasLiveSibling() -> Bool {
        let myPID = ProcessInfo.processInfo.processIdentifier
        return otherInstances(bundleID: Bundle.main.bundleIdentifier ?? "", myPID: myPID)
            .contains { kill($0.processIdentifier, 0) == 0 }
    }

    private static func otherInstances(bundleID: String, myPID: pid_t) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
    }

    private static func terminate(_ others: [NSRunningApplication]) {
        let apps = Dictionary(others.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        let ops = TerminationOps(
            terminate: { apps[$0]?.terminate() ?? true },
            forceTerminate: { pid in
                logW("[single-instance] ⚠️ PID \(pid) 가 종료 요청에 응답하지 않음(모달 표시 중 등) — forceTerminate")
                apps[pid]?.forceTerminate()
            },
            // kill(0), not isTerminated — that flag is updated on the run loop, which this wait blocks
            isAlive: { kill($0, 0) == 0 },
            sleep: { Thread.sleep(forTimeInterval: $0) }
        )
        // REST 포트 3016 bind 경합 방지 — 기존 프로세스가 실제 종료될 때까지 대기 (요청 3초 + 강제 2초).
        let survivors = terminateAndWait(Array(apps.keys), politeTimeout: 3.0, ops: ops)
        if survivors.isEmpty {
            logI("[single-instance] 기존 인스턴스 종료 확인")
        } else {
            logW("[single-instance] ⚠️ 강제 종료 뒤에도 남은 인스턴스 (PIDs: \(survivors)) — 포트 충돌 가능")
        }
    }

    // MARK: - Termination escalation (Issue131 ②)

    /// Seams for `terminateAndWait` — production wraps NSRunningApplication.
    struct TerminationOps {
        var terminate: (pid_t) -> Bool
        var forceTerminate: (pid_t) -> Void
        var isAlive: (pid_t) -> Bool
        var sleep: (TimeInterval) -> Void
    }

    /// Asks each instance to quit, then force-terminates whoever is still alive after `politeTimeout`.
    ///
    /// An instance running a modal alert (the accessibility guide's `runModal`) accepts the request —
    /// `terminate()` returns true — but does not quit until the alert closes. Relying on the return
    /// value alone left both instances up (jma E2E 0/10). Returns the PIDs still alive at the end.
    @discardableResult
    static func terminateAndWait(_ pids: [pid_t], politeTimeout: TimeInterval, ops: TerminationOps) -> [pid_t] {
        for pid in pids where !ops.terminate(pid) {
            ops.forceTerminate(pid)
        }
        let step: TimeInterval = 0.1
        func waitAll(_ timeout: TimeInterval) -> [pid_t] {
            var waited: TimeInterval = 0
            while true {
                let alive = pids.filter(ops.isAlive)
                if alive.isEmpty || waited >= timeout { return alive }
                ops.sleep(step)
                waited += step
            }
        }
        let stubborn = waitAll(politeTimeout)
        guard !stubborn.isEmpty else { return [] }
        stubborn.forEach(ops.forceTerminate)
        return waitAll(2.0)
    }

    /// Issue95: label 규약(`homebrew.mxcl.*` / `sh.brew.*`)을 여기서 다시 판정하지 않는다.
    /// 규약이 바뀌면 이 판정만 빗나가 중복 인스턴스 승패가 뒤집히므로 단일 지점에 위임한다.
    private static func isLaunchedByLaunchd() -> Bool {
        return BrewServiceSync.isLaunchedByLaunchd()
    }
}
