#!/bin/bash
# tdd/run.sh — run the whole fWarrangeCli TDD playlist (tdd/playlist.md) in playlist order (Issue132)
#
# Entry point for `jexec test` (data/exec.yml `test:`). Every runner listed in the playlist
# "실행" column is called once; one step covers several playlist rows when they share a runner.
# Port of the twin runner prj25 fSnippetCli tdd/run.sh (prj25#Issue265).
#
# Usage: bash tdd/run.sh [--quick] [--only <id>] [--list]
#   --quick      steps that leave the installed app alone (selftest + XCTest + publish dry-run check)
#   --only <id>  run a single step (see --list)
#   --list       print the steps and exit
#
# Exit status: 0 only when every selected step passed. The last line is always
#   "PLAYLIST RESULT: all green (N/N)" or "PLAYLIST RESULT: failed <ids>".
#
# Lock: takes /tmp/jma-xcode.lock itself (exec.yml `lock: self`) so it never runs next to
# another xcodebuild on jma. None of the step runners take that lock, so there is no deadlock.
# Prerequisites: XCTest runs isolated by cli/fWarrangeCli.xctestplan (port 13016, no hotkeys,
# no real data folder) — no brew service needed. The full-only step `all-clear-e2e`
# (cli/_tool/fwc-test.sh) replaces the deployed app and needs a logged-in GUI session (jma tmux);
# it snapshots the data folder first and restores it on exit.
#
# Test hooks (runner selftest, tdd/cases/run-selftest.sh):
#   TDD_STEPS_FILE  alternate step table, one "id|timeout_sec|quick(0/1)|command" per line
#   TDD_LOCK        lock directory (default /tmp/jma-xcode.lock)
#   TDD_LOCK_WAIT   seconds to wait for the lock (default 1800)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
LOCK="${TDD_LOCK:-/tmp/jma-xcode.lock}"
LOCK_WAIT="${TDD_LOCK_WAIT:-1800}"

# id | timeout(s) | quick | command — playlist rows in brackets
DEFAULT_STEPS='playlist-runner|120|1|bash tdd/cases/run-selftest.sh
unit|1500|1|bash tdd/cases/unit.sh
publish-dry-run-check|600|1|bash cli/_tool/fwc-deploy-brew-test.sh
all-clear-e2e|1800|0|bash cli/_tool/fwc-test.sh'
# playlist-runner        #28 (this runner)
# unit                   #1-8 #10-17 #19-27  (XCTest, test plan fWarrangeCli)
# publish-dry-run-check  #18 check 1 (check 2 needs --summary on a throwaway clone — not run here)
# all-clear-e2e          #9 (fwc-test.sh: deploy + REST/CMD all + log scan, data restored on exit)

if [ -n "${TDD_STEPS_FILE:-}" ]; then
    STEPS="$(cat "$TDD_STEPS_FILE")" || { echo "cannot read TDD_STEPS_FILE=$TDD_STEPS_FILE"; exit 2; }
else
    STEPS="$DEFAULT_STEPS"
fi

QUICK=0; ONLY=""; LIST=0
while [ $# -gt 0 ]; do
    case "$1" in
        --quick) QUICK=1 ;;
        --only) shift; ONLY="${1:-}"; [ -n "$ONLY" ] || { echo "--only needs an id"; exit 2; } ;;
        --list) LIST=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1"; exit 2 ;;
    esac
    shift
done

if [ "$LIST" = 1 ]; then
    echo "$STEPS" | awk -F'|' 'NF>=4 {printf "%-26s timeout=%ss quick=%s  %s\n", $1, $2, $3, $4}'
    exit 0
fi

if [ -n "$ONLY" ] && ! echo "$STEPS" | awk -F'|' -v id="$ONLY" '$1==id {f=1} END {exit !f}'; then
    echo "unknown step id: $ONLY (see --list)"; exit 2
fi

waited=0
until mkdir "$LOCK" 2>/dev/null; do
    if [ "$waited" -ge "$LOCK_WAIT" ]; then
        echo "lock wait timeout ${LOCK_WAIT}s — $LOCK held by: $(cat "$LOCK/owner" 2>/dev/null)"
        echo "PLAYLIST RESULT: failed lock"
        exit 3
    fi
    sleep 5; waited=$((waited + 5))
done
echo "fwc-tdd-run $$" >"$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT

# Run "$@" with a watchdog. Kills the whole process group of the step on timeout (rc 124).
run_with_watchdog() {
    local limit="$1"; shift
    local flag; flag="$(mktemp "${TMPDIR:-/tmp}/fwc-tdd-wd.XXXXXX")" || return 2; rm -f "$flag"
    set -m
    "$@" </dev/null &
    local pid=$!
    set +m
    # The timer sleep is killed with the watchdog — an orphaned sleep would keep the output
    # pipe open and could later signal a recycled process group.
    ( sleep "$limit" & spid=$!
      trap 'kill "$spid" 2>/dev/null; exit 0' TERM
      wait "$spid"
      touch "$flag"; echo "⏱ watchdog: ${limit}s exceeded — killing step"
      kill -TERM -- -"$pid" 2>/dev/null; sleep 5; kill -KILL -- -"$pid" 2>/dev/null ) &
    local wd=$!
    wait "$pid"; local rc=$?
    kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
    if [ -f "$flag" ]; then rm -f "$flag"; rc=124; fi
    return "$rc"
}

TOTAL=0; PASSED=0; FAILED=""; SKIPPED=0
START=$(date +%s)
while IFS='|' read -r id limit quick cmd; do
    [ -n "$id" ] || continue
    case "$id" in \#*) continue ;; esac
    if [ -n "$ONLY" ] && [ "$id" != "$ONLY" ]; then continue; fi
    if [ "$QUICK" = 1 ] && [ "$quick" != 1 ]; then SKIPPED=$((SKIPPED + 1)); continue; fi
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "== [$TOTAL] $id — $cmd =="
    t0=$(date +%s)
    run_with_watchdog "$limit" bash -c "$cmd"
    rc=$?
    dt=$(( $(date +%s) - t0 ))
    if [ "$rc" -eq 0 ]; then
        PASSED=$((PASSED + 1)); echo "PLAYLIST $id ✅ (${dt}s)"
    else
        FAILED="$FAILED $id"; echo "PLAYLIST $id ❌ rc=$rc (${dt}s)"
    fi
done <<EOF
$STEPS
EOF

echo ""
echo "elapsed $(( $(date +%s) - START ))s · skipped(--quick) $SKIPPED"
if [ "$TOTAL" -eq 0 ]; then
    echo "PLAYLIST RESULT: failed no-steps"; exit 1
fi
if [ -z "$FAILED" ]; then
    echo "PLAYLIST RESULT: all green ($PASSED/$TOTAL)"; exit 0
fi
echo "PLAYLIST RESULT: failed${FAILED} ($PASSED/$TOTAL passed)"
exit 1
