#!/bin/bash
# Official Build Components injector (Issue105).
#
# Runs as the last build phase of the fWarrangeCli target, i.e. before Xcode code-signs
# the bundle, so the signature covers whatever is copied here.
#
#   FWARRANGE_OFFICIAL_BUILD=YES → copy cli/resources/official/* and the license notices
#                                  into <bundle>/Contents/Resources/Official/
#   anything else (source build) → make sure that folder does not exist
#
# Only the official build scripts (fwc-deploy-brew.sh local|publish) pass the flag, and
# they always run a *clean* build in their own derived data folder. That matters: Xcode
# does not re-sign an incremental build just because this phase changed the bundle, so
# switching flavors inside one build tree leaves a broken seal ("a sealed resource is
# missing or invalid"). Measured 2026-09-27 — see Issue105.
set -euo pipefail

CLI_ROOT="${SRCROOT:?SRCROOT is not set}"
RES_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR is not set}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH is not set}"
OUT_DIR="$RES_DIR/Official"
COMPONENTS="$CLI_ROOT/resources/official"
REPO_ROOT="$CLI_ROOT/.."

# A source build must never inherit components from an earlier official build.
HAD_COMPONENTS=0
[ -d "$OUT_DIR" ] && HAD_COMPONENTS=1
rm -rf "$OUT_DIR"

if [ "${FWARRANGE_OFFICIAL_BUILD:-NO}" != "YES" ]; then
    if [ "$HAD_COMPONENTS" -eq 1 ]; then
        echo "warning: this build tree held an official build — its code signature is now stale. Run a clean build."
    fi
    echo "Source build: Official Build Components not included"
    exit 0
fi

if [ ! -s "$COMPONENTS/official-build.txt" ]; then
    echo "error: $COMPONENTS/official-build.txt is missing or empty" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
cp "$COMPONENTS/official-build.txt" "$OUT_DIR/"

# DISTRIBUTION-TERMS §6: the terms are presented inside the package as well.
for doc in LICENSE NOTICE TRADEMARK.md DISTRIBUTION-TERMS.md DISTRIBUTION-TERMS_ko.md COMMERCIAL.md; do
    if [ ! -f "$REPO_ROOT/$doc" ]; then
        echo "error: $REPO_ROOT/$doc is missing" >&2
        exit 1
    fi
    cp "$REPO_ROOT/$doc" "$OUT_DIR/"
done

echo "Official build: components copied to $OUT_DIR"
