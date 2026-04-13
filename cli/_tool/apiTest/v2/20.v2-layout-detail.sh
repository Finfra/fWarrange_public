#!/bin/bash
# Usage: ./20.v2-layout-detail.sh [layout_name]
BASE="http://localhost:3016/api/v2"
NAME=${1:-testCapture}
curl -s --connect-timeout 3 "$BASE/layouts/$NAME" | jq .
