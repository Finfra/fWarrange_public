import Foundation

/// Tells an Official Build apart from a source build (Issue105).
///
/// DISTRIBUTION-TERMS.md §1(b) applies only to the Official Build Components. They live in
/// `cli/resources/official/` and are copied into `Contents/Resources/Official/` only when the
/// official build scripts pass `FWARRANGE_OFFICIAL_BUILD=YES` (`_tool/fwc-official-components.sh`).
/// A plain Xcode build — what anyone gets from `git clone` — therefore reports "Source Build".
enum OfficialBuild {

    static let sourceBuild = "Source Build"

    /// First non-blank line of `Official/official-build.txt` under `resourcesURL`, or "Source Build".
    static func distribution(resourcesURL: URL?) -> String {
        guard let url = resourcesURL?.appendingPathComponent("Official/official-build.txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return sourceBuild }
        let banner = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return banner ?? sourceBuild
    }

    /// Distribution of the running bundle — reported by GET /cli/version (`fWarrangeCli --version`).
    static var current: String { distribution(resourcesURL: Bundle.main.resourceURL) }
}
