#!/bin/bash
# 构建 RClick 的本地安装 DMG 包
#
# 用法:
#   ./scripts/package-dmg.sh              # 构建并生成 output/RClick-v<版本>.dmg
#   ./scripts/package-dmg.sh --install    # 构建后安装到 ~/Applications 并重载 Finder 扩展
#
# 说明:
# - Release 配置 + arm64，使用 Xcode 里配置的本地签名，无需 Developer ID 证书
# - 本地打出的 DMG 不带隔离标记，本机双击安装不会被 Gatekeeper 拦截
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="RClick"
PROJECT="RClick.xcodeproj"
SCHEME="RClick"
BUILD_DIR="build"
STAGING="dmg-staging"
OUTPUT_DIR="output"
INSTALL=false

if [ "${1:-}" = "--install" ]; then
  INSTALL=true
fi

echo "==> Building Release (arm64)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination "generic/platform=macOS" \
  ARCHS=arm64 \
  build -quiet

APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d -path "*/Products/Release/*" | head -n 1)
if [ -z "$APP_PATH" ]; then
  echo "Error: $APP_NAME.app not found in build output" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$OUTPUT_DIR/$APP_NAME-v$VERSION.dmg"

echo "==> Staging $APP_NAME v$VERSION..."
rm -rf "$STAGING"
mkdir -p "$STAGING" "$OUTPUT_DIR"
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG_PATH..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" > /dev/null
rm -rf "$STAGING"

hdiutil verify "$DMG_PATH" > /dev/null && echo "==> Checksum OK"
echo "==> Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

if $INSTALL; then
  echo "==> Installing to ~/Applications..."
  osascript -e 'quit app "RClick"' 2> /dev/null || true
  killall RClick 2> /dev/null || true
  sleep 1
  ditto "$APP_PATH" "$HOME/Applications/$APP_NAME.app"
  open "$HOME/Applications/$APP_NAME.app"
  sleep 2
  killall Finder
  echo "==> Installed and Finder reloaded."
fi
