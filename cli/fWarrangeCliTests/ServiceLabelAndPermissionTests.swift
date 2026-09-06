import XCTest
@testable import fWarrangeCli

/// Issue95 · Issue96 · Issue94 회귀 테스트.
///
/// 세 이슈 모두 "한쪽만 갱신되어 판정이 갈라진" 종류의 고장이라, 판정 자체를
/// 순수 함수로 고정해 두고 여기서 못박는다.
final class ServiceLabelAndPermissionTests: XCTestCase {

    // MARK: - Issue95: Homebrew 서비스 label 규약 변경

    /// 신규 규약(`sh.brew.*`). 이것을 인식하지 못해 launchd 기동 프로세스가
    /// 자신을 non-launchd 로 오판하고 handoff 무한 루프에 빠진 것이 본 이슈다.
    func testRecognizesCurrentBrewLabelConvention() {
        XCTAssertTrue(BrewServiceSync.isServiceLabel("sh.brew.fwarrange-cli"))
    }

    /// 구 규약(`homebrew.mxcl.*`). 아직 구 brew 가 깔린 머신이 남아 있으므로
    /// 신규 규약으로 교체하는 것이 아니라 **둘 다** 인식해야 한다.
    func testRecognizesLegacyBrewLabelConvention() {
        XCTAssertTrue(BrewServiceSync.isServiceLabel("homebrew.mxcl.fwarrange-cli"))
    }

    /// brew 가 규약을 또 바꿔도 따라가기 위한 fallback —
    /// label 의 마지막 컴포넌트가 formula 명이면 이 서비스로 본다.
    func testRecognizesFutureConventionByFormulaSuffix() {
        XCTAssertTrue(BrewServiceSync.isServiceLabel("org.example.fwarrange-cli"))
    }

    /// 다른 서비스의 label 을 우리 것으로 오인하면 안 된다.
    /// 특히 formula 명을 **포함만** 하는 label(`...fwarrange-cli.helper`)은 거짓이어야 한다.
    func testRejectsUnrelatedLabels() {
        XCTAssertFalse(BrewServiceSync.isServiceLabel("sh.brew.some-other-formula"))
        XCTAssertFalse(BrewServiceSync.isServiceLabel("homebrew.mxcl.fwarrange-cli.helper"))
        XCTAssertFalse(BrewServiceSync.isServiceLabel("application.kr.finfra.fWarrange.308013185"))
    }

    /// `XPC_SERVICE_NAME` 미설정(= open 기동)일 때 nil/빈 문자열이 들어온다.
    /// 이것을 참으로 판정하면 open 기동분이 launchd 기동으로 오인되어 brew 동기화가 통째로 죽는다.
    func testRejectsNilAndEmpty() {
        XCTAssertFalse(BrewServiceSync.isServiceLabel(nil))
        XCTAssertFalse(BrewServiceSync.isServiceLabel(""))
    }

    /// 두 규약이 모두 후보 목록에 있어야 한다 — 한쪽만 남기면 그 순간 회귀다.
    func testKnownLabelsCoverBothConventions() {
        XCTAssertTrue(BrewServiceSync.knownServiceLabels.contains("sh.brew.fwarrange-cli"))
        XCTAssertTrue(BrewServiceSync.knownServiceLabels.contains("homebrew.mxcl.fwarrange-cli"))
        XCTAssertEqual(BrewServiceSync.serviceLabel, "sh.brew.fwarrange-cli",
                       "대표 label 은 신규 규약이어야 함")
    }

    // MARK: - Issue96: 접근성 권한을 요구하는 액션 구분

    /// 창을 읽고 옮기는 액션은 AX 권한이 필요하다 — 권한 상실 감지의 대상.
    func testWindowActionsRequireAccessibility() {
        XCTAssertTrue(HotKeyAction.save.requiresAccessibility)
        XCTAssertTrue(HotKeyAction.restoreDefault.requiresAccessibility)
        XCTAssertTrue(HotKeyAction.restoreLast.requiresAccessibility)
    }

    /// paidApp 창 열기는 URL Scheme 호출이라 권한이 필요 없다.
    /// 여기까지 게이트로 막으면 권한 없이도 되던 기능이 함께 죽는다.
    func testShowMainWindowDoesNotRequireAccessibility() {
        XCTAssertFalse(HotKeyAction.showMainWindow.requiresAccessibility)
    }

    // MARK: - Issue94: 죽은 설정 키 제거

    /// `showInCmdTab` 은 paidApp 이 소유를 가져가(prj16#Issue276) 소비처가 사라진 키다.
    /// 설정 응답에 다시 등장하면 누군가 되살린 것이므로 실패해야 한다.
    func testDeadSettingKeyIsGoneFromSettingsPayload() {
        let dict = AppSettings.fullSettingsDict(AppSettings.defaults)
        XCTAssertNil(dict["showInCmdTab"], "showInCmdTab 은 제거된 죽은 키")
    }

    /// 함께 쓰이는 이웃 키까지 지워지지 않았는지 — paidApp 고급 탭이 계속 사용 중이다.
    func testNeighbouringAdvancedKeysSurvive() {
        let dict = AppSettings.fullSettingsDict(AppSettings.defaults)
        XCTAssertNotNil(dict["confirmBeforeDelete"])
        XCTAssertNotNil(dict["clickSwitchToMain"])
    }

    /// PATCH 경로에도 죽은 키가 남지 않아야 한다.
    func testDeadSettingKeyIsIgnoredByPatch() {
        var settings = AppSettings.defaults
        AppSettings.applySettingsPatch(&settings, body: ["showInCmdTab": false])
        XCTAssertNil(AppSettings.fullSettingsDict(settings)["showInCmdTab"])
    }
}
