class FwarrangeCli < Formula
  desc "Window arrangement helper daemon for fWarrange"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "https://github.com/Finfra/fWarrange_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "TODO"

  depends_on :macos

  def install
    prefix.install "fWarrangeCli.app"
  end

  # service 블록: Issue35에서 `brew services` 단일 표준 채택 시 추가 예정
  # 참조: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md §7-5-A

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
