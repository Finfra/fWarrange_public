#!/bin/bash
BASE="http://localhost:3016/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" \
  -H "X-Confirm: true" | jq .
