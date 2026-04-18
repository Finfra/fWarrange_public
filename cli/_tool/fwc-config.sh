#!/bin/bash
# Issue32: Xcode 기반 빌드·배포 공용 설정 (fWarrangeCli)
# - fwc-run-xcode.sh 에서 source로 로드
# - pairApp(fSnippetCli) `fsc-config.sh`와 동일 구조. 파일명 충돌 방지를 위해 `fwc-` 접두어 사용

PROJECT_NAME="fWarrangeCli"
SCHEME="fWarrangeCli"
XCODEPROJ_NAME="fWarrangeCli.xcodeproj"
APP_NAME="fWarrangeCli.app"
DEPLOY_DIR="/Applications/_nowage_app"
APP_PATH="${DEPLOY_DIR}/${APP_NAME}"
CACHE_FILE_NAME=".last_build_path"
CONFIGURATION="${CONFIGURATION:-Debug}"   # /run 경로 기본 Debug (TCC 회피)
