#!/bin/bash
# 존재하지 않는 레이아웃 조회 → 404
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/layouts/nonexistent_layout_xyz" | jq .
