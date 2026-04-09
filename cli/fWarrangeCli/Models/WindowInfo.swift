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
    var window: String
    var layer: Int
    var pos: WindowPosition
    var size: WindowSize
}
