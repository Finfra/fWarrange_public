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
    /// Issue72_2 (Phase 2): CGWindow onscreen 정렬 내 동일 앱 인덱스 (0=최전면).
    /// 같은 앱의 다중 창 매칭 시 tie-breaking·Moom 폴백(Phase 5)에 사용.
    /// 구 yml 호환을 위해 옵셔널.
    var windowOrder: Int?
    /// Issue72_2 (Phase 2): 창이 위치했던 디스플레이의 영구 UUID (`CGDisplayCreateUUIDFromDisplayID`).
    /// 디스플레이 토폴로지 변경 시 좌표 보정·정규화의 기준점. 구 yml 호환을 위해 옵셔널.
    var displayUUID: String?
    /// Issue72_3 (Phase 3): 정규화 적용 전 원본 axTitle. `window`는 TitleNormalizer 적용 후 값.
    /// 정규화 룰셋이 변경되어도 원본 추적 가능하도록 보존. 구 yml 호환을 위해 옵셔널.
    var windowRaw: String?
    /// Issue72_5 (Phase 5): 본 창에 적용할 매칭 모드 (strict/normal/loose).
    /// 옵셔널 — nil 시 복구 호출 시점의 기본 모드(REST 파라미터 또는 normal)를 사용.
    /// 사용자가 특정 창만 strict로 잠그거나 loose로 풀고 싶을 때 yml에 직접 명시.
    var matchMode: MatchMode?

    init(
        id: Int,
        app: String,
        bundleId: String? = nil,
        window: String,
        layer: Int,
        pos: WindowPosition,
        size: WindowSize,
        windowOrder: Int? = nil,
        displayUUID: String? = nil,
        windowRaw: String? = nil,
        matchMode: MatchMode? = nil
    ) {
        self.id = id
        self.app = app
        self.bundleId = bundleId
        self.window = window
        self.layer = layer
        self.pos = pos
        self.size = size
        self.windowOrder = windowOrder
        self.displayUUID = displayUUID
        self.windowRaw = windowRaw
        self.matchMode = matchMode
    }
}
