import AppKit
import CoreGraphics

/// CGGetActiveDisplayList 순서 기반 디스플레이 번호 유틸리티
enum DisplayNumberHelper {

    /// CGGetActiveDisplayList가 반환하는 순서대로 정렬된 CGDirectDisplayID 배열
    private static var activeDisplayIDs: [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
        return Array(displayIDs.prefix(Int(displayCount)))
    }

    /// NSScreen에서 CGDirectDisplayID 추출
    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// NSScreen의 시스템 디스플레이 번호 (1-based, CGGetActiveDisplayList 순서)
    static func displayNumber(for screen: NSScreen) -> Int {
        guard let screenID = displayID(for: screen) else { return 0 }
        let ids = activeDisplayIDs
        if let index = ids.firstIndex(of: screenID) {
            return index + 1
        }
        return 0
    }

    /// NSScreen.screens를 CGGetActiveDisplayList 순서로 정렬하여 (번호, CG좌표 프레임) 쌍 반환
    static func orderedScreenFrames() -> [(number: Int, frame: CGRect)] {
        guard let mainScreen = NSScreen.screens.first else { return [] }
        let mainHeight = mainScreen.frame.height

        return NSScreen.screens.compactMap { screen -> (number: Int, frame: CGRect)? in
            let num = displayNumber(for: screen)
            guard num > 0 else { return nil }
            let f = screen.frame
            let cgFrame = CGRect(x: f.origin.x,
                                 y: mainHeight - f.origin.y - f.height,
                                 width: f.width,
                                 height: f.height)
            return (number: num, frame: cgFrame)
        }.sorted { $0.number < $1.number }
    }

    /// 메인 디스플레이의 메뉴바 영역 (CG좌표계). 메뉴바가 없으면 nil
    static func menuBarRect() -> CGRect? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let frame = mainScreen.frame
        let visibleFrame = mainScreen.visibleFrame
        // 메뉴바 높이 = 전체 높이 - 가시 영역 상단 (NSScreen 좌표계에서)
        let menuBarHeight = (visibleFrame.origin.y + visibleFrame.height) < (frame.origin.y + frame.height)
            ? (frame.origin.y + frame.height) - (visibleFrame.origin.y + visibleFrame.height)
            : 0
        guard menuBarHeight > 0 else { return nil }
        // CG좌표: 메인 스크린은 항상 y=0부터 시작, 메뉴바는 상단
        return CGRect(x: frame.origin.x, y: 0, width: frame.width, height: menuBarHeight)
    }

    /// 디스플레이 번호(1-based)로 CGDirectDisplayID 반환
    static func cgDisplayID(forNumber number: Int) -> CGDirectDisplayID? {
        let ids = activeDisplayIDs
        guard number >= 1, number <= ids.count else { return nil }
        return ids[number - 1]
    }

    /// 좌표 (CG 좌표계)가 위치한 스크린의 디스플레이 번호 (1-based, 못 찾으면 nil)
    static func screenNumber(at point: CGPoint) -> Int? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainHeight = mainScreen.frame.height

        for screen in NSScreen.screens {
            let f = screen.frame
            let cgFrame = CGRect(x: f.origin.x,
                                 y: mainHeight - f.origin.y - f.height,
                                 width: f.width,
                                 height: f.height)
            if cgFrame.contains(point) {
                return displayNumber(for: screen)
            }
        }
        return nil
    }
}
