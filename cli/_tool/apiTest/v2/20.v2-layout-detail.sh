#!/bin/bash
# Usage: ./20.v2-layout-detail.sh [layout_name]
# No argument: capture its own fixture, read it, then delete it (Issue134).
# Runs before 24.v2-capture, so it must not depend on a `testCapture` left behind by earlier runs
# — on a clean data folder (jma) that layout does not exist and the detail call returned 404.
BASE="http://localhost:3016/api/v2"

if [ -n "$1" ]; then
  curl -s --connect-timeout 3 "$BASE/layouts/$1" | jq .
  exit 0
fi

TEST_NAME="_apitest_detail"

# Setup: capture a fixture layout
curl -s --connect-timeout 3 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_NAME\"}" > /dev/null

# Run: layout detail
curl -s --connect-timeout 3 "$BASE/layouts/$TEST_NAME" | jq .

# Cleanup
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/$TEST_NAME" > /dev/null
