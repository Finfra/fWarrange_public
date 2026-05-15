import Foundation

// MARK: - 모델

/// 한 앱에 대한 타이틀 정규화 룰.
///
/// 매칭 우선순위: `bundleId` 정확 일치 > `app` 정확 일치.
/// 정규화 적용 순서: `stripPrefix` → `stripSuffix` → `stripPattern`(regex replace "").
/// 마지막에 양 끝 공백 trim.
struct TitleNormalizeRule: Codable, Equatable {
    /// 매칭 키 1순위 (가장 안정적).
    var bundleId: String?
    /// 매칭 키 2순위 (CGWindow ownerName).
    var app: String?
    /// 제거할 접두 (리터럴).
    var stripPrefix: String?
    /// 제거할 접미 (리터럴). 복수의 suffix 변형은 별도 룰 항목으로 분리.
    var stripSuffix: String?
    /// 제거할 정규식 (ICU). 매칭 부분 전체를 빈 문자열로 치환.
    var stripPattern: String?

    /// 본 룰이 적용 가능한지 판정. bundleId 우선, 둘 다 nil이면 false.
    func matches(bundleId targetBundleId: String?, app targetApp: String) -> Bool {
        if let mineBundle = bundleId, !mineBundle.isEmpty {
            return mineBundle == targetBundleId
        }
        if let mineApp = app, !mineApp.isEmpty {
            return mineApp == targetApp
        }
        return false
    }
}

// MARK: - 프로토콜

/// 타이틀 정규화 서비스.
///
/// 캡처·복구 양쪽에서 동일하게 사용하여 동적 타이틀(브라우저 페이지명, 알림 카운트 등)을 흡수.
/// Phase 1 통계 비교 시 본 정규화가 exactTitle(90점) 매칭률을 회복시키는지가 핵심 지표.
protocol TitleNormalizer: Sendable {
    /// 정규화. 적용 가능한 룰이 없거나 매칭되지 않으면 원본 반환.
    func normalize(title: String, bundleId: String?, app: String) -> String
    /// 현재 활성 룰셋 (REST 노출용).
    func currentRules() -> [TitleNormalizeRule]
    /// 룰셋 갱신 (REST PUT 진입).
    /// `nil` 전달 시 빌트인 룰셋으로 리셋. 디스크 영속 + regex 캐시 무효화.
    func updateRules(_ rules: [TitleNormalizeRule]?) throws
}

// MARK: - 구현체

/// 코드 내장 빌트인 + 사용자 편집본 파일 우선 패턴.
///
/// 사용자 편집본: `~/Library/Application Support/fWarrangeCli/title_normalize.yml`
/// (env `fWarrangeCli_normalize_path`로 재정의 가능).
/// 파일 존재 시 빌트인 룰셋 무시. 파일 없으면 빌트인 사용.
final class FileTitleNormalizer: TitleNormalizer, @unchecked Sendable {

    // MARK: - 상태

    private let queue = DispatchQueue(label: "fWarrangeCli.TitleNormalizer", attributes: .concurrent)
    private var rules: [TitleNormalizeRule] = []
    private var regexCache: [String: NSRegularExpression] = [:]
    private let fileURL: URL

    // MARK: - 초기화

