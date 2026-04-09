import Foundation
import CoreGraphics

// MARK: - ScreenMoveServiceProtocol

@MainActor
protocol ScreenMoveServiceProtocol: AnyObject {
    func moveScreen(screenNumber: Int, delta: CGSize)
}

/// 미니맵에서 스크린 드래그 시 실제 디스플레이 위치를 이동하는 서비스
@Observable
@MainActor
final class ScreenMoveService: ScreenMoveServiceProtocol {
    init() {}

    /// 실제 디스플레이 위치를 delta만큼 이동 (CGConfigureDisplayOrigin)
    func moveScreen(screenNumber: Int, delta: CGSize) {
        guard let displayID = DisplayNumberHelper.cgDisplayID(forNumber: screenNumber) else {
            logE("[ScreenMove] 스크린 \(screenNumber)의 displayID를 찾을 수 없음")
            return
        }

        let currentBounds = CGDisplayBounds(displayID)
        let newX = Int32(currentBounds.origin.x + delta.width)
        let newY = Int32(currentBounds.origin.y + delta.height)

        logD("[ScreenMove] 스크린 \(screenNumber) 이동: (\(currentBounds.origin.x),\(currentBounds.origin.y)) → (\(newX),\(newY))")

        var config: CGDisplayConfigRef?
        let beginErr = CGBeginDisplayConfiguration(&config)
        guard beginErr == .success, let config = config else {
            logE("[ScreenMove] CGBeginDisplayConfiguration 실패: \(beginErr)")
            return
        }

        let configErr = CGConfigureDisplayOrigin(config, displayID, newX, newY)
        guard configErr == .success else {
            logE("[ScreenMove] CGConfigureDisplayOrigin 실패: \(configErr)")
            CGCancelDisplayConfiguration(config)
            return
        }

        // .forSession: 현재 로그인 세션 동안만 유지, 재로그인 시 복원
        // .permanently를 사용하면 미니맵 오조작 시 디스플레이 배치가 영구 변경되므로 사용 금지
        let completeErr = CGCompleteDisplayConfiguration(config, .forSession)
        if completeErr == .success {
            logD("[ScreenMove] 스크린 \(screenNumber) 이동 완료 (세션 한정)")
        } else {
            logE("[ScreenMove] CGCompleteDisplayConfiguration 실패: \(completeErr)")
        }
    }
}
