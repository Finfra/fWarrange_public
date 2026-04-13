#!/bin/bash
BASE="http://localhost:3016/api/v2"
curl -s --connect-timeout 3 "$BASE/cli/status" | jq .
