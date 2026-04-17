import Foundation
import AppKit

/// 모드 전환 시 requiredApps에 정의된 앱을 실행/숨김/무시 처리하는 서비스
protocol AppLauncherService {
    /// 여러 앱 설정을 병렬로 적용함. 개별 실패는 로그만 남기고 나머지는 계속 진행함
    func applyAppConfigs(_ apps: [AppConfig]) async
}

/// `NSWorkspace`/`NSRunningApplication` 기반 구현체
final class NSWorkspaceAppLauncherService: AppLauncherService, @unchecked Sendable {

    func applyAppConfigs(_ apps: [AppConfig]) async {
        guard !apps.isEmpty else { return }
        logI("🧩 모드 앱 자동화 시작 (대상 \(apps.count)개)")

        // 병렬 실행 — 개별 실패 허용
        await withTaskGroup(of: Void.self) { group in
            for config in apps {
                group.addTask { [weak self] in
                    await self?.applyOne(config)
                }
            }
        }
        logI("✅ 모드 앱 자동화 완료")
    }

    private func applyOne(_ config: AppConfig) async {
        switch config.action {
        case .launch:
            await launchIfNeeded(bundleId: config.bundleId)
        case .hide:
            hideIfRunning(bundleId: config.bundleId)
        case .ignore:
            break
        }
    }

    /// 이미 실행 중이 아닐 때만 앱 실행. 실행 중이면 skip
    private func launchIfNeeded(bundleId: String) async {
        if isRunning(bundleId: bundleId) {
            logD("↪️ 이미 실행 중 — skip: \(bundleId)")
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            logW("⚠️ 앱을 찾을 수 없음: \(bundleId)")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            logI("🚀 실행: \(bundleId)")
        } catch {
            logW("앱 실행 실패 '\(bundleId)': \(error.localizedDescription)")
        }
    }

    /// 실행 중인 앱이면 숨김. `terminate()`는 사용하지 않음 (데이터 손실 방지)
    private func hideIfRunning(bundleId: String) {
        let matches = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard !matches.isEmpty else {
            logD("↪️ 실행 중 아님 — hide skip: \(bundleId)")
            return
        }
        for app in matches {
            if app.hide() {
                logI("🙈 숨김: \(bundleId) (pid=\(app.processIdentifier))")
            } else {
                logW("⚠️ 숨김 실패: \(bundleId) (pid=\(app.processIdentifier))")
            }
        }
    }

    private func isRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
}
