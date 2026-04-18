#!/bin/bash
# 에러 테스트: 알 수 없는 settings 탭 지정 → 로컬 CLI 에러
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 settings foobar
