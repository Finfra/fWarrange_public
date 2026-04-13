#!/bin/bash
# fWarrangeCli delete-all 테스트 (v2 경로, 위험: 모든 레이아웃 삭제)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI delete-all --confirm | jq .
