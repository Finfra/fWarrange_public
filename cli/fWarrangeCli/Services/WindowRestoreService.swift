import Foundation
import AppKit

// _AXUIElementGetWindow 선언은 Utils/AXPrivateAPI.swift에 위치

// MARK: - 스레드 안전한 사용 창 추적

private actor UsedWindowsActor {
    var windows: [AXUIElement] = []
    func append(_ window: AXUIElement) { windows.append(window) }
    func contains(_ window: AXUIElement) -> Bool {
        windows.contains(where: { CFEqual($0, window) })
    }
}

// MARK: - 앱 매칭 헬퍼 (Issue71)

/// 앱 매칭 우선순위:
/// 1순위 — `bundleIdentifier` 정확 일치 (가장 안정적, OS·언어·표시명 변경 무관)
/// 2순위 — 다중 이름 후보(localizedName, bundleURL .app 제거 형식, executableURL 파일명)에 대한
///         정확 일치 또는 양방향 prefix 일치 (구 yml 호환 fallback)
///
/// 배경: CGWindowList의 `kCGWindowOwnerName`(yml `app` 필드)과 `NSRunningApplication.localizedName`이
/// 다른 앱이 존재함. ex) VSCode: ownerName="Visual Studio Code" / localizedName="Code".
/// 이름 기반 매칭은 휴리스틱이므로 bundleId가 있으면 항상 우선.
fileprivate func appMatches(_ app: NSRunningApplication, targetApp: String, targetBundleId: String?) -> Bool {
    // 1순위: bundleIdentifier 정확 일치
    if let bid = targetBundleId, !bid.isEmpty,
       let appBid = app.bundleIdentifier, !appBid.isEmpty,
       appBid == bid {
        return true
    }

    // 2순위: 다중 이름 후보 매칭 (구 yml — bundleId 없는 데이터 — 호환)
    let candidates: [String] = [
        app.localizedName,
        app.bundleURL?.deletingPathExtension().lastPathComponent,
        app.executableURL?.lastPathComponent
    ].compactMap { $0 }.filter { !$0.isEmpty }

    for name in candidates {
        if name == targetApp { return true }
        if name.hasPrefix(targetApp) || targetApp.hasPrefix(name) { return true }
    }
    return false
}

/// `WindowInfo` 편의 오버로드 — 매칭 시 항상 bundleId+app 둘 다 사용
fileprivate func appMatches(_ app: NSRunningApplication, window: WindowInfo) -> Bool {
    appMatches(app, targetApp: window.app, targetBundleId: window.bundleId)
}

// MARK: - 실패 원인 분류

private enum RestoreFailureReason: Sendable {
    case noAppRunning       // 실행 중인 앱이 없음 → 재시도 의미 있음 (앱 시작 대기)
    case noWindowMatch      // 앱은 있지만 매칭 창 없음 → 재시도 의미 있음
    case axAPIError         // AX API 호출 실패 → 재시도 의미 있음
    case verifyFailed       // 매칭+설정 성공, 검증만 실패 → 1회 재설정 후 포기
}

// MARK: - 프로토콜

nonisolated protocol WindowRestoreService {
    /// `mode`(Issue72_5, Phase 5): MatchMode (strict/normal/loose). 호출별 정책 결정.
    /// 본 인자는 호출 단위 기본 모드. 개별 `WindowInfo.matchMode`가 지정되면 그 창 한정으로 override.
    /// `minimumScore`는 normal 모드 한정으로 사용자 설정값을 반영. strict/loose는 mode 정책의 고정값 사용.
    func restoreWindows(
        _ windows: [WindowInfo],
        maxRetries: Int,
        retryInterval: Double,
        minimumScore: Int,
        enableParallel: Bool,
        mode: MatchMode,
        onProgress: @MainActor @Sendable (Double, String) -> Void
    ) async -> [WindowMatchResult]
}

// MARK: - 전역 최적 매칭 결과

private struct MatchAssignment: @unchecked Sendable {
    nonisolated(unsafe) let axWindow: AXUIElement
    let score: Int
    let matchType: MatchType
    let title: String
}

// MARK: - 구현체

final class AXWindowRestoreService: WindowRestoreService {

    /// AX 메시징 타임아웃 (초) - 응답 없는 앱 대기 제한
    private let axTimeout: Float = 0.5

