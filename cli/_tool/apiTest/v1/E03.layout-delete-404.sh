#!/bin/bash
# 존재하지 않는 레이아웃 삭제 → 404
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts/nonexistent_layout_xyz" | jq .
