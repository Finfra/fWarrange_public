#!/bin/bash
# Restore 3 modes — POST /layouts/{name}/restore with mode (strict/normal/loose)
# Issue72_5 (Phase 5)
BASE="http://localhost:3016/api/v2"
LAYOUT="test_phase5_modes"

echo "--- 1) 캡처 ---"
curl -s --max-time 15 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" -d "{\"name\":\"$LAYOUT\"}" | jq '.status, (.data.windows | length)'

for MODE in strict normal loose; do
  echo ""
  echo "--- 2.$MODE) restore mode=$MODE ---"
  curl -s --max-time 20 -X POST "$BASE/layouts/$LAYOUT/restore" \
    -H "Content-Type: application/json" -d "{\"mode\":\"$MODE\"}" \
    | jq '.status, .data | {total, succeeded, failed}'
done

echo ""
echo "--- 3) 정리 ---"
curl -s --max-time 5 -X DELETE "$BASE/layouts/$LAYOUT" | jq '.status'
