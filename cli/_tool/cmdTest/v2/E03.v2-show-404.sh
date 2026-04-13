#!/bin/bash
# 존재하지 않는 레이아웃 조회 → 404
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI show nonexistent_layout_xyz
echo "exit code: $?"
