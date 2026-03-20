#!/bin/bash
set -e
echo "🚀 Finishing Deployment (Manual Recovery)..."

# 1. Archive & Remove Old App
if [ -d "/Applications/_nowage_app/fWarrange.app" ]; then
    OLD_VER=$(defaults read /Applications/_nowage_app/fWarrange.app/Contents/Info.plist CFBundleShortVersionString)
    echo "📦 Archiving existing v$OLD_VER..."
    cd /Applications/_nowage_app
    zip -r "fWarrange_v${OLD_VER}.zip" fWarrange.app
    echo "🗑️ Removing old app..."
    rm -rf fWarrange.app
    echo "✅ Cleaned up old version."
else
    echo "ℹ️ No existing app found to archive."
fi

# 2. Build & Deploy New Version
echo "🔨 Building v.75..."
cd "$HOME/_git/__all/fWarrange"
# Using standard build command (assuming user shell has correct permissions)
xcodebuild -scheme fWarrange -configuration Debug build -quiet

echo "📦 Deploying new version..."
BUILD_DIR=$(xcodebuild -scheme fWarrange -showBuildSettings | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)

if [ -d "$BUILD_DIR/fWarrange.app" ]; then
    mkdir -p /Applications/_nowage_app
    cp -R "$BUILD_DIR/fWarrange.app" /Applications/_nowage_app/
    xattr -cr /Applications/_nowage_app/fWarrange.app
    
    # Archive new version
    NEW_VER=$(defaults read /Applications/_nowage_app/fWarrange.app/Contents/Info.plist CFBundleShortVersionString)
    cd /Applications/_nowage_app
    zip -r "fWarrange_v${NEW_VER}.zip" fWarrange.app
    
    echo "🎉 Successfully deployed v$NEW_VER!"
    open /Applications/_nowage_app/fWarrange.app
    say "Complished"
else
    echo "❌ Build failed or artifact not found."
    exit 1
fi
