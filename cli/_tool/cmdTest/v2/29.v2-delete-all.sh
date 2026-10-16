#!/bin/bash
# fWarrangeCli delete-all (deletes ALL layouts in the live data folder)
# Destructive: runs only with FORCE=1, or inside fwc-test.sh which snapshots and
# restores the data folder (FWC_DATA_SNAPSHOT=1). Issue114
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
if [ "${FORCE:-0}" != "1" ] && [ "${FWC_DATA_SNAPSHOT:-0}" != "1" ]; then
  echo "SKIP: destructive test (deletes all layouts). Run with FORCE=1 ./29.v2-delete-all.sh" >&2
  exit 0
fi
$CLI delete-all --confirm | jq .
