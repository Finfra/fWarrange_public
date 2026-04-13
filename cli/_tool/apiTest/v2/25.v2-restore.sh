#!/bin/bash
# Usage: ./25.v2-restore.sh [layout_name]
BASE="http://localhost:3016/api/v2"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 -X POST "$BASE/layouts/$NAME/restore" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
