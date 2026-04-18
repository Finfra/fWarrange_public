#!/bin/bash
# Health check — GET /health (v2)
BASE="http://localhost:3016/api/v2"
echo "--- GET /health (v2) ---"
curl -s --connect-timeout 3 "$BASE/health" | jq .
