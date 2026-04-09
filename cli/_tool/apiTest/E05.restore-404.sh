#!/bin/bash
# 존재하지 않는 레이아웃 복구 → 404
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/layouts/nonexistent_layout_xyz/restore" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
