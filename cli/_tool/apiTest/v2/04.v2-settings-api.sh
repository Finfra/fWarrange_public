#!/bin/bash
# GET /api/v2/settings/api (API 탭 설정 조회)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/api" | jq .
