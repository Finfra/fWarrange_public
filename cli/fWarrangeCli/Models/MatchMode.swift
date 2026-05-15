import Foundation

// MARK: - 매칭 모드

/// Issue72_5 (Phase 5): 창 복구 매칭 모드.
///
/// 사용자 의도("정확히" vs "비슷하게")를 표현하는 단일 enum.
/// 모드별 거동은 `RuntimeMatchPolicy`가 결정.
///
/// - strict: ID/exactTitle/regexTitle/containsTitle 만 허용 (점수 ≥70), 기하 폴백·1:N·Moom 폴백 차단
/// - normal: 현행 + Phase 4 distance 가산. minimumScore 30(설정값). 1:N·Moom 폴백 차단
/// - loose:  1:N 매칭 허용 (Stay 스타일), 모든 점수 미달 시 Moom 폴백(앱별 창 수 일치 → windowOrder 정렬 배분)
enum MatchMode: String, Codable, CaseIterable, Sendable {
    case strict
    case normal
    case loose

    /// 옵셔널 RawValue 변환. nil·잘못된 값은 .normal.
    static func parse(_ value: String?) -> MatchMode {
        guard let value = value, let mode = MatchMode(rawValue: value.lowercased()) else {
            return .normal
        }
        return mode
    }
}

// MARK: - 런타임 정책

/// Issue72_5 (Phase 5): MatchMode가 결정하는 매칭 알고리즘 거동 묶음.
/// computeMatchScore·findOptimalMatches·Moom 폴백이 본 구조체를 참조하여 분기.
struct RuntimeMatchPolicy: Sendable {
    /// 매칭 통과 최소 점수. 본 값 미만은 .noMatch 처리.
    let minimumScore: Int
    /// 기하 매칭(widthMatch/heightMatch/ratioMatch/areaMatch, 60~30점) 활성 여부.
    /// strict 모드에서는 false.
    let geometricFallbackEnabled: Bool
    /// areaMatch(30점) 단독 활성 여부. AppSettings.matchAreaMatchEnabled와 AND 결합.
    let areaMatchEnabled: Bool
    /// 1:N 매칭 허용 — 한 저장된 target이 여러 열린 창에 매칭 가능 (Stay 스타일).
    /// loose 모드 전용.
    let allowMultipleAssignments: Bool
    /// Moom 폴백 활성 — 모든 매칭 실패 시 앱별 창 개수 같으면 windowOrder 순으로 위치 배분.
    /// loose 모드 전용.
    let moomFallbackEnabled: Bool

    /// 모드 + AppSettings.matchAreaMatchEnabled 조합으로 정책 빌드.
    static func from(mode: MatchMode, settingsMinimumScore: Int, areaMatchSettingEnabled: Bool) -> RuntimeMatchPolicy {
        switch mode {
        case .strict:
            return RuntimeMatchPolicy(
                minimumScore: 70,                       // containsTitle 이상만 허용
                geometricFallbackEnabled: false,        // 기하 폴백 차단
                areaMatchEnabled: false,
                allowMultipleAssignments: false,
                moomFallbackEnabled: false
            )
        case .normal:
            return RuntimeMatchPolicy(
                minimumScore: settingsMinimumScore,     // 사용자 설정값(기본 30)
                geometricFallbackEnabled: true,
                areaMatchEnabled: areaMatchSettingEnabled,
                allowMultipleAssignments: false,
                moomFallbackEnabled: false
            )
        case .loose:
            return RuntimeMatchPolicy(
                minimumScore: 30,                       // 가장 관대
                geometricFallbackEnabled: true,
                areaMatchEnabled: true,                 // loose는 항상 area 허용
                allowMultipleAssignments: true,
                moomFallbackEnabled: true
            )
        }
    }
}
