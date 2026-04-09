#!/bin/bash
# Usage: ./03.layout-detail.sh [layout_name]
BASE="http://localhost:3016/api/v1"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 "$BASE/layouts/$NAME" | jq .
