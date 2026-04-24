#!/bin/bash
# Usage: ./10.windows-current.sh [filterApps]
BASE="http://localhost:3016/api/v2"
FILTER=${1:-}
URL="$BASE/windows/current"
[ -n "$FILTER" ] && URL="$URL?filterApps=$FILTER"
curl -s --connect-timeout 3 "$URL" | jq .
