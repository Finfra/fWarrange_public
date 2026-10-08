#!/bin/bash
# Issue32: All Clear Test 통합 테스트 (Issue29에서 run.sh full 모드로 구현된 흐름 이주)
# Usage: ./fwc-test.sh
#
# 8단계 체인:
#   Step 0: 기존 프로세스 종료
#   Step 1: 데이터 폴더 스냅샷(logs 제외) & _config.yml 삭제
#   Step 2: Xcode 빌드 & 배포 & 실행 (fwc-run-xcode.sh build-deploy)
#   Step 3: REST API 헬스 체크 (최대 10초 대기)
#   Step 4: _config.yml 기본값 검증 (19개 필드 + excludedApps + 단축키)
#   Step 5: API 테스트 전체 (apiTestDo.sh all)
#   Step 6: CMD 테스트 전체 (cmdTestDo.sh all)
#   Step 7: 로그 파일 ERROR/CRITICAL 검사
#   Step 8: 데이터 폴더 복원 & 원본 설정 재시작
#
# 데이터 보호 (Issue114): API·CMD 테스트는 레이아웃 전체 삭제·설정 변경·통계·정규화 룰
# 초기화를 실제 데이터에 가한다. Step 1 에서 데이터 폴더(logs 제외)와 앱 상태 폴더
# (Application Support)를 스냅샷하고, 정상 종료·중도 실패·Ctrl-C 어느 경우든 EXIT trap 이
# 앱을 멈춘 뒤 스냅샷으로 되돌린다.
#
# 빌드 구성: Debug (fwc-run-xcode.sh 통해 — TCC 회피 일관성)
# 설계 근거: Issue.md Issue32 (pairApp fsc-test.sh 패턴 이식)

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_XCODE="$SCRIPT_DIR/fwc-run-xcode.sh"
DATA_DIR="$HOME/Documents/finfra/fWarrangeData"
CONFIG_FILE="$DATA_DIR/_config.yml"
LOG_FILE="$DATA_DIR/logs/wlog_cliApp.log"
# restore-stats.json · title_normalize.yml live here (tests 34·36 reset them)
STATE_DIR="$HOME/Library/Application Support/fWarrangeCli"

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

# --- Step 1: 데이터 폴더 스냅샷 & _config.yml 삭제 ---
echo ""
echo "=== Step 1: 데이터 폴더 스냅샷 & _config.yml 삭제 ==="
SNAPSHOT_DIR=""
DATA_RESTORED=0
STATE_EXISTED=0

# Stop the app, then roll the data folder back to the snapshot (logs/ untouched).
# Idempotent: Step 8 calls it explicitly, the EXIT trap covers every early exit.
restore_data() {
    [ "$DATA_RESTORED" -eq 1 ] && return 0
    DATA_RESTORED=1
    [ -z "$SNAPSHOT_DIR" ] && return 0
    bash "$SCRIPT_DIR/kill.sh" >/dev/null 2>&1
    local ok=1
    # --checksum: same-size edits within the same second would pass rsync's quick check
    rsync -a --checksum --delete --exclude 'logs/' "$SNAPSHOT_DIR/data/" "$DATA_DIR/" || ok=0
    if [ "$STATE_EXISTED" -eq 1 ]; then
        rsync -a --checksum --delete "$SNAPSHOT_DIR/state/" "$STATE_DIR/" || ok=0
    elif [ -d "$STATE_DIR" ]; then
        rm -rf "$STATE_DIR"   # did not exist before the run — created by the tests
    fi
    if [ "$ok" -eq 1 ]; then
        rm -rf "$SNAPSHOT_DIR"
        echo "데이터·상태 폴더 복원 완료 (스냅샷 → $DATA_DIR, $STATE_DIR)"
    else
        echo "⚠️  복원 실패 — 스냅샷 보존: $SNAPSHOT_DIR (data/ → $DATA_DIR, state/ → $STATE_DIR)" >&2
    fi
}
trap restore_data EXIT
trap 'exit 130' INT TERM

mkdir -p "$DATA_DIR"
SNAPSHOT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fwc-test-data.XXXXXX") || { echo "❌ 스냅샷 폴더 생성 실패 — 중단"; exit 1; }
SNAP_OK=1
rsync -a --exclude 'logs/' "$DATA_DIR/" "$SNAPSHOT_DIR/data/" || SNAP_OK=0
if [ -d "$STATE_DIR" ]; then
    STATE_EXISTED=1
    rsync -a "$STATE_DIR/" "$SNAPSHOT_DIR/state/" || SNAP_OK=0
fi
if [ "$SNAP_OK" -ne 1 ]; then
    rm -rf "$SNAPSHOT_DIR"; SNAPSHOT_DIR=""
    echo "❌ 스냅샷 실패 — 실데이터 보호 불가로 중단"
    exit 1