    /// Issue72_3 (Phase 3): 타이틀 정규화 서비스. axTitle 비교 전 동일 정규화 적용.
    /// 옵셔널 — 미주입 시 원본 비교 (Phase 1·2 호환).
    private let titleNormalizer: TitleNormalizer?
    /// Issue72_4 (Phase 4): areaMatch(30점, 면적 유사도) 활성 여부.
    /// false 시 30점 매칭 케이스가 노이즈 매칭으로 분류되어 .noMatch 처리됨.
    /// 베이스라인 통계에서 areaMatch 비율이 높으면 false로 전환 검토.
    private let areaMatchEnabled: Bool

    init(titleNormalizer: TitleNormalizer? = nil, areaMatchEnabled: Bool = true) {
        self.titleNormalizer = titleNormalizer
        self.areaMatchEnabled = areaMatchEnabled
    }

    nonisolated func restoreWindows(
        _ windows: [WindowInfo],
        maxRetries: Int,
        retryInterval: Double,
        minimumScore: Int,
        enableParallel: Bool,
        mode: MatchMode,
        onProgress: @MainActor @Sendable (Double, String) -> Void
    ) async -> [WindowMatchResult] {
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        // Issue72_5 (Phase 5): mode → RuntimeMatchPolicy 변환. minimumScore는 normal에서만 반영.
        let basePolicy = RuntimeMatchPolicy.from(
            mode: mode,
            settingsMinimumScore: minimumScore,
            areaMatchSettingEnabled: self.areaMatchEnabled
        )
        logI("[복구 시작] 창 \(windows.count)개, mode=\(mode.rawValue), minimumScore=\(basePolicy.minimumScore), 기하폴백=\(basePolicy.geometricFallbackEnabled), area=\(basePolicy.areaMatchEnabled), 1:N=\(basePolicy.allowMultipleAssignments), moom=\(basePolicy.moomFallbackEnabled), maxRetries=\(maxRetries), interval=\(retryInterval)초, 병렬=\(enableParallel)")

        var pendingWindows = windows
        var allResults: [WindowMatchResult] = []
        var currentAttempt = 1

        while !pendingWindows.isEmpty && currentAttempt <= maxRetries {
            let attemptStartTime = CFAbsoluteTimeGetCurrent()
            logI("[시도 \(currentAttempt)/\(maxRetries)] 남은 창: \(pendingWindows.count)개")

            if currentAttempt > 1 {
                try? await Task.sleep(for: .seconds(retryInterval))
                let sleepElapsed = CFAbsoluteTimeGetCurrent() - attemptStartTime
                logD("[시도 \(currentAttempt)] sleep 완료 - \(String(format: "%.3f", sleepElapsed))초")
            }

            let total = windows.count
            let done = total - pendingWindows.count
            let progress = Double(done) / Double(total)
            let progressMessage = "시도 \(currentAttempt)/\(maxRetries)"
            await onProgress(progress, progressMessage)

            let runningApps = await MainActor.run {
                NSWorkspace.shared.runningApplications
            }
            var nextPending: [WindowInfo] = []
            let isLastAttempt = (currentAttempt == maxRetries)

            if enableParallel {
                let appGroups = Dictionary(grouping: pendingWindows) { $0.app }
                logD("[시도 \(currentAttempt)] 병렬 처리 - 앱 \(appGroups.count)개")
                let usedActor = UsedWindowsActor()

                var parallelResults: [WindowMatchResult] = []
                var parallelPending: [WindowInfo] = []

                await withTaskGroup(of: ([WindowMatchResult], [WindowInfo]).self) { group in
                    for (_, appWindows) in appGroups {
                        let lastAttempt = isLastAttempt
                        group.addTask { [self] in
                            let appName = appWindows.first?.app ?? "unknown"
                            // 같은 ownerName 그룹은 같은 PID·같은 bundleId 가정 (CGWindow 특성)
                            let groupBundleId = appWindows.first?.bundleId
                            let appTaskStart = CFAbsoluteTimeGetCurrent()

                            var appResults: [WindowMatchResult] = []
                            var appPending: [WindowInfo] = []

                            // 앱 찾기 (Issue71: bundleId 우선 + 다중 식별자 매칭)
                            let matchedApps = runningApps.filter {
                                appMatches($0, targetApp: appName, targetBundleId: groupBundleId)
                            }

                            if matchedApps.isEmpty {
                                appPending = appWindows
                            } else {
                                // AX 창 수집
                                var axWindows: [AXUIElement] = []
                                for app in matchedApps {
                                    axWindows.append(contentsOf: self.getAXWindows(for: app))
                                }

                                // usedActor로 이미 사용된 창 필터링
                                var filteredWindows: [AXUIElement] = []
                                for axWindow in axWindows {
                                    if !(await usedActor.contains(axWindow)) {
                                        filteredWindows.append(axWindow)
                                    }
                                }

                                if filteredWindows.isEmpty {
                                    appPending = appWindows
                                } else {
                                    // 전역 최적 매칭 (Issue167: 복수 창 위치 뒤바뀜 방지)
                                    let matches = self.findOptimalMatches(
                                        targets: appWindows, axWindows: filteredWindows,
                                        usedWindows: [], minimumScore: basePolicy.minimumScore,
                                        policy: basePolicy
                                    )

                                    for (i, target) in appWindows.enumerated() {
                                        if let match = matches[i] {
                                            let (success, _) = self.applyAndVerify(target: target, axWindow: match.axWindow)
                                            await usedActor.append(match.axWindow)

                                            if success {
                                                logD("[복구] '\(target.app)'/'\(match.title)' score=\(match.score) \(match.matchType) 성공")
                                                appResults.append(WindowMatchResult(targetWindow: target, matchedTitle: match.title, matchType: match.matchType, score: match.score, success: true))
                                            } else if lastAttempt {
                                                logW("[복구] '\(target.app)' 검증 실패 → 마지막 시도, best-effort 성공 처리")
                                                appResults.append(WindowMatchResult(targetWindow: target, matchedTitle: match.title, matchType: match.matchType, score: match.score, success: true))
                                            } else {
                                                logW("[복구] '\(target.app)' 검증 실패 → 재시도 대상 유지 (시도 \(currentAttempt)/\(maxRetries))")
                                                appPending.append(target)
                                            }
                                        } else {
                                            appPending.append(target)
                                        }
                                    }
                                }
                            }

                            let appElapsed = CFAbsoluteTimeGetCurrent() - appTaskStart
                            logI("[복구] '\(appName)' - 성공: \(appResults.count), 대기: \(appPending.count), \(String(format: "%.3f", appElapsed))초")
                            return (appResults, appPending)
                        }
                    }

                    for await (results, pending) in group {
                        parallelResults.append(contentsOf: results)
                        parallelPending.append(contentsOf: pending)
                    }
                }

                allResults.append(contentsOf: parallelResults)
                nextPending = parallelPending
            } else {
                var usedWindows: [AXUIElement] = []

                // 앱별 배치 매칭으로 같은 앱 복수 창 위치 뒤바뀜 방지 (Issue167)
                let seqAppGroups = Dictionary(grouping: pendingWindows, by: { $0.app })

                for (appName, appTargets) in seqAppGroups {
                    // Issue71: bundleId 우선 + 다중 식별자 매칭
                    let seqBundleId = appTargets.first?.bundleId
                    let matchedApps = runningApps.filter {
                        appMatches($0, targetApp: appName, targetBundleId: seqBundleId)
                    }

                    guard !matchedApps.isEmpty else {
                        for target in appTargets {
                            logD("[매칭] '\(target.app)' 앱 미실행")
                            nextPending.append(target)
                        }
                        continue
                    }

                    var axWindows: [AXUIElement] = []
                    for app in matchedApps {
                        axWindows.append(contentsOf: getAXWindows(for: app))
                    }

                    guard !axWindows.isEmpty else {
                        for target in appTargets {
                            logD("[매칭] '\(target.app)' AX 창 목록 없음")
                            nextPending.append(target)
                        }
                        continue
                    }

                    // 전역 최적 매칭 (Issue167)
                    let matches = findOptimalMatches(
                        targets: appTargets, axWindows: axWindows,
                        usedWindows: usedWindows, minimumScore: basePolicy.minimumScore,
                        policy: basePolicy
                    )

                    for (i, target) in appTargets.enumerated() {
                        if let match = matches[i] {
                            let (success, _) = applyAndVerify(target: target, axWindow: match.axWindow)
                            usedWindows.append(match.axWindow)

                            if success {
                                logD("[복구] '\(target.app)'/'\(match.title)' score=\(match.score) \(match.matchType) 성공")
                                allResults.append(WindowMatchResult(targetWindow: target, matchedTitle: match.title, matchType: match.matchType, score: match.score, success: true))
                            } else if isLastAttempt {
                                logW("[복구] '\(target.app)' 검증 실패 → 마지막 시도, best-effort 성공 처리")
                                allResults.append(WindowMatchResult(targetWindow: target, matchedTitle: match.title, matchType: match.matchType, score: match.score, success: true))
                            } else {
                                logW("[복구] '\(target.app)' 검증 실패 → 재시도 대상 유지 (시도 \(currentAttempt)/\(maxRetries))")
                                nextPending.append(target)
                            }
                        } else {
                            nextPending.append(target)
                        }
                    }
                }
            }

            let attemptElapsed = CFAbsoluteTimeGetCurrent() - attemptStartTime
            let succeeded = pendingWindows.count - nextPending.count
            logI("[시도 \(currentAttempt)/\(maxRetries) 완료] 성공: \(succeeded), 남은: \(nextPending.count), \(String(format: "%.3f", attemptElapsed))초")

            // 시도 전후 변화 없으면 조기 종료 검토
            // 단, 최소 2회는 시도 (첫 시도에서 AX API 미준비로 전체 실패할 수 있음)
            if succeeded == 0 && !nextPending.isEmpty && currentAttempt >= 2 {
                logI("[조기 종료] 시도 \(currentAttempt)에서 변화 없음 → 리트라이 중단")
                pendingWindows = nextPending
                break
            } else if succeeded == 0 && !nextPending.isEmpty {
                logI("[재시도 유지] 시도 \(currentAttempt)에서 변화 없으나 최소 시도 횟수 미달 → 재시도 계속")
            }

            pendingWindows = nextPending

            // 남은 창이 모두 앱 미실행 상태인지 확인 → 조기 종료
            // Issue71: bundleId 우선 + 다중 식별자 매칭으로 VSCode 등 ownerName ↔ localizedName 불일치 흡수
            if !pendingWindows.isEmpty {
                let allAppsNotRunning = pendingWindows.allSatisfy { target in
                    !runningApps.contains(where: { appMatches($0, window: target) })
                }
                if allAppsNotRunning {
                    let missingApps = Set(pendingWindows.map { $0.app })
                    logI("[조기 종료] 남은 창의 앱이 모두 미실행 상태: \(missingApps.joined(separator: ", "))")
                    break
                }
            }

            currentAttempt += 1
        }

        // Issue72_5 (Phase 5): Moom 스타일 최후 폴백 (loose 모드 전용)
        // 매칭 실패한 target 들을 앱별로 그룹핑하고, 같은 앱의 살아있는 창 개수가 같으면
        // windowOrder 순으로 위치 배분. "내용은 모르겠지만 자리는 맞춰주기" 시나리오.
        if basePolicy.moomFallbackEnabled && !pendingWindows.isEmpty {
            let runningApps = await MainActor.run { NSWorkspace.shared.runningApplications }
            let pendingByApp = Dictionary(grouping: pendingWindows, by: { $0.app })
            for (appName, appTargets) in pendingByApp {
                let bundleId = appTargets.first?.bundleId
                let matchedApps = runningApps.filter {
                    appMatches($0, targetApp: appName, targetBundleId: bundleId)
                }
                guard !matchedApps.isEmpty else { continue }
                var axWindows: [AXUIElement] = []
                for app in matchedApps {
                    axWindows.append(contentsOf: getAXWindows(for: app))
                }
                // 앱별 창 개수 일치 검증
                guard axWindows.count == appTargets.count else {
                    logD("[Moom 폴백] '\(appName)' 창 개수 불일치 (target=\(appTargets.count), ax=\(axWindows.count)) — 스킵")
                    continue
                }
                // target은 windowOrder 오름차순, ax는 현재 onscreen 순서(getAXWindows 반환 순)로 배분
                let sortedTargets = appTargets.sorted { (lhs, rhs) in
                    (lhs.windowOrder ?? Int.max) < (rhs.windowOrder ?? Int.max)
                }
                for (idx, target) in sortedTargets.enumerated() {
                    let axWindow = axWindows[idx]
                    let (success, _) = applyAndVerify(target: target, axWindow: axWindow)
                    if success {
                        logI("[Moom 폴백] '\(appName)' #\(idx) (windowOrder=\(target.windowOrder ?? -1)) 배분 성공")
                        allResults.append(WindowMatchResult(
                            targetWindow: target,
                            matchedTitle: "(moom-fallback)",
                            matchType: .noMatch,
                            score: 0,
                            success: true
                        ))
                        // pendingWindows에서 제거
                        pendingWindows.removeAll { CFEqual($0 as AnyObject, target as AnyObject) || ($0.id == target.id && $0.app == target.app && $0.window == target.window) }
                    }
                }
            }
        }

        // 실패한 창도 결과에 추가
        for remaining in pendingWindows {
            allResults.append(WindowMatchResult(
                targetWindow: remaining,
                matchedTitle: "",
                matchType: .noMatch,
                score: 0,
                success: false
            ))
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - totalStartTime
        let succeeded = allResults.filter { $0.success }.count
        logI("[복구 완료] 성공: \(succeeded)/\(allResults.count), 총 \(String(format: "%.3f", totalElapsed))초")

        return allResults
    }

    // MARK: - AX 창 목록 획득

    /// 앱의 AX 창 목록을 가져온다 (kAXWindowsAttribute → kAXChildrenAttribute 폴백)
    private nonisolated func getAXWindows(for app: NSRunningApplication) -> [AXUIElement] {
        if app.isHidden { app.unhide() }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, axTimeout)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        if result == .success, let windows = value as? [AXUIElement], !windows.isEmpty {
            return windows
        }

        // 폴백: kAXChildrenAttribute에서 AXWindow Role 필터링 (Finder, Chrome 등)
        var childValue: CFTypeRef?
        let childResult = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childValue)
        if childResult == .success, let children = childValue as? [AXUIElement] {
            return children.filter { child in
                var roleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
                return (roleValue as? String) == "AXWindow"
            }
        }

