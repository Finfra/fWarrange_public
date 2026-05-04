import Cocoa
import SwiftUI

/// About 창 관리 클래스
/// Issue69: paidApp 동작 상태에 따라 cli/paid 두 가지 모드의 About 창을 표시.
class AboutWindowManager {
    static let shared = AboutWindowManager()
    private var window: NSWindow?

    /// About 창 표시
    /// - Parameter isPaidActive: paidApp(`fWarrange`)이 동작 중이면 paidApp 정보를 표시
    func showAbout(isPaidActive: Bool = false) {
        // Re-create when mode changes so the title/contents reflect current paidApp state.
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.close()
            window = nil
        }

        let aboutView = AboutView(isPaidActive: isPaidActive)
        let hostingController = NSHostingController(rootView: aboutView)

        let newWindow = AboutWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = hostingController
        newWindow.title = isPaidActive ? "About fWarrange" : "About fWarrangeCli"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
        logV("ℹ️ About 창 표시 (mode=\(isPaidActive ? "paid" : "cli"))")
    }
}

// MARK: - About NSWindow (⌘W 지원)

/// LSUIElement 앱에서 ⌘W로 창 닫기를 지원하는 NSWindow 서브클래스
class AboutWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            close()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - About SwiftUI View

struct AboutView: View {
    let isPaidActive: Bool

    private static let paidAppBundleId = "kr.finfra.fWarrange"

    /// paidApp 번들 정보 (실행 중이면 NSRunningApplication, 아니면 PaidAppLauncher.detect()에서 추출)
    private var paidAppInfo: (name: String, version: String, icon: NSImage?)? {
        let bundleURL: URL? = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.paidAppBundleId)
            .first?.bundleURL ?? PaidAppLauncher.detect()
        guard let url = bundleURL, let bundle = Bundle(url: url) else { return nil }
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return ("fWarrange", "\(version) (\(build))", icon)
    }

    private var cliVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private let productPageURL = URL(string: "https://finfra.kr/product/fWarrange/en/index.html")!
    private let githubURL = URL(string: "https://github.com/finfra/fWarrange_public")!
    private let appStoreURL = URL(string: "macappstore://apps.apple.com/app/fwarrange/id6744105753")!

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            linkCard
            copyrightSection
        }
        .padding(24)
        .frame(minWidth: 380, minHeight: isPaidActive ? 420 : 380)
    }

    @ViewBuilder
    private var headerSection: some View {
        let info = isPaidActive ? paidAppInfo : nil
        VStack(spacing: 6) {
            if let icon = info?.icon ?? NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }
            Text(info?.name ?? "fWarrangeCli")
                .font(.title2)
                .fontWeight(.bold)
            Text(info?.version ?? cliVersion)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var linkCard: some View {
        VStack(spacing: 0) {
            linkRow(
                systemImage: "globe",
                title: "Product Page",
                subtitle: "finfra.kr",
                url: productPageURL
            )
            Divider().padding(.leading, 56)
            linkRow(
                systemImage: "chevron.left.forwardslash.chevron.right",
                title: "GitHub Repository",
                subtitle: "github.com/finfra/fWarrange_public",
                url: githubURL
            )
            if isPaidActive {
                Divider().padding(.leading, 56)
                linkRow(
                    systemImage: "bag",
                    title: "Mac App Store",
                    subtitle: "fWarrange (paid)",
                    url: appStoreURL
                )
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var copyrightSection: some View {
        Text("© 2025 Finfra. All rights reserved.")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func linkRow(systemImage: String, title: String, subtitle: String, url: URL) -> some View {
        Button(action: { NSWorkspace.shared.open(url) }) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
