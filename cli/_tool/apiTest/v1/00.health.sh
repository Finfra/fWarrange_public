#!/bin/bash
# 서버 루트 (/) 및 versioned health (/api/v2/health) 테스트
BASE="http://localhost:3016/api/v2"
echo "--- GET / (서버 루트) ---"
curl -s --connect-timeout 3 "http://localhost:3016/" | jq .
echo ""
echo "--- GET /api/v2/health (versioned) ---"
curl -s --connect-timeout 3 "$BASE/health" | jq .
