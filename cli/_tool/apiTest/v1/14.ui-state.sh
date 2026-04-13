#!/bin/bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X PUT "$BASE/ui/state" \
  -H "Content-Type: application/json" \
  -d '{"hideWindows": true}' | jq .
