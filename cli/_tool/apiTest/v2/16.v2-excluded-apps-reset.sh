#!/bin/bash
# POST /api/v2/settings/restore/excluded-apps/reset (제외 앱 목록을 기본값으로 초기화)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 -X POST "$BASE/settings/restore/excluded-apps/reset" | jq .
