#!/bin/bash
# apiTestDo.sh - API 테스트 스크립트 실행기
# Usage:
#   source cli/_tool/apiTestDo.sh        # 정상 테스트 전체 실행
#   source cli/_tool/apiTestDo.sh 0      # 0번만 실행
#   source cli/_tool/apiTestDo.sh E      # 에러 테스트 전체 실행
#   source cli/_tool/apiTestDo.sh E01    # E01번만 실행
#   source cli/_tool/apiTestDo.sh all    # 정상 + 에러 전체 실행

# zsh/bash 호환 경로 탐지
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _SELF="${BASH_SOURCE[0]}"
elif [ -n "${(%):-%x}" 2>/dev/null ]; then
    _SELF="${(%):-%x}"
else
    _SELF="$0"
fi
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)/apiTest"

run_test() {
    local file="$1"
    local base=$(basename "$file" .sh)
    local num=$(echo "$base" | sed 's/\([A-Z]*[0-9]*\)\..*/\1/')
    local name=$(echo "$base" | sed 's/[A-Z]*[0-9]*\.//')
    echo "========================================"
    echo "[$num] $name"
    echo "========================================"
    bash "$file"
    echo ""
}

run_normal() {
    for file in $(ls "$SCRIPT_DIR"/[0-9]*.sh 2>/dev/null | sort -t. -k1 -n); do
        run_test "$file"
    done
}

run_error() {
    for file in $(ls "$SCRIPT_DIR"/E[0-9]*.sh 2>/dev/null | sort); do
        run_test "$file"
    done
}

if [ -n "$1" ]; then
    case "$1" in
        all)
            run_normal
            echo "======== ERROR TESTS ========"
            echo ""
            run_error
            ;;
        E|e)
            run_error
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
    run_normal
fi
