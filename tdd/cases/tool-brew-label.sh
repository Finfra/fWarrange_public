#!/bin/bash
# tdd/cases/tool-brew-label.sh — shell tools recognise the brew service under both label conventions (Issue136)
#
# Homebrew renamed service labels from homebrew.mxcl.<formula> to sh.brew.<formula> (Issue95). The Swift
# side was fixed, but cli/_tool/fwc-config.sh still matched only the old label, so `brew_service_running`
# was always false on current brew. fwc-run-xcode.sh then skipped "stop brew before Debug deploy", and
# fwc-test.sh ran its REST/CMD suites while the launchd instance and the Debug app replaced each other
# (jma full run: API 37/38 got no response).
#
# `launchctl` is stubbed as a shell function, so this never touches the real launchd.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/cli/_tool/fwc-config.sh"

PASS=0; FAIL=0
LIST=""
launchctl() { printf 'PID\tStatus\tLabel\n%b' "$LIST"; }

expect() { # expect <0|1> <description>
    if brew_service_running; then got=0; else got=1; fi
    if [ "$got" = "$1" ]; then PASS=$((PASS + 1)); echo "  ✅ $2"
    else FAIL=$((FAIL + 1)); echo "  ❌ $2 (brew_service_running rc=$got, expected $1)"; fi
}

LIST="24650\t0\tsh.brew.fwarrange-cli\n";        expect 0 "sh.brew.* label (current brew) is running"
LIST="24650\t0\thomebrew.mxcl.fwarrange-cli\n";  expect 0 "homebrew.mxcl.* label (old brew) is running"
LIST="-\t78\thomebrew.mxcl.libvirt\n";            expect 1 "unrelated service is not ours"
LIST="2585\t0\tsh.brew.fsnippet-cli\n";           expect 1 "sibling app's service is not ours"
LIST="";                                          expect 1 "nothing loaded"

echo "tool-brew-label: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
