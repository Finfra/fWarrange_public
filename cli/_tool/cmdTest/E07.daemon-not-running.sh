#!/bin/bash
# 데몬 미실행 상태에서 status → 에러
# 주의: 이 테스트는 데몬이 중지된 상태에서 실행해야 함
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
echo "※ 데몬이 중지된 상태에서 실행해야 정상 결과"
$CLI status
echo "exit code: $?"
