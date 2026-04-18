#!/bin/bash
# cmdTestDo.sh - CLI 커맨드 테스트 스크립트 실행기 (v1/v2 분리)
# Usage:
#   bash cli/_tool/cmdTestDo.sh                          # v1 정상 전체
#   bash cli/_tool/cmdTestDo.sh v1                       # v1 정상 전체
#   bash cli/_tool/cmdTestDo.sh v2                       # v2 정상 전체
#   bash cli/_tool/cmdTestDo.sh v1 0                     # v1 00번
#   bash cli/_tool/cmdTestDo.sh v2 20                    # v2 20번
#   bash cli/_tool/cmdTestDo.sh v1 E                     # v1 에러 전체
#   bash cli/_tool/cmdTestDo.sh v2 E08                   # v2 E08번
#   bash cli/_tool/cmdTestDo.sh all                      # v1 + v2 정상 + 에러 전체
#   bash cli/_tool/cmdTestDo.sh --run all                # fwc-run-xcode.sh 실행 후 전체 테스트
#   bash cli/_tool/cmdTestDo.sh --log all                # 테스트 후 로그 확인
#   bash cli/_tool/cmdTestDo.sh --report all             # 테스트 결과 저장
#   bash cli/_tool/cmdTestDo.sh --run --log --report all # 전체 자동화

# zsh/bash 호환 경로 탐지
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _SELF="${BASH_SOURCE[0]}"
else
    _SELF="$0"
fi
TOOL_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
ROOT_DIR="$TOOL_DIR/cmdTest"
REPORT_DIR="$(cd "$TOOL_DIR/.." && pwd)/_doc_work/report"
LOG_FILE="$HOME/Documents/finfra/fWarrangeData/logs/wlog.log"

# 옵션 파싱
OPT_RUN=0
OPT_LOG=0
OPT_REPORT=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --run)    OPT_RUN=1 ;;
        --log)    OPT_LOG=1 ;;
        --report) OPT_REPORT=1 ;;
        *)        ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

# 리포트 누적 버퍼
REPORT_BUFFER=""
append_report() { REPORT_BUFFER="$REPORT_BUFFER$1"$'\n'; }

run_test() {
    local file="$1"
    local base=$(basename "$file" .sh)
    local num=$(echo "$base" | sed 's/\([A-Z]*[0-9]*\)\..*/\1/')
    local name=$(echo "$base" | sed 's/[A-Z]*[0-9]*\.//')
    local header="========================================
[$num] $name
========================================"
    echo "$header"
    local output
    output=$(bash "$file" 2>&1)
    echo "$output"
    echo ""
    append_report "$header"
    append_report "$output"
    append_report ""
}

run_normal() {
    local dir="$1"
    for file in $(ls "$dir"/[0-9]*.sh 2>/dev/null | sort -t. -k1 -n); do
        run_test "$file"
    done
}

run_error() {
    local dir="$1"
    for file in $(ls "$dir"/E[0-9]*.sh 2>/dev/null | sort); do
        run_test "$file"
    done
}

pre_flight() {
    echo "=== Pre-flight: fwc-run-xcode.sh build-deploy 실행 ==="
    bash "$TOOL_DIR/fwc-run-xcode.sh" build-deploy
    echo ""
}

check_logs() {
    echo "=== Post-test Log Check ==="
    if [ -f "$LOG_FILE" ]; then
        local errors
        errors=$(grep -E "CRITICAL|❌ ERROR" "$LOG_FILE" | tail -20)
        if [ -n "$errors" ]; then
            echo "⚠️  에러/크리티컬 로그 발견:"
            echo "$errors"
            append_report "## 로그 요약 (에러 발견)"
            append_report '```'
            append_report "$errors"
            append_report '```'
        else
            echo "✅ 에러/크리티컬 로그 없음"
            append_report "## 로그 요약"
            append_report "✅ 에러/크리티컬 로그 없음"
        fi
        # 마지막 10줄
        local last_lines
        last_lines=$(tail -10 "$LOG_FILE")
        echo ""
        echo "--- 최근 로그 10줄 ---"
        echo "$last_lines"
        append_report ""
        append_report "### 최근 로그 10줄"
        append_report '```'
        append_report "$last_lines"
        append_report '```'
    else
        echo "로그 파일 없음: $LOG_FILE"
        append_report "## 로그 요약"
        append_report "로그 파일 없음: $LOG_FILE"
    fi
    echo ""
}

save_report() {
    local test_type="${1:-cmdTest}"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$REPORT_DIR/${timestamp}_${test_type}_report.md"
    mkdir -p "$REPORT_DIR"

    # 앱 버전 및 uptime
    local health
    health=$(curl -s --connect-timeout 3 http://localhost:3016/ 2>/dev/null)
    local version uptime
    version=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")
    uptime=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('uptime_seconds','?'))" 2>/dev/null || echo "?")

    {
        echo "---"
        echo "name: ${timestamp}_${test_type}_report"
        echo "description: ${test_type} 테스트 결과 리포트"
        echo "date: $(date +%Y-%m-%d)"
        echo "---"
        echo ""
        echo "# 개요"
        echo ""
        echo "* 실행일시: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "* 앱 버전: $version"
        echo "* 업타임(초): $uptime"
        echo "* 테스트 유형: $test_type"
        echo ""
        echo "# 테스트 결과"
        echo ""
        echo "$REPORT_BUFFER"
    } > "$report_file"

    echo "=== 리포트 저장 완료 ==="
    echo "📄 $report_file"
    echo ""
}

# --run: 사전 빌드·배포·실행
[ "$OPT_RUN" -eq 1 ] && pre_flight

# 버전 디렉토리 선택 (기본: v1)
VERSION="v1"
case "${1:-}" in
    v1|v2)
        VERSION="$1"
        shift
        ;;
    all)
        for v in v1 v2; do
            echo "======== $v NORMAL ========"
            append_report "## $v NORMAL"
            run_normal "$ROOT_DIR/$v"
            echo "======== $v ERROR ========"
            append_report "## $v ERROR"
            run_error  "$ROOT_DIR/$v"
        done
        [ "$OPT_LOG" -eq 1 ] && check_logs
        [ "$OPT_REPORT" -eq 1 ] && save_report "cmdTest"
        return 0 2>/dev/null || exit 0
        ;;
esac

SCRIPT_DIR="$ROOT_DIR/$VERSION"
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Error: $SCRIPT_DIR 디렉토리가 없습니다" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -n "${1:-}" ]; then
    case "$1" in
        E|e)
            append_report "## $VERSION ERROR"
            run_error "$SCRIPT_DIR"
            ;;
        E[0-9]*)
            match=$(ls "$SCRIPT_DIR"/"$1".*.sh 2>/dev/null)
            if [ -z "$match" ]; then
                echo "Error: $1.*.sh not found in $SCRIPT_DIR"
                return 1 2>/dev/null || exit 1
            fi
            run_test "$match"
            ;;
        *)
            num=$(printf "%02d" "$1" 2>/dev/null || echo "$1")
            match=$(ls "$SCRIPT_DIR"/"$num".*.sh 2>/dev/null)
            if [ -z "$match" ]; then
                echo "Error: $num.*.sh not found in $SCRIPT_DIR"
                return 1 2>/dev/null || exit 1
            fi
            run_test "$match"
            ;;
    esac
else
    append_report "## $VERSION NORMAL"
    run_normal "$SCRIPT_DIR"
fi

[ "$OPT_LOG" -eq 1 ] && check_logs
[ "$OPT_REPORT" -eq 1 ] && save_report "cmdTest_${VERSION}"
