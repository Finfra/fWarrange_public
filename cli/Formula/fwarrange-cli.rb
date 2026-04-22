class FwarrangeCli < Formula
  desc "Window arrangement helper daemon for fWarrange"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "https://github.com/Finfra/fWarrange_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "TODO"

  depends_on :macos

  def install
    prefix.install "fWarrangeCli.app"
  end

  def post_install
    # Homebrew service 관리 비활성화 (Issue51 workaround)
    # brew services kill이 Homebrew 5.1.7에서 작동하지 않는 버그 회피
  end

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
