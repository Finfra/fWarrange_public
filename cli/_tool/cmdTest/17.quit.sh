#!/bin/bash
# fWarrangeCli quit 테스트 (위험: 데몬 종료)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
$CLI quit --confirm
