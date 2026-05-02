import AppKit

enum KeySpecParser {
    /// Converts a shortcut displayString (e.g. "⌘F7", "⌃⇧⌘F7", "⌘Q") to
    /// the (keyEquivalent, modifierMask) pair expected by NSMenuItem.
    /// F1–F19 are mapped to NSFunctionKey unicode scalars (0xF704 + n - 1).
    /// Regular keys are lowercased as NSMenu convention requires.
    static func parse(_ spec: String) -> (key: String, modifiers: NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        var remaining = spec

        while let first = remaining.first {
            switch first {
            case "⌃", "^": modifiers.insert(.control); remaining.removeFirst()
            case "⌥":      modifiers.insert(.option);  remaining.removeFirst()
            case "⇧":      modifiers.insert(.shift);   remaining.removeFirst()
            case "⌘":      modifiers.insert(.command); remaining.removeFirst()
            default:
                return (mapKeyEquivalent(remaining), modifiers)
            }
        }
        return ("", modifiers)
    }

    private static func mapKeyEquivalent(_ rest: String) -> String {
        if let n = parseFKeyNumber(rest), (1...19).contains(n) {
            let scalar = UnicodeScalar(0xF704 + (n - 1))!
            return String(Character(scalar))
        }
        if rest.lowercased() == "space" { return " " }
        return String(rest.prefix(1)).lowercased()
    }

    private static func parseFKeyNumber(_ rest: String) -> Int? {
        guard rest.hasPrefix("F") else { return nil }
        return Int(rest.dropFirst())
    }
}
