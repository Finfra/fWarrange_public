#!/bin/bash
# Restore dry-run (interactive) — Issue72_7 (Phase 7-1)
BASE="http://localhost:3016/api/v2"
LAYOUT="test_dryrun"

echo "--- 캡처 ---"
curl -s --max-time 15 -X POST "$BASE/capture" \
  -H "Content-Type: application/json" -d "{\"name\":\"$LAYOUT\"}" | jq '.status'

echo ""
echo "--- dry-run (interactive=true) ---"
curl -s --max-time 20 -X POST "$BASE/layouts/$LAYOUT/restore" \
  -H "Content-Type: application/json" -d '{"interactive":true}' \
  | jq '.status, .data | {total, succeeded, failed, sample: (.results[0:3] | map({matchedTitle, score, matchType, success}))}'

echo ""
echo "--- 실제 적용 (control: interactive 미설정) ---"
curl -s --max-time 20 -X POST "$BASE/layouts/$LAYOUT/restore" \
  -H "Content-Type: application/json" -d '{}' \
  | jq '.status, .data | {total, succeeded, failed}'

echo ""
echo "--- 정리 ---"
curl -s --max-time 5 -X DELETE "$BASE/layouts/$LAYOUT" | jq '.status'