    init(fileURL: URL? = nil) {
        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultFileURL()
        }
        loadFromDiskOrBuiltIn()
    }

    static func defaultFileURL() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["fWarrangeCli_normalize_path"], !envPath.isEmpty {
            return URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        }
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let appDir = baseDir.appendingPathComponent("fWarrangeCli", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("title_normalize.yml")
    }

    // MARK: - 공개 API

    func normalize(title: String, bundleId: String?, app: String) -> String {
        guard !title.isEmpty else { return title }
        return queue.sync {
            guard let rule = rules.first(where: { $0.matches(bundleId: bundleId, app: app) }) else {
                return title
            }
            return applyRule(rule, to: title)
        }
    }

    func currentRules() -> [TitleNormalizeRule] {
        queue.sync { rules }
    }

    func updateRules(_ newRules: [TitleNormalizeRule]?) throws {
        try queue.sync(flags: .barrier) {
            if let newRules = newRules {
                rules = newRules
                try writeToDisk(newRules)
            } else {
                // nil = 빌트인 리셋: 디스크 파일 삭제 + 빌트인 적용
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                rules = Self.builtInRules
            }
            regexCache.removeAll()
        }
    }

    // MARK: - 정규화 적용

    /// 룰 적용 순서: prefix → suffix → pattern. 마지막에 양 끝 공백 trim.
    /// 본 메서드는 queue.sync 컨텍스트에서만 호출됨 (regexCache 동기화).
    private func applyRule(_ rule: TitleNormalizeRule, to title: String) -> String {
        var result = title

        if let prefix = rule.stripPrefix, !prefix.isEmpty, result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
        }
        if let suffix = rule.stripSuffix, !suffix.isEmpty, result.hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count))
        }
        if let pattern = rule.stripPattern, !pattern.isEmpty {
            if let regex = cachedRegex(pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// regex 캐시. 본 메서드는 queue.sync 컨텍스트(read 또는 barrier write)에서 호출.
    private func cachedRegex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            logW("[TitleNormalizer] 잘못된 정규식 패턴: \(pattern)")
            return nil
        }
        regexCache[pattern] = regex
        return regex
    }

    // MARK: - 디스크 I/O

    private func loadFromDiskOrBuiltIn() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            rules = Self.builtInRules
            return
        }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let parsed = Self.parseYAML(content)
            if parsed.isEmpty {
                logW("[TitleNormalizer] 사용자 룰셋 비어있음 → 빌트인 사용")
                rules = Self.builtInRules
            } else {
                rules = parsed
                logI("[TitleNormalizer] 사용자 룰셋 로드 — \(parsed.count)개")
            }
        } catch {
            logE("[TitleNormalizer] 룰셋 로드 실패: \(error.localizedDescription) → 빌트인 사용")
            rules = Self.builtInRules
        }
    }

    private func writeToDisk(_ rules: [TitleNormalizeRule]) throws {
        let yaml = Self.serializeYAML(rules)
        try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
        logI("[TitleNormalizer] 룰셋 디스크 영속 — \(rules.count)개")
    }

    // MARK: - YAML I/O (LayoutStorageService 패턴 차용 — 자체 파서)

    static func serializeYAML(_ rules: [TitleNormalizeRule]) -> String {
        var yaml = ""
        for r in rules {
            yaml += "- "
            var first = true
            func write(_ key: String, _ value: String?) {
                guard let value = value, !value.isEmpty else { return }
                let safe = value
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let indent = first ? "" : "  "
                yaml += "\(indent)\(key): \"\(safe)\"\n"
                first = false
            }
            write("bundleId", r.bundleId)
            write("app", r.app)
            write("stripPrefix", r.stripPrefix)
            write("stripSuffix", r.stripSuffix)
            write("stripPattern", r.stripPattern)
            if first {
                // 모든 값이 nil/empty — 항목 자체를 스킵하지 않고 placeholder 추가 (드문 케이스)
                yaml += "app: \"\"\n"
            }
        }
        return yaml
    }

    static func parseYAML(_ content: String) -> [TitleNormalizeRule] {
        struct Acc {
            var bundleId: String?
            var app: String?
            var stripPrefix: String?
            var stripSuffix: String?
            var stripPattern: String?
            var isEmpty: Bool {
                bundleId == nil && app == nil && stripPrefix == nil && stripSuffix == nil && stripPattern == nil
            }
            func build() -> TitleNormalizeRule {
                TitleNormalizeRule(
                    bundleId: bundleId, app: app,
                    stripPrefix: stripPrefix, stripSuffix: stripSuffix,
                    stripPattern: stripPattern
                )
            }
        }

        var results: [TitleNormalizeRule] = []
        var current: Acc?

        func parseValue(_ raw: String) -> String {
            let val = raw.trimmingCharacters(in: .whitespaces)
            if val.hasPrefix("\"") && val.hasSuffix("\"") {
                return String(val.dropFirst().dropLast())
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
            return val
        }

        func setField(_ acc: inout Acc, _ key: String, _ raw: String) {
            let value = parseValue(raw)
            switch key {
            case "bundleId": acc.bundleId = value
            case "app": acc.app = value
            case "stripPrefix": acc.stripPrefix = value
            case "stripSuffix": acc.stripSuffix = value
            case "stripPattern": acc.stripPattern = value
            default: break
            }
        }

        for line in content.components(separatedBy: .newlines) {
            let raw = line
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed.hasPrefix("- ") {
                if let c = current, !c.isEmpty { results.append(c.build()) }
                current = Acc()
                let rest = String(trimmed.dropFirst(2))
                if let colon = rest.firstIndex(of: ":") {
                    let key = String(rest[..<colon])
                    let value = String(rest[rest.index(after: colon)...])
                    setField(&current!, key, value)
                }
            } else if let colon = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colon])
                let value = String(trimmed[trimmed.index(after: colon)...])
                if current != nil {
                    setField(&current!, key, value)
                }
            }
        }
        if let c = current, !c.isEmpty { results.append(c.build()) }
        return results
    }

    // MARK: - 빌트인 룰셋 (Top 10 앱)

    /// Issue72_3: 빌트인 룰셋. 사용자가 외부 파일을 두지 않은 경우 적용.
    static let builtInRules: [TitleNormalizeRule] = [
        // 브라우저: " — Safari", " - Google Chrome" 등 suffix 제거
        TitleNormalizeRule(bundleId: "com.apple.Safari", app: "Safari", stripSuffix: nil, stripPattern: " — Safari$"),
        TitleNormalizeRule(bundleId: "com.google.Chrome", app: "Google Chrome", stripPattern: " - Google Chrome$"),
        TitleNormalizeRule(bundleId: "com.microsoft.edgemac", app: "Microsoft Edge", stripPattern: " - Microsoft.+$"),
        TitleNormalizeRule(bundleId: "org.mozilla.firefox", app: "Firefox", stripPattern: " — Mozilla Firefox$"),

        // 에디터: 미저장 표시 prefix + 프로젝트명 suffix 제거
        TitleNormalizeRule(bundleId: "com.microsoft.VSCode", app: "Code", stripPrefix: "● ", stripPattern: " — .+$"),
        TitleNormalizeRule(bundleId: "com.todesktop.230313mzl4w4u92", app: "Cursor", stripPrefix: "● ", stripPattern: " — .+$"),

        // Slack: 알림 카운트 ` (N)` 제거
        TitleNormalizeRule(bundleId: "com.tinyspeck.slackmacgap", app: "Slack", stripPattern: " \\(\\d+\\)$"),

        // 터미널: " — zsh" 등 쉘 표시 제거
        TitleNormalizeRule(bundleId: "com.googlecode.iterm2", app: "iTerm2", stripPattern: " — .+$"),
        TitleNormalizeRule(bundleId: "com.apple.Terminal", app: "Terminal", stripPattern: " — .+$"),

        // Xcode: " — project_name" 제거
        TitleNormalizeRule(bundleId: "com.apple.dt.Xcode", app: "Xcode", stripPattern: " — .+$")
    ]
}
