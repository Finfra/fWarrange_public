import Foundation

enum MatchType: String {
    case windowID = "ID"
    case exactTitle = "Title(Exact)"
    case regexTitle = "Regex"
    case containsTitle = "Title(Contains)"
    case widthMatch = "Width"
    case heightMatch = "Height"
    case ratioMatch = "Ratio"
    case areaMatch = "Area"
    case noMatch = "None"
}

struct WindowMatchResult {
    let targetWindow: WindowInfo
    let matchedTitle: String
    let matchType: MatchType
    let score: Int
    let success: Bool
}
