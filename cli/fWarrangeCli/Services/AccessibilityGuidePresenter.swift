import Foundation
import AppKit

/// Surfaces the Accessibility permission guide alert (Issue189).
/// Issue217 Phase 2: extracted from AppState. The caller injects the
/// `WindowManager` since opening the system settings is its responsibility.
enum AccessibilityGuidePresenter {

    /// Issue96: `NSAlert.runModal()` 은 블로킹이라 가드가 없으면 호출이 큐에 쌓여
    /// 닫는 즉시 또 뜬다(prj25 Issue221 실발생). 단축키는 연타될 수 있으므로 필수다.
    /// 접근은 모두 main queue 안에서만 일어나 별도 동기화가 필요 없다.
    private static var isPresenting = false

    static func show(windowManager: WindowManager) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Accessibility 권한 필요"
            alert.informativeText = """
                fWarrangeCli가 창 위치를 제어하려면 접근성 권한이 필요합니다.

                시스템 설정 > 개인정보 보호 및 보안 > 접근성에서
                fWarrangeCli를 추가하고 허용해주세요.
                """
            alert.addButton(withTitle: "설정 열기")
            alert.addButton(withTitle: "나중에")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                Task { @MainActor in
                    windowManager.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: - 운영 중 권한 상실 (Issue96)

    /// 실행 중에 접근성 권한이 해제된 것을 감지했을 때의 안내.
    ///
    /// 시작 시 안내(`show(windowManager:)`)와 달리 **설정 열기 버튼을 두지 않는다** —
    /// 권한이 해제되면 접근성 목록에서 항목 자체가 사라져 켤 대상이 없고,
    /// 실행 중인 프로세스는 스스로를 그 목록에 되돌릴 수 없다. 재시작이 유일한 복구 경로다.
    static func showPermissionLost() {
        DispatchQueue.main.async {
            guard !isPresenting else {
                logD("[a11y] 권한 상실 안내 이미 표시 중 — 중복 호출 억제")
                return
            }
            isPresenting = true
            defer { isPresenting = false }

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "접근성 권한이 해제되었습니다"
            alert.informativeText = """
                단축키는 입력됐지만 창을 제어할 수 없습니다.

                실행 중인 앱은 접근성 목록에 스스로를 다시 등록할 수 없어 재시작이 필요합니다.
                재시작 후에도 동작하지 않으면 시스템 설정 > 개인정보 보호 및 보안 > 접근성에서
                fWarrangeCli를 다시 허용해주세요.
                """
            alert.addButton(withTitle: "지금 재시작")
            alert.addButton(withTitle: "나중에")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                logI("[a11y] 권한 상실 안내 — 사용자가 재시작을 미룸")
                return
            }
            restart()
        }
    }

    /// 재시작 경로는 기동 방식에 따라 갈린다.
    /// launchd(brew services) 관리분은 brew 에 위임하고, `open` 기동분만 자가 재실행한다.
    private static func restart() {
        if BrewServiceSync.requestManagedRestart() {
            logI("[a11y] 재시작을 brew services 에 위임 — launchd 가 새 인스턴스를 기동")
            return
        }
        relaunchViaOpen()
    }

    /// `open` 기동 인스턴스의 자가 재실행.
    ///
    /// 새 인스턴스를 먼저 띄우면 `SingleInstanceGuard` 의 패자 규칙(non-launchd 는 기존 인스턴스에
    /// 양보하고 exit)에 걸려 곧바로 종료된다. 그래서 **현재 프로세스가 사라진 뒤** 뜨도록
    /// 분리된 셸 프로세스에 지연 실행을 맡긴다. 이 자식 프로세스는 부모 종료와 무관하게 살아남는다.
    private static func relaunchViaOpen() {
        let bundlePath = Bundle.main.bundleURL.path
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        // $0 = 번들 경로. 경로에 공백이 있어도 안전하도록 인자로 전달한다.
        // 최대 10초까지 자신의 종료를 기다린 뒤 open — 종료가 지연돼도 재시작을 놓치지 않는다.
        helper.arguments = [
            "-c",
            #"for _ in $(seq 1 50); do pgrep -f "$0/Contents/MacOS/" >/dev/null 2>&1 || break; sleep 0.2; done; /usr/bin/open "$0""#,
            bundlePath
        ]
        do {
            try helper.run()
        } catch {
            logW("[a11y] ⚠️ 재시작 헬퍼 실행 실패 — \(error.localizedDescription). 수동 재시작이 필요합니다")
            return
        }
        logI("[a11y] 자가 재시작 — 현재 인스턴스 종료 후 새 인스턴스 기동")
        NSApp.terminate(nil)
    }
}
