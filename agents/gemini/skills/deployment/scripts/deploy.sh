#!/bin/bash
set -e

# deploy.sh
# fWarrange 자동 배포 스크립트
# 사용법: ./deploy.sh

# 프로젝트 루트 경로 설정 (스크립트 위치: .agent/skills/deployment/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../../.."
PROJECT_DIR="$PROJECT_ROOT/fWarrange"

cd "$PROJECT_ROOT"

echo "📂 Project Root: $PROJECT_ROOT"

# --- 1. 버전 증가 (Version Bump) ---
echo "⬆️  버전 증가 중..."

if [ -d "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/fWarrange.xcodeproj" ]; then
    cd "$PROJECT_DIR"
else
    echo "❌ 오류: 프로젝트 디렉토리를 찾을 수 없습니다: $PROJECT_DIR"
    exit 1
fi

# 현재 빌드 번호 확인
current_ver=$(agvtool what-version -terse)
echo "   현재 빌드: $current_ver"

# 다음 버전 계산
next_ver=$(echo "$current_ver + 0.01" | bc)
if [ -z "$next_ver" ]; then
    next_ver=$(echo $current_ver | awk '{print $1 + 0.01}')
fi

echo "   다음 버전: $next_ver"

# Marketing Version 업데이트
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $next_ver;/g" fWarrange.xcodeproj/project.pbxproj

# Project Version (Build Number) 업데이트
agvtool new-version -all $next_ver
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $next_ver;/g" fWarrange.xcodeproj/project.pbxproj

echo "✅ 버전이 $next_ver 로 증가되었습니다."

# --- 2. 기존 프로세스 종료 ---
echo "🚫 기존 fWarrange 프로세스 종료 중..."
pkill -f MacOS/fWarrange || true

# 프로세스 완전 종료 대기 (최대 5초)
for i in {1..10}; do
    if ! pgrep -f MacOS/fWarrange > /dev/null 2>&1; then
        break
    fi
    echo "   ⏳ 종료 대기 중... ($((i * 500))ms)"
    sleep 0.5
done

if pgrep -f MacOS/fWarrange > /dev/null 2>&1; then
    echo "   ⚠️ 강제 종료 시도..."
    pkill -9 -f MacOS/fWarrange || true
    sleep 1
fi
echo "   ✅ 프로세스 종료 완료"

# --- 2.1 기존 앱 아카이빙 (Archive Old Version) ---
APP_PATH="/Applications/_nowage_app/fWarrange.app"
if [ -d "$APP_PATH" ]; then
    echo "📦 기존 앱 확인 중..."

    if [ -f "$APP_PATH/Contents/Info.plist" ]; then
        RAW_VER=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)

        if [[ "$RAW_VER" == .* ]]; then
             CLEAN_VER="${RAW_VER#.}"
             OLD_VER="0.${CLEAN_VER}"
        else
             OLD_VER="$RAW_VER"
        fi

        echo "   기존 버전: v$OLD_VER"

        ARCHIVE_NAME="fWarrange_v${OLD_VER}.zip"
        ARCHIVE_PATH="/Applications/_nowage_app/$ARCHIVE_NAME"

        if [ ! -f "$ARCHIVE_PATH" ]; then
            echo "   🗜 v${OLD_VER} 아카이빙 실행..."
            (cd /Applications/_nowage_app && zip -r "$ARCHIVE_NAME" fWarrange.app) || echo "   ❌ Zip command failed"

            if [ -f "$ARCHIVE_PATH" ]; then
                 echo "   ✅ 아카이빙 성공: $ARCHIVE_NAME"
            else
                 echo "   ❌ 아카이빙 실패"
                 exit 1
            fi
        else
            echo "   ℹ️ v${OLD_VER} 아카이브가 이미 존재합니다."
        fi
    else
        echo "⚠️ 경고: Info.plist를 찾을 수 없어 버전을 확인할 수 없습니다."
    fi

    echo "🗑 기존 앱 삭제..."
    rm -rf "$APP_PATH"
fi

# --- 3. Debug 버전 빌드 ---
echo "🔨 Debug 스킴 빌드 중..."
xcodebuild -scheme fWarrange -configuration Debug build -quiet

# --- 4. 배포 (Deploy) ---
echo "📦 /Applications 로 배포 중..."

BUILD_DIR=$(xcodebuild -scheme fWarrange -showBuildSettings | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)

if [ -d "$BUILD_DIR/fWarrange.app" ]; then
    mkdir -p /Applications/_nowage_app
    rm -rf /Applications/_nowage_app/fWarrange.app
    cp -R "$BUILD_DIR/fWarrange.app" /Applications/_nowage_app/

    # Quarantine 속성 제거
    xattr -cr /Applications/_nowage_app/fWarrange.app

    # 아카이빙
    VERSION=$(agvtool what-marketing-version -terse1)
    (cd /Applications/_nowage_app && zip -r "fWarrange_v${VERSION}.zip" fWarrange.app)

    echo "✅ 배포 완료: /Applications/_nowage_app/fWarrange.app"
else
    echo "❌ 빌드 실패 또는 파일을 찾을 수 없음"
    exit 1
fi

# --- 5. 앱 실행 ---
echo "🚀 앱 실행 중..."
open /Applications/_nowage_app/fWarrange.app

# --- 6. Save Point 및 커밋 ---
echo "📝 Issue.md 업데이트 및 커밋 중..."

cd "$PROJECT_ROOT"
DATE=$(date +%Y.%m.%d)

# 1. Main Release Commit
git commit -am "Build $next_ver: Release & Deploy"
RELEASE_HASH=$(git rev-parse --short HEAD)
echo "   Release Commit Hash: $RELEASE_HASH"

# 2. Update Issue.md with Save Point
if [ -f "Issue.md" ]; then
    sed -i '' "/\* Save Point :/a\\
      - $DATE v$next_ver Release ($RELEASE_HASH)
    " Issue.md
    echo "   Issue.md에 Save Point 추가됨 ($RELEASE_HASH)"
else
    echo "⚠️ 경고: 루트에서 Issue.md를 찾을 수 없습니다."
fi

# 3. Documentation Commit
git add Issue.md
git commit -m "Docs: Update Issue.md for v$next_ver (Hash: $RELEASE_HASH)"

echo "🎉 배포 완료! v$next_ver"
