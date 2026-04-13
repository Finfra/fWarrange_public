#!/bin/bash
# Usage: ./07.capture.sh [layout_name] [filterApps]
# filterApps 예: "Safari,iTerm2"
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
FILTER=${2:-}

if [ -n "$FILTER" ]; then
  echo "--- capture with filterApps: $FILTER ---"
  curl -s --connect-timeout 3 -X POST "$BASE/capture" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NAME\", \"filterApps\": [$(echo "$FILTER" | sed 's/[^,]*/"&"/g')]}" | jq .
else
  curl -s --connect-timeout 3 -X POST "$BASE/capture" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NAME\"}" | jq .
fi
