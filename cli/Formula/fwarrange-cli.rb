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
    keep_alive false
    log_path var/"log/fwarrange-cli.log"
    error_log_path var/"log/fwarrange-cli.error.log"
    environment_variables FWARRANGE_PORT: "3016",
                          FWARRANGE_LOG_LEVEL: "info",
                          FWARRANGE_DISABLE_HOTKEYS: "0"
  end

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
