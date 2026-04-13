#!/bin/bash
# PUT /api/v2/settings/restore/excluded-apps (제외 앱 목록 전체 교체)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X PUT "$BASE/settings/restore/excluded-apps" \
  -H "Content-Type: application/json" \
  -d '{"apps": ["Activity Monitor", "System Settings", "Finder"]}' | jq .
