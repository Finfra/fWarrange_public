#!/bin/bash
# GET /api/v2/settings (전체 설정 조회)
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/settings" | jq .
