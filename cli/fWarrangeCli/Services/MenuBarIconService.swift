import Foundation
import AppKit

/// Menu bar icon factory (Issue217 Phase 2 — extracted from AppState).
/// Static factory only; observation/state transitions remain in AppState.
enum MenuBarIconService {
    /// cliApp default menu bar icon: rectangle.3.group with diagonal clip.
    static func makeCLIIcon() -> NSImage {
        let symbol = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "fWarrange")!
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let clip = NSBezierPath()
            clip.move(to: NSPoint(x: 0, y: rect.height))
            clip.line(to: NSPoint(x: rect.width, y: rect.height))
            clip.line(to: NSPoint(x: rect.width, y: rect.height * 0.4))
            clip.line(to: NSPoint(x: 0, y: 0))
            clip.close()
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            symbol.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Menu bar icon while paidApp is active: rectangle.3.group full template.
    static func makePaidAppActiveIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let img = (NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "fWarrange")?
            .withSymbolConfiguration(config))
            ?? NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "fWarrange")!
        img.isTemplate = true
        return img
    }
}
