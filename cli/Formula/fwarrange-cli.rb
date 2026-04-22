class FwarrangeCli < Formula
  desc "Window arrangement helper daemon for fWarrange"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "https://github.com/Finfra/fWarrange_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "TODO"

  depends_on :macos

  def install
    prefix.install "fWarrangeCli.app"
  end

  service do
    run [opt_prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli"]
    run_at_load false
    log_path var/"log/fwarrange-cli.log"
    error_log_path var/"log/fwarrange-cli.error.log"
    environment_variables FWARRANGE_PORT: "3016",
                          FWARRANGE_LOG_LEVEL: "info",
                          FWARRANGE_DISABLE_HOTKEYS: "0"
  end

  def post_install
    # Issue51 workaround: Homebrew 5.1.7에서 자동으로 추가되는 KeepAlive 제거
    system "plutil", "-remove", "KeepAlive",
           "#{Dir.home}/Library/LaunchAgents/homebrew.mxcl.fwarrange-cli.plist" rescue nil
  end

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
