import Foundation
import AppKit

/// Issue81: 시스템 슬립/화면 잠금 시 현재 레이아웃을 자동 캡처하는 코디네이터.
///
/// - 트리거: `NSWorkspace.willSleepNotification`(시스템 슬립) + `com.apple.screenIsLocked`(화면 잠금)
/// - 게이트: `autoSaveOnSleep == true` 일 때만 캡처
/// - 디바운스: 슬립·잠금이 근접 발생해도 마지막 캡처 후 `debounceInterval` 이내면 무시
/// - 캡처본: `auto-yyyy-MM-dd-N` 이름으로 저장 → `isAuto` 표식 + retentionDays 자동 삭제 대상
@MainActor
final class AutoCaptureCoordinator {
    private let windowManager: WindowManager
    private let layoutManager: LayoutManager
    /// 최신 설정을 디스크에서 조회하는 클로저 (REST PATCH 로 갱신된 값을 반영하기 위함)
    private let settingsProvider: () -> AppSettings

    /// 디바운스 간격(초) — 슬립+잠금 근접 발생 시 중복 캡처 방지
    private let debounceInterval: TimeInterval = 5

    private var lastCaptureAt: Date?
    private var observers: [NSObjectProtocol] = []
    private var started = false

    init(
        windowManager: WindowManager,
        layoutManager: LayoutManager,
        settingsProvider: @escaping () -> AppSettings
    ) {
        self.windowManager = windowManager
        self.layoutManager = layoutManager
        self.settingsProvider = settingsProvider
    }

    /// 슬립/잠금 알림 구독 시작 (멱등 — 중복 호출 시 1회만 등록)
    func start() {
        guard !started else { return }
        started = true

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleDeactivation(trigger: "sleep")
            }
        }
        observers.append(sleepObserver)

        // 화면 잠금은 NSWorkspace 가 아닌 DistributedNotificationCenter 로 전달됨
        let lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleDeactivation(trigger: "lock")
            }
        }
        observers.append(lockObserver)

        logI("🌙 AutoCaptureCoordinator 구독 시작 (슬립/잠금 자동 캡처)")
    }

    /// 구독 해제
    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let distributedCenter = DistributedNotificationCenter.default()
        for obs in observers {
            workspaceCenter.removeObserver(obs)
            distributedCenter.removeObserver(obs)
        }
        observers.removeAll()
        started = false
    }

    /// 비활성화(슬립/잠금) 트리거 처리 — 게이트·디바운스 확인 후 캡처
    private func handleDeactivation(trigger: String) {
        let settings = settingsProvider()
        guard settings.autoSaveOnSleep ?? true else {
            logD("자동 캡처 skip (autoSaveOnSleep=false), trigger=\(trigger)")
            return
        }

        // 디바운스: 마지막 캡처 후 debounceInterval 이내면 무시
        let now = Date()
        if let last = lastCaptureAt, now.timeIntervalSince(last) < debounceInterval {
            logD("자동 캡처 디바운스 skip (trigger=\(trigger))")
            return
        }

        let windows = windowManager.captureCurrentWindows(filterApps: nil)
        guard !windows.isEmpty else {
            logW("자동 캡처 skip — 캡처된 윈도우 없음 (trigger=\(trigger))")
            return
        }

        let name = layoutManager.nextAutoCaptureName(date: now)
        do {
            try layoutManager.saveLayout(name: name, windows: windows)
            lastCaptureAt = now
            logI("🌙 자동 캡처 완료: \(name) (\(windows.count)개 윈도우, trigger=\(trigger))")
        } catch {
            logE("자동 캡처 저장 실패: \(name) — \(error)")
            return
        }

        // 보관 기간 초과분 정리
        layoutManager.cleanupExpiredAutoCaptures(retentionDays: settings.retentionDays ?? 7, now: now)
    }
}
