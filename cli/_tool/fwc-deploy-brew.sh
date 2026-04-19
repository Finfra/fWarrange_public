#!/bin/bash
# Issue34: /deploy brew 서브커맨드 라우터 (pairApp fsc-deploy-brew.sh 수렴)
# Usage: ./fwc-deploy-brew.sh [local|publish|status|uninstall]
#
# 목적:
#   - 단독 호출 금지 — 반드시 서브커맨드 동반
#   - local:     로컬 Homebrew tap 재설치 (원격 tap 생성 전 테스트 경로)
#   - publish:   원격 finfra/homebrew-tap 저장소에 Formula 반영 (🚧 TODO)
#   - status:    설치/tap/프로세스/REST 상태 조회 (+ 심링크, 원격 tap 체크)
#   - uninstall: brew 제거 + 로컬 tap Formula 파일 정리 + 심링크 제거
#
# 설계 근거:
#   - ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md
#   - pairApp(fSnippetCli #25) fsc-deploy-brew.sh 구조 수렴
# 설계 메모:
#   - Formula version은 URL에서 추출되지 않으므로 LOCAL_VERSION 명시 필수
#   - PIPESTATUS로 xcodebuild/brew 실제 exit code 포착 (tail 파이프 회피)
#   - 메뉴바 GUI 앱(LSUIElement)은 brew services 대신 open으로 직접 실행
#   - 우리 고유: /Applications/_nowage_app/ 심링크 (개발자 테스트 편의)
#   - brew 재설치 후 새 서명 바이너리로 TCC 권한 꼬임 가능 → /run tcc 안내

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$CLI_DIR")"

# shellcheck source=fwc-config.sh
source "$SCRIPT_DIR/fwc-config.sh"

TAP_DIR="/opt/homebrew/Library/Taps/finfra/homebrew-tap"
TAP_FORMULA="$TAP_DIR/Formula/fwarrangecli.rb"
TARBALL="/tmp/fWarrangeCli-local.tar.gz"
LOCAL_VERSION="0.0.0-local"
FORMULA_NAME="fwarrangecli"
APP_LINK="${DEPLOY_DIR}/${APP_NAME}"
REMOTE_TAP="finfra/tap"
PORT="3016"

usage() {
  cat <<'USAGE'
Usage: /deploy brew <sub>       ⚠️ 서브커맨드 필수 — 단독 호출 엄격 금지

🚫 `/deploy brew` (서브커맨드 없음)는 사용자 실수를 유발하므로 차단됩니다.
   암시적 기본값(local) 적용하지 않습니다. 반드시 아래 4개 중 하나 명시.

  sub         설명                                                         상태
  ---------   -----------------------------------------------------------  -----
  local       Release 빌드 → 로컬 finfra/tap 재설치 + 심링크 + 앱 실행     ✅
  publish     원격 finfra/homebrew-tap 저장소에 Formula 반영 + push        🚧 TODO
  status      brew 설치·tap·심링크·프로세스·REST API 상태 조회             ✅
  uninstall   brew uninstall + 로컬 tap Formula + 심링크 정리              ✅

예시:
  /deploy brew local       # 로컬 재설치 (개발 반복)
  /deploy brew status      # 현재 상태 한눈에 조회
  /deploy brew uninstall   # 깨끗하게 정리

⚠️ TCC 안내: brew 재설치로 접근성 권한이 꼬이면 `/run tcc` 로 재설정.
USAGE
}

# ---------- 공용 유틸: TCC 안내 ----------
tcc_notice() {
    echo ""
    echo "⚠️ TCC 안내"
    echo "   brew 재설치로 새 서명 바이너리가 생기면 접근성 권한이 분리되어"
    echo "   창 캡처·복구가 동작하지 않을 수 있습니다."
    echo ""
    echo "   해결책 중 하나:"
    echo "     1) 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > fWarrangeCli 체크"
    echo "     2) Xcode Debug 경로로 재설정: /run tcc"
    echo "        (kill + tccutil reset Accessibility kr.finfra.fWarrangeCli + build-deploy)"
}

