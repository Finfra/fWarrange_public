import AppKit
import CoreGraphics

// MARK: - DisplaySwitchService 프로토콜

@MainActor
protocol DisplaySwitchServiceProtocol: AnyObject {
    func switchMainDisplay(to point: NSPoint)
    func registerRightClickMonitor(enabled: Bool)
    func unregisterRightClickMonitor()
}

// MARK: - DisplaySwitchService 구현체

/// 보조 디스플레이에서 우클릭 시 해당 디스플레이를 메인으로 전환하는 서비스
@Observable
@MainActor
final class DisplaySwitchService: DisplaySwitchServiceProtocol {
    private var rightClickMonitor: Any?

    init() {}

    /// 우클릭 글로벌 모니터 등록/해제
    func registerRightClickMonitor(enabled: Bool) {
        unregisterRightClickMonitor()
        guard enabled else {
            logD("DisplaySwitch: 우클릭 모니터 비활성화")
            return
        }

        rightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.switchMainDisplay(to: location)
            }
        }
        logD("DisplaySwitch: 우클릭 모니터 등록 완료")
    }

    func unregisterRightClickMonitor() {
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
            rightClickMonitor = nil
        }
    }

    /// NSEvent.mouseLocation(AppKit 좌표)에서 메인 디스플레이 전환 실행
    func switchMainDisplay(to nsPoint: NSPoint) {
        // 마우스 위치의 스크린 찾기
        guard let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(nsPoint) }) else {
            return
        }

        // 이미 메인 디스플레이면 무시
        guard let mainScreen = NSScreen.screens.first, targetScreen != mainScreen else {
            return
        }

        guard let targetDisplayID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            logE("DisplaySwitch: 타겟 스크린의 displayID를 가져올 수 없음")
            return
        }

        setAsMainDisplay(displayID: targetDisplayID)
    }

    /// CGDisplayConfigRef API로 메인 디스플레이 전환
    /// 타겟을 원점(0,0)에 놓고 나머지를 상대적으로 재배치
    private func setAsMainDisplay(displayID: CGDirectDisplayID) {
        let mainDisplayID = CGMainDisplayID()
        guard displayID != mainDisplayID else { return }

        // 현재 타겟 디스플레이의 위치
        let targetBounds = CGDisplayBounds(displayID)
        let offsetX = targetBounds.origin.x
        let offsetY = targetBounds.origin.y

        var config: CGDisplayConfigRef?
        let beginErr = CGBeginDisplayConfiguration(&config)
        guard beginErr == .success, let config = config else {
            logE("DisplaySwitch: CGBeginDisplayConfiguration 실패: \(beginErr)")
            return
        }

        // 모든 활성 디스플레이를 가져와 offset 보정
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

        for id in displayIDs {
            let bounds = CGDisplayBounds(id)
            let newX = Int32(bounds.origin.x - offsetX)
            let newY = Int32(bounds.origin.y - offsetY)
            let configErr = CGConfigureDisplayOrigin(config, id, newX, newY)
            if configErr != .success {
                logW("DisplaySwitch: display \(id) origin 설정 실패: \(configErr)")
            }
        }

        let completeErr = CGCompleteDisplayConfiguration(config, .permanently)
        if completeErr == .success {
            logI("DisplaySwitch: 메인 디스플레이 전환 완료 (displayID: \(displayID))")
        } else {
            logE("DisplaySwitch: CGCompleteDisplayConfiguration 실패: \(completeErr)")
        }
    }
}
