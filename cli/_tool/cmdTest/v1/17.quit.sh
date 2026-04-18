#!/bin/bash
# fWarrangeCli quit 테스트 (위험: all 실행 시 이후 테스트 실패)
# 실행하려면: FORCE=1 ./17.quit.sh
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
if [ "${FORCE:-0}" != "1" ]; then
  echo "SKIP: 데몬 종료 테스트. 실행하려면 FORCE=1 ./17.quit.sh" >&2
  exit 0
fi
$CLI quit --confirm
