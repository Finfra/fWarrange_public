#!/bin/bash
# body 없이 rename 요청 → 400
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PUT "$BASE/layouts/testCapture" \
  -H "Content-Type: application/json" | jq .
