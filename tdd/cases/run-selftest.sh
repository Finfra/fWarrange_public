#!/bin/bash
# tdd/cases/run-selftest.sh — selftest of the playlist runner tdd/run.sh (Issue132 — port of prj25#Issue265)
#
# Uses stub step tables (TDD_STEPS_FILE) and a private lock, so it needs no build, no app and
# no GUI. Markers are computed values (got-$((40+2)) -> got-42) because the runner echoes the
# command line: grepping a literal marker would pass without the step having run.
#
# Usage: bash tdd/cases/run-selftest.sh      (TDD_RUNNER=<path> to test another runner copy)

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="${TDD_RUNNER:-$ROOT/tdd/run.sh}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/fwc-run-selftest.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
export TDD_LOCK="$WORK/lock"
PASS=0; FAIL=0

check() {   # check <name> <condition-rc>
    if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "  ✅ $1"; else FAIL=$((FAIL + 1)); echo "  ❌ $1"; fi
}

run() {     # run <steps-file> [args...] — sets OUT and RC
    local steps="$1"; shift
    OUT="$(TDD_STEPS_FILE="$steps" bash "$RUNNER" "$@" 2>&1)"; RC=$?
}

# 1. one failing step fails the run and is named
printf 'a|30|1|echo got-$((40+2))\nb|30|1|exit 7\nc|30|1|echo got-$((50+5))\n' >"$WORK/s1"
run "$WORK/s1"
echo "[1] failing step propagates"
check "rc is non-zero (rc=$RC)" "$([ "$RC" -ne 0 ] && echo 0 || echo 1)"
check "result line names b" "$(echo "$OUT" | tail -1 | grep -q '^PLAYLIST RESULT: failed b ' && echo 0 || echo 1)"
check "steps after the failure still run (got-55)" "$(echo "$OUT" | grep -q 'got-55' && echo 0 || echo 1)"

# 2. all green
printf 'a|30|1|echo got-$((40+2))\nc|30|1|true\n' >"$WORK/s2"
T0=$(date +%s); run "$WORK/s2"; DT=$(( $(date +%s) - T0 ))
echo "[2] all green"
check "no orphaned watchdog timer holds the output open (${DT}s < 10s)" "$([ "$DT" -lt 10 ] && echo 0 || echo 1)"
check "rc 0 (rc=$RC)" "$RC"
check "result line all green (2/2)" "$(echo "$OUT" | tail -1 | grep -q 'all green (2/2)' && echo 0 || echo 1)"
check "step a really ran (got-42)" "$(echo "$OUT" | grep -q 'got-42' && echo 0 || echo 1)"

# 3. a hung step is killed by the watchdog and counts as failure
printf 'slow|2|1|sleep 60\nafter|30|1|echo got-$((60+6))\n' >"$WORK/s3"
T0=$(date +%s); run "$WORK/s3"; DT=$(( $(date +%s) - T0 ))
echo "[3] watchdog"
check "rc non-zero (rc=$RC)" "$([ "$RC" -ne 0 ] && echo 0 || echo 1)"
check "slow reported rc=124" "$(echo "$OUT" | grep -q 'PLAYLIST slow ❌ rc=124' && echo 0 || echo 1)"
check "finished well before 60s (${DT}s)" "$([ "$DT" -lt 30 ] && echo 0 || echo 1)"
check "next step still ran (got-66)" "$(echo "$OUT" | grep -q 'got-66' && echo 0 || echo 1)"

# 4. a step that reads stdin must not eat the remaining step table
printf 'reader|30|1|cat >/dev/null; echo got-$((70+7))\nlast|30|1|echo got-$((80+8))\n' >"$WORK/s4"
run "$WORK/s4"
echo "[4] stdin isolation"
check "last step ran (got-88)" "$(echo "$OUT" | grep -q 'got-88' && echo 0 || echo 1)"
check "all green (2/2)" "$(echo "$OUT" | tail -1 | grep -q 'all green (2/2)' && echo 0 || echo 1)"

# 5. --quick skips non-quick steps · --only selects one · unknown --only is rejected
printf 'q|30|1|echo got-$((10+1))\nslowgui|30|0|exit 9\n' >"$WORK/s5"
run "$WORK/s5" --quick
echo "[5] selection"
check "--quick: green (1/1) without the gui step (rc=$RC)" "$([ "$RC" -eq 0 ] && echo "$OUT" | tail -1 | grep -q 'all green (1/1)' && echo 0 || echo 1)"
run "$WORK/s5" --only slowgui
check "--only slowgui: runs it and fails (rc=$RC)" "$([ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'PLAYLIST slowgui ❌' && echo 0 || echo 1)"
run "$WORK/s5" --only nope
check "--only unknown: rc 2 (rc=$RC)" "$([ "$RC" -eq 2 ] && echo 0 || echo 1)"

# 6. empty selection is a failure, not a silent green
printf '#only a comment\n' >"$WORK/s6"
run "$WORK/s6"
echo "[6] no steps"
check "rc non-zero (rc=$RC)" "$([ "$RC" -ne 0 ] && echo 0 || echo 1)"

# 7. a held lock times out with rc 3 and the lock is left to its owner
mkdir "$TDD_LOCK"; echo other >"$TDD_LOCK/owner"
OUT="$(TDD_STEPS_FILE="$WORK/s2" TDD_LOCK_WAIT=5 bash "$RUNNER" 2>&1)"; RC=$?
echo "[7] lock"
check "rc 3 (rc=$RC)" "$([ "$RC" -eq 3 ] && echo 0 || echo 1)"
check "foreign lock kept" "$([ "$(cat "$TDD_LOCK/owner" 2>/dev/null)" = other ] && echo 0 || echo 1)"
rm -rf "$TDD_LOCK"
run "$WORK/s2"
check "own lock released after a run" "$([ ! -d "$TDD_LOCK" ] && echo 0 || echo 1)"

echo ""
echo "run-selftest: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
