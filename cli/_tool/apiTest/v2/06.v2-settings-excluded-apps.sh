#!/bin/bash
# GET /api/v2/settings/restore/excluded-apps (제외 앱 목록 조회)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/restore/excluded-apps" | jq .