fi
echo "데이터·상태 폴더 스냅샷: $SNAPSHOT_DIR ($(du -sh "$SNAPSHOT_DIR" | cut -f1))"
# Destructive tests (delete-all) check this flag; the snapshot makes them safe here
export FWC_DATA_SNAPSHOT=1

if [ -f "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
    echo "기존 _config.yml 삭제 (스냅샷에 보존 — 기본값 생성 테스트)"
else
    echo "_config.yml 없음 (신규 생성 테스트)"
fi

# --- Step 2: Xcode 빌드 & 배포 & 실행 ---
echo ""
echo "=== Step 2: Xcode 빌드 & 배포 & 실행 ==="
if bash "$RUN_XCODE" build-deploy; then
    record_result "빌드 & 배포" "PASS" "Xcode Debug 빌드 성공"
else
    record_result "빌드 & 배포" "FAIL" "빌드 또는 배포 실패"
    echo ""; echo "❌ 빌드 실패 — 중단 (EXIT trap 이 데이터 폴더 복원)"
    exit 1
fi

# --- Step 3: REST API 헬스 체크 (최대 10초 대기) ---
echo ""
echo "=== Step 3: REST API 헬스 체크 ==="
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
    echo ""; echo "❌ REST API 미응답 — 중단 (EXIT trap 이 데이터 폴더 복원)"
    exit 1
fi

# --- Step 4: _config.yml 기본값 검증 ---
echo ""
echo "=== Step 4: _config.yml 기본값 검증 ==="
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
    check_default "launchAtLogin" "true"   # Issue51: bundled seed default is true (brew services --keep)
    check_default "restServerEnabled" "true"
    check_default "allowExternalAccess" "false"
    check_default "allowedCIDR" "192.168.0.0/16"
    check_default "autoSaveOnSleep" "true"
    check_default "maxAutoSaves" "5"
    check_default "restoreButtonStyle" "nameIcon"
    check_default "confirmBeforeDelete" "true"
    check_default "clickSwitchToMain" "false"
    check_default "theme" "system"
    check_default "appLanguage" "system"

    printf "%b" "$DEFAULTS_DETAIL"

    EA_COUNT=$(echo "$CONFIG_CONTENT" | grep -c '  - "' || true)
    if [ "$EA_COUNT" -ge 2 ]; then
        echo "  ✓ excludedApps: ${EA_COUNT}개 항목"
    else
        echo "  ✗ excludedApps: ${EA_COUNT}개 항목 (expected: ≥2)"
        DEFAULTS_OK=false
    fi

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

# --- Step 5: API 테스트 (all) ---
echo ""
echo "=== Step 5: API 테스트 (all) ==="
API_RESULT=$(bash "$SCRIPT_DIR/apiTestDo.sh" all 2>&1)
echo "$API_RESULT"
# Judge each test by response content, not by how many ran (Issue114)
echo ""
echo "--- API 판정 ---"
API_VERDICT=$(echo "$API_RESULT" | python3 "$SCRIPT_DIR/fwc-verdict.py" "API")
API_RC=$?
echo "$API_VERDICT"
API_SUMMARY=$(echo "$API_VERDICT" | tail -1)
if [ "$API_RC" -eq 0 ]; then
    record_result "API 테스트" "PASS" "$API_SUMMARY"
else
    record_result "API 테스트" "FAIL" "$API_SUMMARY"
fi

# --- Step 6: CMD 테스트 (all) ---
echo ""
echo "=== Step 6: CMD 테스트 (all) ==="
CMD_RESULT=$(bash "$SCRIPT_DIR/cmdTestDo.sh" all 2>&1)
echo "$CMD_RESULT"
echo ""
echo "--- CMD 판정 ---"
CMD_VERDICT=$(echo "$CMD_RESULT" | python3 "$SCRIPT_DIR/fwc-verdict.py" "CMD")
CMD_RC=$?
echo "$CMD_VERDICT"
CMD_SUMMARY=$(echo "$CMD_VERDICT" | tail -1)
if [ "$CMD_RC" -eq 0 ]; then
    record_result "CMD 테스트" "PASS" "$CMD_SUMMARY"
else
    record_result "CMD 테스트" "FAIL" "$CMD_SUMMARY"
fi

# --- Step 7: 로그 확인 ---
echo ""
echo "=== Step 7: 로그 확인 ==="
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

# --- Step 8: 데이터 폴더 복원 & 재시작 ---
echo ""
echo "=== Step 8: 데이터 폴더 복원 ==="
restore_data

bash "$RUN_XCODE" run-only

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
