class Fwarrangecli < Formula
  desc "Window arrangement helper daemon for fWarrange"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "https://github.com/Finfra/fWarrange_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "TODO"

  depends_on :macos

  def install
    prefix.install "fWarrangeCli.app"
  end

  # service 블록 제거: 자동 시작은 앱 내 SMAppService(LoginItem)로 관리
  # 향후 배포 시 필요하면 service 블록 재추가 예정

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
