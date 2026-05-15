#!/bin/bash
# Reset normalize rules to built-in — DELETE /normalize-rules (v2)
# Issue72_3 (Phase 3): 빌트인 룰셋으로 리셋
BASE="http://localhost:3016/api/v2"
echo "--- DELETE /normalize-rules (v2, 빌트인 리셋) ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/normalize-rules" | jq '.status, .data.count, .data.message'