# ==========================================
# 서브커맨드: local (9단계)
# ==========================================
cmd_local() {
    local TOTAL_PASS=0
    local TOTAL_FAIL=0
    local STEP_RESULTS=()

    record_result() {
        local step="$1" result="$2" detail="$3"
        if [ "$result" = "PASS" ]; then
            TOTAL_PASS=$((TOTAL_PASS + 1))
            STEP_RESULTS+=("✅ $step: $detail")
        else
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            STEP_RESULTS+=("❌ $step: $detail")
        fi
    }

    echo "╔══════════════════════════════════════════╗"
    echo "║  fWarrangeCli Brew Deploy (local)        ║"
    echo "╚══════════════════════════════════════════╝"

    # Step 1: Release 빌드
    echo ""
    echo "=== Step 1: Release 빌드 ==="
    pushd "$CLI_DIR" > /dev/null || { record_result "Release 빌드" "FAIL" "cd $CLI_DIR 실패"; return 1; }
    xcodebuild -scheme "$SCHEME" -configuration Release build 2>&1 | tail -8
    local BUILD_STATUS=${PIPESTATUS[0]}
    popd > /dev/null || true
    if [ "$BUILD_STATUS" -eq 0 ]; then
        record_result "Release 빌드" "PASS" "xcodebuild 성공"
    else
        record_result "Release 빌드" "FAIL" "xcodebuild 실패 (exit=$BUILD_STATUS)"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi

    # Step 2: 기존 프로세스 정리 + 심링크 제거
    echo ""
    echo "=== Step 2: 기존 프로세스 정리 ==="
    if pgrep -f "MacOS/$PROJECT_NAME" > /dev/null 2>&1; then
        echo "$PROJECT_NAME 프로세스 감지 — pkill"
        pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
        sleep 0.5
    fi
    [ -e "$APP_LINK" ] && rm -rf "$APP_LINK"
    record_result "기존 프로세스 정리" "PASS" "pkill + 심링크 제거"

    # Step 3: 로컬 tap 확인·생성
    echo ""
    echo "=== Step 3: 로컬 tap 확인·생성 ($REMOTE_TAP) ==="
    if [ ! -d "$TAP_DIR" ]; then
        echo "tap 미존재 — 생성 시도"
        if brew tap-new "$REMOTE_TAP" 2>/dev/null; then
            record_result "로컬 tap" "PASS" "brew tap-new $REMOTE_TAP"
        else
            echo "brew tap-new 실패 — 수동 mkdir fallback"
            mkdir -p "$TAP_DIR/Formula"
            pushd "$TAP_DIR" > /dev/null || true
            git init -q 2>/dev/null || true
            popd > /dev/null || true
            record_result "로컬 tap" "PASS" "수동 mkdir fallback"
        fi
    else
        record_result "로컬 tap" "PASS" "이미 존재: $TAP_DIR"
    fi

    # Step 4: 로컬 tarball 생성 (source tarball)
    echo ""
    echo "=== Step 4: 로컬 tarball 생성 ==="
    pushd "$ROOT_DIR" > /dev/null || { record_result "tarball 생성" "FAIL" "cd $ROOT_DIR 실패"; print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"; return 1; }
    tar czf "$TARBALL" cli/
    local TAR_STATUS=$?
    popd > /dev/null || true
    if [ "$TAR_STATUS" -eq 0 ]; then
        local SHA
        SHA=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
        echo "tarball: $TARBALL"
        echo "sha256 : $SHA"
        record_result "tarball 생성" "PASS" "$(du -h "$TARBALL" | awk '{print $1}')"
    else
        record_result "tarball 생성" "FAIL" "tar czf 실패 (exit=$TAR_STATUS)"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi

    # Step 5: 로컬 tap Formula 작성 (source build + caveats)
    echo ""
    echo "=== Step 5: 로컬 tap Formula 갱신 ==="
    mkdir -p "$(dirname "$TAP_FORMULA")"
    cat > "$TAP_FORMULA" <<FORMULA
class Fwarrangecli < Formula
  desc "Window arrangement helper daemon for fWarrange (local build)"
  homepage "https://github.com/Finfra/fWarrange_public"
  url "file://$TARBALL"
  version "$LOCAL_VERSION"
  sha256 "$SHA"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    # Homebrew가 tarball의 최상위 'cli/' 폴더로 자동 진입한 상태로 install 호출됨
    system "xcodebuild", "-project", "fWarrangeCli.xcodeproj",
           "-scheme", "fWarrangeCli",
           "-configuration", "Release",
           "-derivedDataPath", buildpath/"build",
           "MACOSX_DEPLOYMENT_TARGET=14.0",
           "SYMROOT=#{buildpath}/build",
           "CODE_SIGN_IDENTITY=-",
           "CODE_SIGNING_REQUIRED=NO",
           "CODE_SIGNING_ALLOWED=NO"
    prefix.install Dir["build/Release/fWarrangeCli.app"]
  end

  def caveats
    <<~EOS
      fWarrangeCli는 창 캡처·복구에 Accessibility(손쉬운 사용) 권한이 필요합니다.

      설치 후 다음 단계를 수행하세요:
        1. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용
        2. fWarrangeCli.app 항목에 체크

      TCC 권한이 꼬이면 Xcode Debug 경로로 재설정: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fWarrangeCli.app/Contents/MacOS/fWarrangeCli", :exist?
  end
end
FORMULA
    echo "$TAP_FORMULA"
    record_result "Formula 갱신" "PASS" "file:// URL + SHA256 + version=$LOCAL_VERSION"

    # Step 6: brew uninstall + install
    echo ""
    echo "=== Step 6: brew uninstall + install ==="
    brew uninstall "$FORMULA_NAME" 2>/dev/null || true
    brew install --build-from-source "$REMOTE_TAP/$FORMULA_NAME" 2>&1 | tail -20
    local INSTALL_STATUS=${PIPESTATUS[0]}
    if [ "$INSTALL_STATUS" -eq 0 ]; then
        record_result "brew install" "PASS" "$REMOTE_TAP/$FORMULA_NAME"
    else
        record_result "brew install" "FAIL" "exit=$INSTALL_STATUS"
    fi

    # Step 7: 심링크 생성 (/Applications/_nowage_app → brew prefix)
    echo ""
    echo "=== Step 7: 심링크 생성 ==="
    if [ "$INSTALL_STATUS" -ne 0 ]; then
        record_result "심링크 생성" "FAIL" "brew install 실패로 skip"
    else
        local BREW_PREFIX
        BREW_PREFIX=$(brew --prefix "$FORMULA_NAME" 2>/dev/null)
        if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/$APP_NAME" ]; then
            mkdir -p "$DEPLOY_DIR"
            ln -sfn "$BREW_PREFIX/$APP_NAME" "$APP_LINK"
            echo "[symlink] $APP_LINK → $BREW_PREFIX/$APP_NAME"
            record_result "심링크 생성" "PASS" "$APP_LINK"
        else
            record_result "심링크 생성" "FAIL" "brew prefix 또는 .app 없음: $BREW_PREFIX"
        fi
    fi

    # Step 8: 앱 실행
    echo ""
    echo "=== Step 8: 앱 실행 (open via symlink) ==="
    if [ ! -L "$APP_LINK" ] && [ ! -d "$APP_LINK" ]; then
        record_result "앱 실행" "FAIL" "심링크/앱 없음으로 skip"
    else
        echo "[open] $APP_LINK"
        open "$APP_LINK"
        local OPEN_STATUS=$?
        if [ "$OPEN_STATUS" -eq 0 ]; then
            record_result "앱 실행" "PASS" "$APP_LINK"
        else
            record_result "앱 실행" "FAIL" "open 실패 (exit=$OPEN_STATUS)"
        fi
    fi

    # Step 9: REST API 헬스 체크
    echo ""
    echo "=== Step 9: REST API 헬스 체크 (port $PORT) ==="
    local HEALTH=""
    for _i in $(seq 1 10); do
        HEALTH=$(curl -s --connect-timeout 2 http://localhost:$PORT/ 2>/dev/null)
        [ -n "$HEALTH" ] && break
        sleep 1
    done
    if [ -n "$HEALTH" ]; then
        echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
        record_result "REST API" "PASS" "포트 $PORT 응답 정상"
    else
        record_result "REST API" "FAIL" "10초 내 응답 없음 (접근성 미승인 가능성)"
    fi

    print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
    tcc_notice
    return "$TOTAL_FAIL"
}

# ==========================================
# 서브커맨드: publish (TODO)
# ==========================================
cmd_publish() {
    echo "🚧 /deploy brew publish 는 아직 미구현 (Issue34 Phase B)"
    echo ""
    echo "예정 동작:"
    echo "  1. GitHub 태그 생성 (예: cli-v1.0.0)"
    echo "  2. gh release create + tarball 업로드"
    echo "  3. cli/Formula/fWarrangeCli.rb 'url'/'sha256'/'version' 갱신"
    echo "  4. 원격 finfra/homebrew-tap 저장소 push"
    echo ""
    echo "사전 조건:"
    echo "  - 원격 finfra/homebrew-tap GitHub 저장소 생성 (public)"
    echo "  - gh CLI 인증 (gh auth login)"
    echo "  - HOMEBREW_TAP_TOKEN (tap 레포 write PAT)"
    echo ""
    echo "참고 가이드: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md"
    return 1
}

# ==========================================
# 서브커맨드: status
# ==========================================
cmd_status() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  fWarrangeCli Brew Status                ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    echo "── brew 설치 ──"
    if brew list "$FORMULA_NAME" &>/dev/null; then
        local VERSION
        VERSION=$(brew list --versions "$FORMULA_NAME" | awk '{print $2}')
        local PREFIX
        PREFIX=$(brew --prefix "$FORMULA_NAME" 2>/dev/null)
        echo "✅ 설치됨: $FORMULA_NAME $VERSION"
        echo "   prefix : $PREFIX"
        [ -d "$PREFIX/$APP_NAME" ] && echo "   .app   : $PREFIX/$APP_NAME"
    else
        echo "❌ 미설치"
    fi
    echo ""

    echo "── 로컬 tap ($REMOTE_TAP) ──"
    if [ -d "$TAP_DIR" ]; then
        echo "✅ 존재: $TAP_DIR"
        if [ -f "$TAP_FORMULA" ]; then
            echo "   Formula: $TAP_FORMULA"
            grep -E '^\s*(url|version|sha256)' "$TAP_FORMULA" | sed 's/^/     /'
        else
            echo "   Formula 파일 없음"
        fi
    else
        echo "❌ tap 미설치 ($TAP_DIR)"
    fi
    echo ""

    echo "── 원격 tap 등록 ──"
    if brew tap 2>/dev/null | grep -q "^${REMOTE_TAP}$"; then
        echo "✅ $REMOTE_TAP 등록됨"
    else
        echo "❌ $REMOTE_TAP 미등록 (원격 tap repo 미생성 또는 미연결)"
    fi
    echo ""

    echo "── 심링크 (/Applications/_nowage_app) ──"
    if [ -L "$APP_LINK" ]; then
        echo "✅ $APP_LINK → $(readlink "$APP_LINK")"
    elif [ -e "$APP_LINK" ]; then
        echo "⚠️  $APP_LINK 존재하지만 심링크 아님 (실제 파일/디렉토리)"
    else
        echo "❌ $APP_LINK 없음"
    fi
    echo ""

    echo "── 프로세스 ──"
    if pgrep -fl "MacOS/$PROJECT_NAME" 2>/dev/null; then
        :
    else
        echo "(실행 중 아님)"
    fi
    echo ""

    echo "── REST API (port $PORT) ──"
    local HEALTH
    HEALTH=$(curl -s --connect-timeout 2 http://localhost:$PORT/ 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        echo "✅ 응답 정상"
        echo "$HEALTH" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
    else
        echo "❌ 응답 없음"
    fi
}

# ==========================================
# 서브커맨드: uninstall
# ==========================================
cmd_uninstall() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  fWarrangeCli Brew Uninstall             ║"
    echo "╚══════════════════════════════════════════╝"

    # 프로세스 종료
    if pgrep -f "MacOS/$PROJECT_NAME" > /dev/null 2>&1; then
        echo "── 프로세스 종료"
        pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
        sleep 0.3
    fi

    echo "── brew uninstall $FORMULA_NAME"
    brew uninstall "$FORMULA_NAME" 2>&1 | tail -5

    echo "── 심링크 제거"
    if [ -e "$APP_LINK" ]; then
        rm -rf "$APP_LINK"
        echo "✅ 제거: $APP_LINK"
    else
        echo "(없음: $APP_LINK)"
    fi

    echo "── 로컬 tap Formula 제거"
    if [ -f "$TAP_FORMULA" ]; then
        rm -f "$TAP_FORMULA"
        echo "✅ 제거: $TAP_FORMULA"
    else
        echo "(없음: $TAP_FORMULA)"
    fi

    echo "── tarball 제거"
    if [ -f "$TARBALL" ]; then
        rm -f "$TARBALL"
        echo "✅ 제거: $TARBALL"
    else
        echo "(없음: $TARBALL)"
    fi

    echo ""
    echo "ℹ️  $REMOTE_TAP 디렉토리($TAP_DIR)는 유지함 — 완전 제거하려면:"
    echo "    brew untap $REMOTE_TAP"
}

# ==========================================
# 공용: 리포트 출력
# ==========================================
print_report() {
    local pass="$1" fail="$2"
    shift 2
    local results=("$@")

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║         Brew Deploy 결과                 ║"
    echo "╠══════════════════════════════════════════╣"
    for r in "${results[@]}"; do
        printf "║  %-40s║\n" "$r"
    done
    echo "╠══════════════════════════════════════════╣"
    if [ "$fail" -eq 0 ]; then
        printf "║  🎉 ALL CLEAR: %d PASS / %d FAIL         ║\n" "$pass" "$fail"
    else
        printf "║  ⚠️  ISSUES: %d PASS / %d FAIL           ║\n" "$pass" "$fail"
    fi
    echo "╚══════════════════════════════════════════╝"
}

# ==========================================
# 디스패치
# ==========================================
SUB="${1:-}"
case "$SUB" in
    local)
        cmd_local
        ;;
    publish)
        cmd_publish
        ;;
    status)
        cmd_status
        ;;
    uninstall)
        cmd_uninstall
        ;;
    "")
        usage
        exit 1
        ;;
    *)
        echo "❌ 알 수 없는 서브커맨드: $SUB"
        echo ""
        usage
        exit 1
        ;;
esac
