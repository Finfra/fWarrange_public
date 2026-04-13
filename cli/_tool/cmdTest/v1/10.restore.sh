#!/bin/bash
# fWarrangeCli restore 테스트 (사전 조건: 레이아웃 존재)
CLI="${FWARRANGE_CLI:-/Applications/_nowage_app/fWarrangeCli.app/Contents/MacOS/fWarrangeCli}"
NAME=${1:-testCmd}
# 레이아웃 없으면 먼저 캡처
$CLI capture "$NAME" > /dev/null 2>&1
$CLI restore "$NAME" | jq .
