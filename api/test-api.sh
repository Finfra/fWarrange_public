#!/bin/bash
# Usage:
#   bash test-api.sh [port]
#
# Arguments:
#   port : (옵션) API 서버 포트 (기본값: 3016)

PORT=${1:-3016}
BASE="http://localhost:$PORT"
PASS=0
FAIL=0

# 색상 코드
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

check() {
    local desc="$1"
    local expected_code="$2"
    local actual_code="$3"
    local body="$4"

    if [ "$actual_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ PASS${NC} [$actual_code] $desc"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} [$actual_code] $desc (expected: $expected_code)"
        echo "  Response: $body"
        FAIL=$((FAIL + 1))
    fi
}

echo "=================================="
echo "fWarrange REST API Test"
echo "Base URL: $BASE"
echo "=================================="
echo ""

# 1. Health Check
echo "--- Health Check ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /" "200" "$CODE" "$BODY"
echo "  $BODY"
echo ""

# 2. Accessibility Status
echo "--- Accessibility ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/status/accessibility")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/status/accessibility" "200" "$CODE" "$BODY"
echo "  $BODY"
echo ""

# 3. Running Apps
echo "--- Running Apps ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/windows/apps")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/windows/apps" "200" "$CODE" "$BODY"
echo ""

# 4. Current Windows
echo "--- Current Windows ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/windows/current")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/windows/current" "200" "$CODE" "$BODY"
echo ""

# 5. Current Windows (filtered)
echo "--- Current Windows (filtered) ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/windows/current?filterApps=Safari")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/windows/current?filterApps=Safari" "200" "$CODE" "$BODY"
echo ""

# 6. Capture
echo "--- Capture ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/v1/capture" \
    -H "Content-Type: application/json" \
    -d '{"name":"test-api-layout"}')
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "POST /api/v1/capture" "200" "$CODE" "$BODY"
echo ""

# 7. List Layouts
echo "--- List Layouts ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/layouts")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/layouts" "200" "$CODE" "$BODY"
echo ""

# 8. Get Layout Detail
echo "--- Layout Detail ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/layouts/test-api-layout")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/layouts/test-api-layout" "200" "$CODE" "$BODY"
echo ""

# 9. Rename Layout
echo "--- Rename Layout ---"
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/api/v1/layouts/test-api-layout" \
    -H "Content-Type: application/json" \
    -d '{"newName":"test-api-renamed"}')
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "PUT /api/v1/layouts/test-api-layout (rename)" "200" "$CODE" "$BODY"
echo ""

# 10. Get renamed layout
echo "--- Renamed Layout Detail ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/layouts/test-api-renamed")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/layouts/test-api-renamed" "200" "$CODE" "$BODY"
echo ""

# 11. Restore Layout
echo "--- Restore Layout ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/v1/layouts/test-api-renamed/restore" \
    -H "Content-Type: application/json" \
    -d '{"maxRetries":2,"retryInterval":0.3}')
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "POST /api/v1/layouts/test-api-renamed/restore" "200" "$CODE" "$BODY"
echo ""

# 12. Delete Layout
echo "--- Delete Layout ---"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/api/v1/layouts/test-api-renamed")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "DELETE /api/v1/layouts/test-api-renamed" "200" "$CODE" "$BODY"
echo ""

# 13. Locale GET
echo "--- Locale GET ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/locale")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/locale" "200" "$CODE" "$BODY"
echo "  $BODY"
echo ""

# 14. Locale PUT
echo "--- Locale PUT ---"
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/api/v1/locale" \
    -H "Content-Type: application/json" \
    -d '{"language":"en"}')
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "PUT /api/v1/locale" "200" "$CODE" "$BODY"
echo "  $BODY"
echo ""

# 15. Remove Windows (capture first, then remove)
echo "--- Remove Windows ---"
# 캡처하여 테스트용 레이아웃 생성
curl -s -X POST "$BASE/api/v1/capture" \
    -H "Content-Type: application/json" \
    -d '{"name":"test-remove-windows"}' > /dev/null 2>&1
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/v1/layouts/test-remove-windows/windows/remove" \
    -H "Content-Type: application/json" \
    -d '{"windowIds":[99999]}')
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "POST /api/v1/layouts/test-remove-windows/windows/remove" "200" "$CODE" "$BODY"
echo "  $BODY"
# 정리
curl -s -X DELETE "$BASE/api/v1/layouts/test-remove-windows" > /dev/null 2>&1
echo ""

# 16. 404 Test
echo "--- 404 Test ---"
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/layouts/nonexistent")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "GET /api/v1/layouts/nonexistent (404)" "404" "$CODE" "$BODY"
echo ""

# 17. Delete All (without header - should fail)
echo "--- Delete All (no header) ---"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/api/v1/layouts")
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -1)
check "DELETE /api/v1/layouts (no header, expect 400)" "400" "$CODE" "$BODY"
echo ""

# Summary
echo "=================================="
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "=================================="
