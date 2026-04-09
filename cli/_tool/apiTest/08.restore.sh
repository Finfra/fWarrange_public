#!/bin/bash
# Usage: ./08.restore.sh [layout_name]
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 -X POST "$BASE/layouts/$NAME/restore" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
