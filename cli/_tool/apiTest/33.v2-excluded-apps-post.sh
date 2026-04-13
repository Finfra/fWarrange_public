#!/bin/bash
# POST /api/v2/settings/restore/excluded-apps (제외 앱 목록에 추가)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X POST "$BASE/settings/restore/excluded-apps" \
  -H "Content-Type: application/json" \
  -d '{"apps": ["Xcode"]}' | jq .
