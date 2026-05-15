import Foundation

// MARK: - 프로토콜

/// 창 복구 매칭 결과 누적·노출 서비스. `WindowRestoreService` → `record(_:)` 진입.
/// REST 응답 시 `currentSnapshot()`으로 직렬화 가능한 dictionary 획득.
protocol RestoreStatsCollector: Sendable {
    /// 단일 매칭 이벤트 누적. async — 디스크 영속이 throttle 단위로 일어남.
    func record(app: String, title: String, score: Int, matchType: MatchType, success: Bool) async
    /// 다건 일괄 누적. WindowMatchResult 배열을 한 번에 처리.
    func recordBatch(_ results: [WindowMatchResult]) async
    /// 현재 누적 통계 스냅샷 (REST 응답용 dictionary).
    func currentSnapshot() async -> [String: Any]
    /// 디스크에서 통계 로드 (앱 시작 시 호출).
    func load() async
    /// 디스크에 즉시 flush (앱 종료 시 호출).
    func flush() async
    /// 통계 초기화 (테스트·재시작 베이스라인용).
    func reset() async
}

// MARK: - 기본 구현 (디스크 영속)

/// JSON 파일 기반 영속 구현.
///
/// 경로: `~/Library/Application Support/fWarrangeCli/restore-stats.json` (env 미설정 시 기본).
/// 영속 정책: record/recordBatch 시 **즉시 디스크 기록**. 매칭은 빈번하지 않은 작업(복구 1회당 N개)이며,
/// 디바운스 도입 시 앱 종료(특히 launchd kill) 직전 매칭이 손실될 위험이 큼.
actor JSONRestoreStatsCollector: RestoreStatsCollector {

    // MARK: - 상태

    private var stats: RestoreStats = RestoreStats()
    private let fileURL: URL

    // MARK: - 초기화

    init(fileURL: URL? = nil) {
        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultFileURL()
        }
    }

    /// 기본 경로: `~/Library/Application Support/fWarrangeCli/restore-stats.json`.
    /// 환경변수 `fWarrangeCli_stats_path` 우선.
    static func defaultFileURL() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["fWarrangeCli_stats_path"], !envPath.isEmpty {
            return URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        }
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let appDir = baseDir.appendingPathComponent("fWarrangeCli", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("restore-stats.json")
    }

    // MARK: - 누적

    func record(app: String, title: String, score: Int, matchType: MatchType, success: Bool) async {
        let event = RestoreEvent(
            timestamp: Date(),
            app: app,
            title: title,
            score: score,
            matchType: matchType.rawValue,
            success: success
        )
        stats.record(event)
        await writeToDisk()
    }

    func recordBatch(_ results: [WindowMatchResult]) async {
        guard !results.isEmpty else { return }
        let now = Date()
        for result in results {
            let event = RestoreEvent(
                timestamp: now,
                app: result.targetWindow.app,
                title: result.targetWindow.window,
                score: result.score,
                matchType: result.matchType.rawValue,
                success: result.success
            )
            stats.record(event)
        }
        await writeToDisk()
    }

    // MARK: - 스냅샷

    func currentSnapshot() async -> [String: Any] {
        stats.toJSONDictionary()
    }

    // MARK: - 디스크 영속

    func load() async {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // 첫 실행 — 빈 통계 유지
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.stats = try decoder.decode(RestoreStats.self, from: data)
            logI("[RestoreStats] 로드 — totalAttempts=\(stats.totalAttempts), successes=\(stats.successes)")
        } catch {
            logW("[RestoreStats] 로드 실패: \(error.localizedDescription) — 빈 통계로 시작")
            self.stats = RestoreStats()
        }
    }

    func flush() async {
        await writeToDisk()
    }

    func reset() async {
        stats = RestoreStats()
        await writeToDisk()
    }

    // MARK: - 디스크 기록

    private func writeToDisk() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stats)
            try data.write(to: fileURL, options: [.atomic])
            logD("[RestoreStats] flush — \(fileURL.lastPathComponent), totalAttempts=\(stats.totalAttempts)")
        } catch {
            logE("[RestoreStats] flush 실패: \(error.localizedDescription)")
        }
    }
}
