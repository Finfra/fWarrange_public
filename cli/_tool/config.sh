#!/bin/bash
# Issue31: Xcode 기반 빌드·배포 공용 설정
# - run-xcode.sh 에서 source로 로드
# - 프로젝트 단위 값 (fSnippetCli 동기화 시 값만 바꿔서 공용)

PROJECT_NAME="fWarrangeCli"
SCHEME="fWarrangeCli"
XCODEPROJ_NAME="fWarrangeCli.xcodeproj"
APP_NAME="fWarrangeCli.app"
DEPLOY_DIR="/Applications/_nowage_app"
APP_PATH="${DEPLOY_DIR}/${APP_NAME}"
CACHE_FILE_NAME=".last_build_path"
CONFIGURATION="${CONFIGURATION:-Debug}"   # 기본 Debug (기존 run.sh와 동일)
