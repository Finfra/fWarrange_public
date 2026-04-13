#!/bin/bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X DELETE "$BASE/layouts" \
  -H "X-Confirm-Delete-All: true" | jq .
