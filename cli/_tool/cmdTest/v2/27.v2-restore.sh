#!/bin/bash
# fWarrangeCli restore 테스트 (v2 경로)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmdV2}
# 레이아웃 없으면 먼저 캡처
$CLI capture "$NAME" > /dev/null 2>&1
$CLI restore "$NAME" | jq .
