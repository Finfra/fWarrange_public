import Foundation
import CoreGraphics

struct WindowPosition: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
}

struct WindowSize: Codable, Equatable {
    var width: CGFloat
    var height: CGFloat
}

struct WindowInfo: Identifiable, Codable, Equatable {
    var id: Int
    var app: String
    /// CFBundleIdentifier (Issue71). 안정적 매칭 보조 식별자.
    /// 구 yml 호환을 위해 옵셔널 — nil 이면 이름 기반 fallback 매칭이 사용됨.
    var bundleId: String?
    var window: String
    var layer: Int
    var pos: WindowPosition
    var size: WindowSize

    init(
        id: Int,
        app: String,
        bundleId: String? = nil,
        window: String,
        layer: Int,
        pos: WindowPosition,
        size: WindowSize
    ) {
        self.id = id
        self.app = app
        self.bundleId = bundleId
        self.window = window
        self.layer = layer
        self.pos = pos
        self.size = size
    }
}