        return []
    }

    // MARK: - 단일 (target, axWindow) 매칭 점수 계산

    private nonisolated func computeMatchScore(
        target: WindowInfo,
        axWindow: AXUIElement,
        policy: RuntimeMatchPolicy
    ) -> (score: Int, matchType: MatchType, title: String, distance: Double, cgWindowId: CGWindowID) {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        let axTitleRaw = titleValue as? String ?? ""
        // Issue72_3 (Phase 3): axTitle을 정규화하여 캡처 시점에 정규화된 target.window와 비교.
        // normalizer가 없으면 원본 그대로 (Phase 1·2 동작 유지).
        let axTitle: String
        if let normalizer = titleNormalizer {
            axTitle = normalizer.normalize(title: axTitleRaw, bundleId: target.bundleId, app: target.app)
        } else {
            axTitle = axTitleRaw
        }

        var cgWindowId: CGWindowID = 0
        _ = _AXUIElementGetWindow(axWindow, &cgWindowId)

        // 현재 창 위치 읽기 (동점 해소용)
        var posValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
        var currentPos = CGPoint.zero
        if let posV = posValue, CFGetTypeID(posV) == AXValueGetTypeID() {
            AXValueGetValue(posV as! AXValue, .cgPoint, &currentPos)
        }

        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)
        var currentSize = CGSize.zero
        if let sizeV = sizeValue, CFGetTypeID(sizeV) == AXValueGetTypeID() {
            AXValueGetValue(sizeV as! AXValue, .cgSize, &currentSize)
        }

        let currentArea = currentSize.width * currentSize.height
        let targetArea = target.size.width * target.size.height

        var score = 0
        var mType: MatchType = .noMatch

        if cgWindowId == target.id && target.id != 0 {
            score = 100; mType = .windowID
        } else if axTitle == target.window && !target.window.isEmpty {
            score = 90; mType = .exactTitle
        } else if !target.window.isEmpty,
                  let regex = try? NSRegularExpression(pattern: target.window, options: .caseInsensitive),
                  regex.firstMatch(in: axTitle, range: NSRange(location: 0, length: axTitle.utf16.count)) != nil {
            score = 80; mType = .regexTitle
        } else if !target.window.isEmpty && axTitle.contains(target.window) {
            score = 70; mType = .containsTitle
        }
        // Issue72_5 (Phase 5): 기하 폴백(60~30점)은 policy.geometricFallbackEnabled 가드.
        // strict 모드(false)에서는 60~30 분기를 모두 .noMatch로 처리.
        else if policy.geometricFallbackEnabled && abs(currentSize.width - target.size.width) < 5 {
            score = 60; mType = .widthMatch
        } else if policy.geometricFallbackEnabled && abs(currentSize.height - target.size.height) < 5 {
            score = 50; mType = .heightMatch
        } else if policy.geometricFallbackEnabled && target.size.height > 0 && currentSize.height > 0 &&
                  abs((currentSize.width / currentSize.height) - (target.size.width / target.size.height)) < 0.05 {
            score = 40; mType = .ratioMatch
        } else if policy.areaMatchEnabled && currentArea > 0 && targetArea > 0 &&
                  abs(currentArea - targetArea) / max(currentArea, targetArea) < 0.05 {
            // Issue72_4 (Phase 4): areaMatchEnabled=false 시 30점 매칭 비활성 → noMatch
            // Issue72_5 (Phase 5): policy.areaMatchEnabled로 통합 (strict=false, loose=true, normal=설정값)
            score = 30; mType = .areaMatch
        }

        let dx = Double(currentPos.x - target.pos.x)
        let dy = Double(currentPos.y - target.pos.y)
        let distance = sqrt(dx * dx + dy * dy)

        // Issue72_4 (Phase 4): 동일 카테고리 내에서 가까운 위치 우선.
        // distance 0px → +9점, 900px+ → 0점. 가산점 상한 9점이므로 카테고리 경계는 보존
        // (예: exactTitle 90 + 9 = 99 < ID 100). noMatch(0)·windowID(100)에는 가산하지 않음.
        if score > 0 && score < 100 {
            let bonus = max(0, 9 - Int(distance / 100))
            score += bonus
        }

        // Issue72_6 (Phase 6-1): spaceId 일치 시 보조 가산점 (+3).
        // 다른 Space의 동명 창과 구분. 비공개 API 실패(nil) 시 가산 안 함.
        // 카테고리 경계 보존 위해 작게 부여 (+3, 상한 99).
        if score > 0 && score < 100, let targetSpace = target.spaceId {
            let axSpace = _spaceIdForCGWindowID(cgWindowId)
            if axSpace == targetSpace {
                score = min(score + 3, 99)
            }
        }

        return (score, mType, axTitle, distance, cgWindowId)
    }

    // MARK: - 복수 창 전역 최적 매칭 (Issue167)

    /// 같은 앱의 복수 타겟에 대해 전역 최적 매칭을 수행한다.
    /// per-target 탐욕 대신 전역 탐욕(score DESC → distance ASC)으로 위치 뒤바뀜을 방지한다.
    private nonisolated func findOptimalMatches(
        targets: [WindowInfo],
        axWindows: [AXUIElement],
        usedWindows: [AXUIElement],
        minimumScore: Int,
        policy: RuntimeMatchPolicy
    ) -> [MatchAssignment?] {
        struct Candidate {
            let targetIdx: Int
            let windowIdx: Int
            let score: Int
            let distance: Double
            let cgWindowId: CGWindowID
            let matchType: MatchType
            let title: String
        }

        // 모든 (target, axWindow) 쌍의 점수 계산
        var candidates: [Candidate] = []
        for (ti, target) in targets.enumerated() {
            for (wi, axWindow) in axWindows.enumerated() {
                if usedWindows.contains(where: { CFEqual($0, axWindow) }) { continue }
                // Issue72_5 (Phase 5): WindowInfo.matchMode가 명시되면 그 창 한정으로 정책 override
                let effectivePolicy: RuntimeMatchPolicy
                if let perTargetMode = target.matchMode, perTargetMode != .normal {
                    effectivePolicy = RuntimeMatchPolicy.from(
                        mode: perTargetMode,
                        settingsMinimumScore: policy.minimumScore,
                        areaMatchSettingEnabled: policy.areaMatchEnabled
                    )
                } else {
                    effectivePolicy = policy
                }
                let (score, matchType, title, distance, cgWinId) = computeMatchScore(target: target, axWindow: axWindow, policy: effectivePolicy)
                if score > 0 {
                    candidates.append(Candidate(
                        targetIdx: ti, windowIdx: wi,
                        score: score, distance: distance, cgWindowId: cgWinId,
                        matchType: matchType, title: title
                    ))
                }
            }
        }

        // 전역 정렬: score 높은 순 → 거리 가까운 순 → Window ID 작은 순 (결정적 순서)
        candidates.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if abs(a.distance - b.distance) > 1.0 { return a.distance < b.distance }
            return a.cgWindowId < b.cgWindowId
        }

        // 전역 탐욕 할당 — 각 target과 window를 최대 1회만 매칭
        // Issue72_5 (Phase 5): loose 모드(allowMultipleAssignments)는 window 1:N 허용
        var assignedTargets = Set<Int>()
        var assignedWindows = Set<Int>()
        var results: [MatchAssignment?] = Array(repeating: nil, count: targets.count)

        for c in candidates {
            guard !assignedTargets.contains(c.targetIdx) else { continue }
            if !policy.allowMultipleAssignments && assignedWindows.contains(c.windowIdx) { continue }
            guard c.score >= minimumScore else { continue }
            assignedTargets.insert(c.targetIdx)
            assignedWindows.insert(c.windowIdx)
            results[c.targetIdx] = MatchAssignment(
                axWindow: axWindows[c.windowIdx],
                score: c.score,
                matchType: c.matchType,
                title: c.title
            )
        }

        if targets.count > 1 {
            let matched = results.compactMap { $0 }.count
            logD("[최적매칭] '\(targets.first?.app ?? "")' \(targets.count)개 타겟 → \(matched)개 매칭 (후보 \(candidates.count)개)")
        }

        return results
    }

    // MARK: - 위치/크기 설정 및 검증 (공통)

    private nonisolated func applyAndVerify(
        target: WindowInfo,
        axWindow: AXUIElement
    ) -> (success: Bool, failReason: RestoreFailureReason?) {
        // 1차 설정
        var targetPosition = CGPoint(x: target.pos.x, y: target.pos.y)
        var posResult: AXError = .failure
        if let posValue = AXValueCreate(.cgPoint, &targetPosition) {
            posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        }
        var targetSize = CGSize(width: target.size.width, height: target.size.height)
        var sizeResult: AXError = .failure
        if let sizeValue = AXValueCreate(.cgSize, &targetSize) {
            sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }

        // AX API 호출 자체가 실패한 경우 (권한 없음, API 비활성 등)
        if posResult != .success && sizeResult != .success {
            logW("[복구] AX API 실패 - '\(target.app)' pos:\(posResult.rawValue), size:\(sizeResult.rawValue)")
            return (false, .axAPIError)
        }

        // macOS가 창 위치/크기 변경을 처리할 시간 확보
        usleep(50_000) // 50ms

        // 1차 검증
        if verify(target: target, axWindow: axWindow) {
            return (true, nil)
        }

        // 2차 설정 (위치를 크기 설정 후 다시 설정 - 일부 앱은 크기 변경 시 위치가 밀림)
        if let posValue = AXValueCreate(.cgPoint, &targetPosition) {
            let secondPosResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            if secondPosResult != .success {
                logD("[복구] AX 2차 위치 설정 실패 - '\(target.app)' code:\(secondPosResult.rawValue)")
            }
        }

        // 2차 설정 후에도 처리 시간 확보
        usleep(50_000) // 50ms

        // 2차 검증
        if verify(target: target, axWindow: axWindow) {
            return (true, nil)
        }

        return (false, .verifyFailed)
    }

    private nonisolated func verify(target: WindowInfo, axWindow: AXUIElement) -> Bool {
        var finalPosValue: CFTypeRef?
        var finalSizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &finalPosValue)
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &finalSizeValue)

        var actualPos = CGPoint.zero
        var actualSize = CGSize.zero
        guard let fPos = finalPosValue, CFGetTypeID(fPos) == AXValueGetTypeID() else { return false }
        AXValueGetValue(fPos as! AXValue, .cgPoint, &actualPos)
        guard let fSize = finalSizeValue, CFGetTypeID(fSize) == AXValueGetTypeID() else { return false }
        AXValueGetValue(fSize as! AXValue, .cgSize, &actualSize)

        let posMatch = abs(actualPos.x - target.pos.x) <= 3 && abs(actualPos.y - target.pos.y) <= 3
        let sizeMatch = abs(actualSize.width - target.size.width) <= 3 && abs(actualSize.height - target.size.height) <= 3

        return posMatch && sizeMatch
    }
}
