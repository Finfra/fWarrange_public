import Foundation

// MARK: - 단일 매칭 이벤트 (최근 N개 보관용)

/// 복구 매칭 1건의 결과 스냅샷. RestoreStats.recentEvents에 누적됨.
struct RestoreEvent: Codable, Equatable {
    let timestamp: Date
    let app: String
    /// target.window — 정규화 전 원본
    let title: String
    let score: Int
    /// MatchType.rawValue (ex: "ID", "Title(Exact)", "Area", "None")
    let matchType: String
    let success: Bool
}

// MARK: - 누적 통계

/// 창 복구 매칭의 누적 통계.
///
/// `WindowRestoreService`가 매 매칭 결과(WindowMatchResult)마다 `RestoreStatsCollector.record(_:)`로 push하면,
/// Collector가 본 모델을 갱신·디스크 영속한다.
///
/// 디스크 위치: `~/Library/Application Support/fWarrangeCli/restore-stats.json`
struct RestoreStats: Codable, Equatable {
    /// recentEvents 윈도우 크기 상한.
    static let recentEventsCapacity = 200
    /// topFailureKeys 응답 노출 상한.
    static let topFailuresLimit = 10

    /// 누적 매칭 시도 수 (target 단위). 성공·실패 모두 포함.
    var totalAttempts: Int = 0
    /// 성공 카운트 (`WindowMatchResult.success == true`).
    var successes: Int = 0
    /// 실패 카운트.
    var failures: Int = 0
    /// MatchType.rawValue 별 누적 카운트 (전체 시도 기준).
    var matchTypeCounts: [String: Int] = [:]
    /// 성공 매칭의 score 합. averageScore 계산용.
    var successScoreSum: Int = 0
    /// 성공 매칭의 score 카운트. averageScore 계산용 (denominator).
    var successScoreCount: Int = 0
    /// 자주 실패하는 `(app|title)` 키별 카운트. Top N 추출 시 정렬.
    var failureKeyCounts: [String: Int] = [:]
    /// 최근 매칭 이벤트 (FIFO, capacity 200).
    var recentEvents: [RestoreEvent] = []
    /// 마지막 갱신 시각 (load/save 진단용).
    var lastUpdated: Date?
    /// 통계 누적 시작 시각 (베이스라인 보고서 기준점).
    var sessionStartedAt: Date?

    // MARK: - 파생 지표

    /// 성공 매칭의 평균 score. successScoreCount==0이면 0 반환.
    var averageScore: Double {
        guard successScoreCount > 0 else { return 0 }
        return Double(successScoreSum) / Double(successScoreCount)
    }

    /// 성공률 (0.0~1.0). totalAttempts==0이면 0 반환.
    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successes) / Double(totalAttempts)
    }

    /// 실패 카운트가 가장 많은 `(app|title)` 키 Top N.
    /// 정렬: count DESC, 동률 시 key ASC.
    var topFailures: [(key: String, count: Int)] {
        failureKeyCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(Self.topFailuresLimit)
            .map { ($0.key, $0.value) }
    }

    // MARK: - 누적 갱신

    /// 단일 매칭 이벤트를 누적. WindowRestoreService → Collector → 본 메서드 호출 경로.
    mutating func record(_ event: RestoreEvent) {
        totalAttempts += 1
        if event.success {
            successes += 1
            successScoreSum += event.score
            successScoreCount += 1
        } else {
            failures += 1
            let key = Self.failureKey(app: event.app, title: event.title)
            failureKeyCounts[key, default: 0] += 1
        }
        matchTypeCounts[event.matchType, default: 0] += 1

        recentEvents.append(event)
        if recentEvents.count > Self.recentEventsCapacity {
            recentEvents.removeFirst(recentEvents.count - Self.recentEventsCapacity)
        }

        lastUpdated = event.timestamp
        if sessionStartedAt == nil {
            sessionStartedAt = event.timestamp
        }
    }

    /// 실패 키 정규화 (app|title). title이 너무 길면 앞 80자만.
    static func failureKey(app: String, title: String) -> String {
        let trimmed = title.count > 80 ? String(title.prefix(80)) + "…" : title
        return "\(app)|\(trimmed)"
    }

    // MARK: - JSON 직렬화 헬퍼 (REST 응답 변환용)

    /// REST 응답용 dictionary 표현. JSON 직렬화 시 `topFailures`를 배열로 풀어냄.
    func toJSONDictionary() -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var dict: [String: Any] = [
            "totalAttempts": totalAttempts,
            "successes": successes,
            "failures": failures,
            "successRate": successRate,
            "averageScore": averageScore,
            "matchTypeCounts": matchTypeCounts,
            "topFailures": topFailures.map { ["key": $0.key, "count": $0.count] },
            "recentEventsCount": recentEvents.count,
            "recentEventsCapacity": Self.recentEventsCapacity
        ]
        if let lastUpdated = lastUpdated {
            dict["lastUpdated"] = isoFormatter.string(from: lastUpdated)
        }
        if let sessionStartedAt = sessionStartedAt {
            dict["sessionStartedAt"] = isoFormatter.string(from: sessionStartedAt)
        }
        return dict
    }
}
