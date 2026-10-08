#!/bin/bash
# DELETE /api/v2/layouts (deletes ALL layouts in the live data folder)
# Destructive: runs only with FORCE=1, or inside fwc-test.sh which snapshots and
# restores the data folder (FWC_DATA_SNAPSHOT=1). Issue114
BASE="http://localhost:3016/api/v2"
if [ "${FORCE:-0}" != "1" ] && [ "${FWC_DATA_SNAPSHOT:-0}" != "1" ]; then
  echo "SKIP: destructive test (deletes all layouts). Run with FORCE=1 ./23.v2-layouts-delete-all.sh" >&2
  exit 0
fi
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts" \
  -H "X-Confirm-Delete-All: true" | jq .
