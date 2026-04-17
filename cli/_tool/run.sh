#!/bin/bash
# Usage: ./run.sh [run-only|full]
#   run-only: 빌드 없이 실행만
#   full: 빌드→배포→_config.yml 초기화→기본값 검증→API/CMD 전체 테스트

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="/Applications/_nowage_app/fWarrangeCli.app"
MODE="${1:-build-run}"
DATA_DIR="$HOME/Documents/finfra/fWarrangeData"
CONFIG_FILE="$DATA_DIR/_config.yml"
LOG_FILE="$DATA_DIR/logs/wlog.log"

# full 모드 분기 (set -e 비활성화 — 개별 step에서 에러 핸들링)
if [ "$MODE" = "full" ]; then
    set +e
    TOTAL_PASS=0
    TOTAL_FAIL=0
    STEP_RESULTS=()

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
    echo "║       fWarrangeCli All Clear Test        ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # --- Step 0: 프로세스 종료 ---
    echo "=== Step 0: 기존 프로세스 종료 ==="
    bash "$SCRIPT_DIR/kill.sh"

    # --- Step 1: _config.yml 백업 & 삭제 ---
    echo ""
    echo "=== Step 1: _config.yml 백업 & 삭제 ==="
    CONFIG_BACKUP=""
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG_BACKUP="${CONFIG_FILE}.bak.$$"
        cp "$CONFIG_FILE" "$CONFIG_BACKUP"
        rm -f "$CONFIG_FILE"
        echo "기존 _config.yml 백업: $CONFIG_BACKUP"
    else
        echo "_config.yml 없음 (신규 생성 테스트)"
    fi

    # --- Step 2: Debug 빌드 & 배포 ---
    echo ""
    echo "=== Step 2: Debug 빌드 & 배포 ==="
    cd "$CLI_DIR"
    if xcodebuild -scheme fWarrangeCli -configuration Debug build -quiet 2>&1; then
        BUILD_DIR=$(xcodebuild -scheme fWarrangeCli -showBuildSettings 2>/dev/null | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
        mkdir -p /Applications/_nowage_app
        rm -rf "$APP_PATH"
        cp -R "$BUILD_DIR/fWarrangeCli.app" "$APP_PATH"
        xattr -cr "$APP_PATH"
        record_result "빌드 & 배포" "PASS" "Debug 빌드 성공"
    else
        record_result "빌드 & 배포" "FAIL" "빌드 실패"
        echo ""; echo "❌ 빌드 실패 — 중단"
        [ -n "$CONFIG_BACKUP" ] && mv "$CONFIG_BACKUP" "$CONFIG_FILE"
        exit 1
    fi

    # --- Step 3: 앱 실행 ---
    echo ""
    echo "=== Step 3: 앱 실행 ==="
    open "$APP_PATH"

    # --- Step 4: REST API 헬스 체크 (최대 10초 대기) ---
    echo ""
    echo "=== Step 4: REST API 헬스 체크 ==="
    HEALTH=""
    for _i in $(seq 1 10); do
        HEALTH=$(curl -s --connect-timeout 2 http://localhost:3016/ 2>/dev/null)
        if [ -n "$HEALTH" ]; then
            break
        fi
        sleep 1
    done
    if [ -n "$HEALTH" ]; then
        HEALTH_MSG=$(echo "$HEALTH" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"status={d.get(\"status\",\"?\")}, layouts={d.get(\"layout_count\",\"?\")}") ' 2>/dev/null || echo "응답 수신")
        record_result "REST API 헬스" "PASS" "$HEALTH_MSG"
    else
        record_result "REST API 헬스" "FAIL" "10초 내 응답 없음 (포트 3016)"
        echo ""; echo "❌ REST API 미응답 — 중단"
        [ -n "$CONFIG_BACKUP" ] && mv "$CONFIG_BACKUP" "$CONFIG_FILE"
        exit 1
    fi

    # --- Step 5: _config.yml 기본값 검증 ---
    echo ""
    echo "=== Step 5: _config.yml 기본값 검증 ==="
    if [ -f "$CONFIG_FILE" ]; then
        echo "_config.yml 자동 생성 확인 ✓"
        CONFIG_CONTENT=$(cat "$CONFIG_FILE")
        DEFAULTS_OK=true
        DEFAULTS_DETAIL=""

        check_default() {
            local key="$1" expected="$2"
            local actual
            actual=$(echo "$CONFIG_CONTENT" | grep "^${key}:" | head -1 | sed "s/^${key}: *//; s/\"//g")
            if [ "$actual" = "$expected" ]; then
                DEFAULTS_DETAIL="${DEFAULTS_DETAIL}  ✓ ${key}: ${actual}\n"
            else
                DEFAULTS_DETAIL="${DEFAULTS_DETAIL}  ✗ ${key}: ${actual} (expected: ${expected})\n"
                DEFAULTS_OK=false
            fi
        }

        check_default "maxRetries" "5"
        check_default "retryInterval" "0.5"
        check_default "minimumMatchScore" "30"
        check_default "enableParallelRestore" "true"
        check_default "restServerPort" "3016"
        check_default "logLevel" "5"
        check_default "dataStorageMode" "host"
        check_default "launchAtLogin" "false"
        check_default "restServerEnabled" "true"
        check_default "allowExternalAccess" "false"
        check_default "allowedCIDR" "192.168.0.0/16"
        check_default "autoSaveOnSleep" "true"
        check_default "maxAutoSaves" "5"
        check_default "restoreButtonStyle" "nameIcon"
        check_default "confirmBeforeDelete" "true"
        check_default "showInCmdTab" "true"
        check_default "clickSwitchToMain" "false"
        check_default "theme" "system"
        check_default "appLanguage" "system"

        printf "%b" "$DEFAULTS_DETAIL"

        # excludedApps 확인
        EA_COUNT=$(echo "$CONFIG_CONTENT" | grep -c '  - "' || true)
        if [ "$EA_COUNT" -ge 2 ]; then
            echo "  ✓ excludedApps: ${EA_COUNT}개 항목"
        else
            echo "  ✗ excludedApps: ${EA_COUNT}개 항목 (expected: ≥2)"
            DEFAULTS_OK=false
        fi

        # 단축키 확인
        SC_SAVE=$(echo "$CONFIG_CONTENT" | grep "^saveShortcut:" | head -1)
        SC_RESTORE=$(echo "$CONFIG_CONTENT" | grep "^restoreDefaultShortcut:" | head -1)
        if [ -n "$SC_SAVE" ] && [ -n "$SC_RESTORE" ]; then
            echo "  ✓ 단축키 설정: saveShortcut, restoreDefaultShortcut 존재"
        else
            echo "  ✗ 단축키 설정 누락"
            DEFAULTS_OK=false
        fi

        if $DEFAULTS_OK; then
            record_result "_config.yml 기본값" "PASS" "모든 기본값 일치"
        else
            record_result "_config.yml 기본값" "FAIL" "일부 기본값 불일치"
        fi
    else
        record_result "_config.yml 기본값" "FAIL" "_config.yml 자동 생성 안 됨"
    fi

    # --- Step 6: API 테스트 (all) ---
    echo ""
    echo "=== Step 6: API 테스트 (all) ==="
    API_RESULT=$(bash "$SCRIPT_DIR/apiTestDo.sh" all 2>&1)
    echo "$API_RESULT"
    API_TOTAL=$(echo "$API_RESULT" | grep -c '^\[' || true)
    API_OK=$(echo "$API_RESULT" | grep -c '"status": "ok"' || true)
    API_ERR_EXPECTED=$(echo "$API_RESULT" | grep -c '"status": "error"' || true)
    if [ "$API_TOTAL" -gt 0 ]; then
        record_result "API 테스트" "PASS" "${API_TOTAL}개 테스트 실행 (ok=${API_OK}, error=${API_ERR_EXPECTED})"
    else
        record_result "API 테스트" "FAIL" "테스트 실행 안 됨"
    fi

    # --- Step 7: CMD 테스트 (all) ---
    echo ""
    echo "=== Step 7: CMD 테스트 (all) ==="
    CMD_RESULT=$(bash "$SCRIPT_DIR/cmdTestDo.sh" all 2>&1)
    echo "$CMD_RESULT"
    CMD_TOTAL=$(echo "$CMD_RESULT" | grep -c '^\[' || true)
    if [ "$CMD_TOTAL" -gt 0 ]; then
        record_result "CMD 테스트" "PASS" "${CMD_TOTAL}개 테스트 실행"
    else
        record_result "CMD 테스트" "FAIL" "테스트 실행 안 됨"
    fi

    # --- Step 8: 로그 확인 ---
    echo ""
    echo "=== Step 8: 로그 확인 ==="
    if [ -f "$LOG_FILE" ]; then
        LOG_ERRORS=$(grep -c "ERROR\|CRITICAL" "$LOG_FILE" 2>/dev/null || true)
        LOG_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
        echo "로그 파일: ${LOG_LINES}줄, ERROR/CRITICAL: ${LOG_ERRORS}건"
        if [ "$LOG_ERRORS" -eq 0 ]; then
            record_result "로그 검사" "PASS" "ERROR/CRITICAL 0건"
        else
            record_result "로그 검사" "FAIL" "ERROR/CRITICAL ${LOG_ERRORS}건 발견"
            echo "--- 에러 로그 ---"
            grep "ERROR\|CRITICAL" "$LOG_FILE" | tail -5
        fi
    else
        echo "로그 파일 없음 (logLevel=5이므로 정상)"
        record_result "로그 검사" "PASS" "로그 파일 미생성 (logLevel=5, critical 전용)"
    fi

    # --- Step 9: _config.yml 복원 & 최종 결과 ---
    echo ""
    echo "=== Step 9: _config.yml 복원 ==="
    if [ -n "$CONFIG_BACKUP" ]; then
        mv "$CONFIG_BACKUP" "$CONFIG_FILE"
        echo "원본 _config.yml 복원 완료"
    else
        echo "복원 대상 없음 (기존 파일 없었음)"
    fi

    # 프로세스 종료 후 원본 설정으로 재시작
    bash "$SCRIPT_DIR/kill.sh"
    open "$APP_PATH"

    # --- 최종 리포트 ---
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║          All Clear Test 결과             ║"
    echo "╠══════════════════════════════════════════╣"
    for r in "${STEP_RESULTS[@]}"; do
        printf "║  %-40s║\n" "$r"
    done
    echo "╠══════════════════════════════════════════╣"
    if [ "$TOTAL_FAIL" -eq 0 ]; then
        printf "║  🎉 ALL CLEAR: %d PASS / %d FAIL        ║\n" "$TOTAL_PASS" "$TOTAL_FAIL"
    else
        printf "║  ⚠️  ISSUES: %d PASS / %d FAIL           ║\n" "$TOTAL_PASS" "$TOTAL_FAIL"
    fi
    echo "╚══════════════════════════════════════════╝"

    if [ "$TOTAL_FAIL" -eq 0 ]; then
        say "All clear test passed" 2>/dev/null &
    else
        say "All clear test failed" 2>/dev/null &
    fi

    exit "$TOTAL_FAIL"
fi

# --- 기존 모드 (build-run / run-only) ---

echo "=== Step 1: 기존 프로세스 종료 ==="
bash "$SCRIPT_DIR/kill.sh"

if [ "$MODE" != "run-only" ]; then
    echo "=== Step 2: Debug 빌드 ==="
    cd "$CLI_DIR"
    xcodebuild -scheme fWarrangeCli -configuration Debug build -quiet

    echo "=== Step 3: 배포 ==="
    BUILD_DIR=$(xcodebuild -scheme fWarrangeCli -showBuildSettings 2>/dev/null | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
    mkdir -p /Applications/_nowage_app
    rm -rf "$APP_PATH"
    cp -R "$BUILD_DIR/fWarrangeCli.app" "$APP_PATH"
    xattr -cr "$APP_PATH"
fi

echo "=== Step 4: 실행 ==="
open "$APP_PATH"

echo "=== Step 5: 동작 확인 ==="
sleep 3
HEALTH=$(curl -s --connect-timeout 3 http://localhost:3016/ 2>/dev/null)
if [ -n "$HEALTH" ]; then
    echo "✅ REST API 정상"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
else
    echo "❌ REST API 응답 없음 (포트 3016)"
fi
