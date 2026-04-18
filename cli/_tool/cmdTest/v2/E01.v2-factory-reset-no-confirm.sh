#!/bin/bash
# 에러 테스트: --confirm 없이 factory-reset → 로컬 CLI 에러
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI v2 factory-reset
