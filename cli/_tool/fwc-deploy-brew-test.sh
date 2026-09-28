#!/bin/bash
# fwc-deploy-brew-test.sh — regression checks for `fwc-deploy-brew.sh publish --dry-run` (Issue112)
#
#   1) dry-run must stop at the precondition step when VERSION is already released
#      (tag / GitHub release exists) — the same way a live publish would.
#   2) dry-run must not report steps it did not execute (tag push, release, tap push) as ✅ PASS.
#
# xcodebuild is stubbed, so check 1 never builds: a missed duplicate check fails fast at
# "Release 빌드" instead of running a real Release build. Check 2 needs a full build and an
# unreleased version, so it runs only with --summary (on a throwaway clone — it rewrites VERSION).
#
# Usage: bash cli/_tool/fwc-deploy-brew-test.sh [--summary]
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$ROOT/cli/_tool/fwc-deploy-brew.sh"
RELEASE_REPO="Finfra/fWarrange_public"
FAIL=0

# ── 1) duplicate version stops the dry-run ──────────────
V=$(tr -d '[:space:]' < "$ROOT/VERSION")
TAG="cli-v$V"
if ! gh release view "$TAG" --repo "$RELEASE_REPO" >/dev/null 2>&1; then
    echo "SKIP 1: $TAG is not released yet — check 1 needs an already released VERSION"
else
    STUB=$(mktemp -d)
    printf '#!/bin/sh\necho "xcodebuild stub: the build step must not be reached"\nexit 99\n' > "$STUB/xcodebuild"
    chmod +x "$STUB/xcodebuild"
    OUT=$(PATH="$STUB:$PATH" bash "$SCRIPT" publish --dry-run 2>&1); RC=$?
    rm -rf "$STUB"
    if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "이미 존재" && ! printf '%s' "$OUT" | grep -q "=== Step 1"; then
        echo "PASS 1: dry-run stops before the build on released $TAG"
    else
        echo "FAIL 1: dry-run did not stop on released $TAG (rc=$RC)"
        printf '%s\n' "$OUT" | grep -E "=== Step|이미 존재|stub|ALL CLEAR|ISSUES" | head -8
        FAIL=1
    fi
fi

# ── 2) dry-run summary marks unexecuted steps ───────────
if [ "${1:-}" = "--summary" ]; then
    FAKE="9.9.$(date +%s | tail -c 4)"
    printf '%s\n' "$FAKE" > "$ROOT/VERSION"
    sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*;/MARKETING_VERSION = ${FAKE};/" \
        "$ROOT/cli/fWarrangeCli.xcodeproj/project.pbxproj"
    OUT=$(bash "$SCRIPT" publish --dry-run 2>&1); RC=$?
    BAD=$(printf '%s\n' "$OUT" | grep -E "✅ (git tag push|gh release|tap push|검증):")
    PLAN=$(printf '%s\n' "$OUT" | grep -cE "⏭ (git tag push|gh release|tap push|검증):")
    if [ "$RC" -eq 0 ] && [ -z "$BAD" ] && [ "$PLAN" -eq 4 ]; then
        echo "PASS 2: dry-run summary marks 4 unexecuted steps as ⏭ (version $FAKE)"
    else
        echo "FAIL 2: dry-run summary (rc=$RC, ⏭ $PLAN/4)"
        printf '%s\n' "$BAD"
        printf '%s\n' "$OUT" | grep -E "ALL CLEAR|ISSUES|❌" | head -5
        FAIL=1
    fi
fi

exit $FAIL
