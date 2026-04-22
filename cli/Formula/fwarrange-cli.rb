class FwarrangeCli < Formula
  desc "Window layout management daemon for fWarrange (local build)"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "file:///tmp/fWarrangeCli-local.tar.gz"
  version "1.0.0"
  sha256 "43a3b749463af2696394220ffa1886167a94b31eda919a81fd493e0b523cf122"
  license "MIT"

  depends_on :macos

  def install
    # Tarball contains pre-built fWarrangeCli.app (Apple Development signature preserved).
    # Brew sandbox restricts keychain access, so copy as-is without rebuilding.
    prefix.install "fWarrangeCli.app"
  end

  service do
    run [opt_prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli"]
    keep_alive successful_exit: false
    run_at_load true
    log_path var/"log/fwarrange-cli.log"
    error_log_path var/"log/fwarrange-cli.err.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      fWarrangeCli requires Accessibility permissions.

      To enable auto-start after installation:
        brew services start finfra/tap/fwarrange-cli

      To grant Accessibility permissions:
        System Settings > Privacy & Security > Accessibility > fWarrangeCli

      If TCC permissions are corrupted, reset via Xcode Debug path: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
