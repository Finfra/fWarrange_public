#!/bin/bash
# tdd/cases/unit.sh — XCTest suite of fWarrangeCli (Issue132, step `unit` of tdd/run.sh)
#
# Runs `xcodebuild test` with the isolating test plan cli/fWarrangeCli.xctestplan
# (fWarrangeCli_config / FWARRANGE_DISABLE_HOTKEYS / FWARRANGE_PORT=13016), so the test host
# never touches the real data folder, the user's hotkeys or port 3016.
# The verdict comes from the log, not only from the exit code: xcodebuild has been seen to
# hang after the tests finished (prj13 precedent), so we stop waiting once the summary lines
# are in the log.
#
# Pass = "** TEST SUCCEEDED **", at least one "Test Case ... passed", zero "Test Case ... failed".
#
# Env: TDD_LOG (default /tmp/fwc-tdd-unit.log) · TDD_DERIVED (DerivedData path, default
#      ~/Library/Developer/Xcode/DerivedData/fWarrangeCli-tdd) · TDD_UNIT_TIMEOUT (default 1200s)

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="${TDD_LOG:-/tmp/fwc-tdd-unit.log}"
DERIVED="${TDD_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/fWarrangeCli-tdd}"
LIMIT="${TDD_UNIT_TIMEOUT:-1200}"

xcodebuild test -project "$ROOT/cli/fWarrangeCli.xcodeproj" -scheme fWarrangeCli \
    -testPlan fWarrangeCli -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
    >"$LOG" 2>&1 </dev/null &
XPID=$!
i=0
while [ "$i" -lt "$LIMIT" ]; do
    kill -0 "$XPID" 2>/dev/null || break
    if grep -q "\*\* TEST \(SUCCEEDED\|FAILED\) \*\*" "$LOG"; then
        sleep 5   # let xcodebuild exit on its own first
        break
    fi
    sleep 1; i=$((i + 1))
done
if kill -0 "$XPID" 2>/dev/null; then
    echo "⚠️ xcodebuild ($XPID) still running after the summary or ${LIMIT}s — killing"
    kill "$XPID" 2>/dev/null
fi
wait "$XPID" 2>/dev/null

grep -E "Test Case .* failed|error:|Executed [0-9]+ test|\*\* TEST (SUCCEEDED|FAILED) \*\*" "$LOG" | tail -40
PASS=$(grep -c "Test Case .* passed" "$LOG")
FAIL=$(grep -c "Test Case .* failed" "$LOG")
echo "=== unit: passed=$PASS failed=$FAIL (log: $LOG) ==="
grep -q "\*\* TEST SUCCEEDED \*\*" "$LOG" && [ "$PASS" -gt 0 ] && [ "$FAIL" -eq 0 ]
