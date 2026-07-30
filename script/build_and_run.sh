#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="VibeStickSetup"
BUNDLE_ID="com.vibestick.setup"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${VIBE_STICK_APP_VERSION:-0.3.11}"
APP_BUILD_VERSION="${VIBE_STICK_APP_BUILD_VERSION:-38}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VIBE_STICK_APP_VERSION must use semantic version format, for example 0.1.7." >&2
  exit 2
fi
if [[ ! "$APP_BUILD_VERSION" =~ ^[1-9][0-9]*$ ]]; then
  echo "VIBE_STICK_APP_BUILD_VERSION must be a positive integer." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/app/macos"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PROJECT_TEMPLATE="$APP_RESOURCES/VibeStickProject"
IDF_EXPORT="${VIBE_STICK_IDF_EXPORT:-$HOME/esp/vibestick-esp-idf-v5.5.1/export.sh}"

if [[ ! -f "$IDF_EXPORT" ]]; then
  echo "Release builds require ESP-IDF 5.5.x on the release machine: $IDF_EXPORT" >&2
  exit 1
fi
(cd "$ROOT_DIR/release" && /usr/bin/shasum -a 256 --check assets.sha256)
(cd "$ROOT_DIR/firmware/sticks3" && "$ROOT_DIR/scripts/run-idf.sh" --export "$IDF_EXPORT" build)

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -TERM -x "$APP_NAME" >/dev/null 2>&1 || true
  for _ in {1..100}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "VibeStick Setup is still shutting down; wait for its active operation to cancel safely." >&2
    exit 1
  fi
fi

if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  ARM64_TRIPLE="arm64-apple-macosx${MIN_SYSTEM_VERSION}"
  X86_64_TRIPLE="x86_64-apple-macosx${MIN_SYSTEM_VERSION}"
  swift build --package-path "$PACKAGE_DIR" --configuration release --triple "$ARM64_TRIPLE"
  swift build --package-path "$PACKAGE_DIR" --configuration release --triple "$X86_64_TRIPLE"
  ARM64_BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --configuration release --triple "$ARM64_TRIPLE" --show-bin-path)"
  X86_64_BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --configuration release --triple "$X86_64_TRIPLE" --show-bin-path)"
else
  swift build --package-path "$PACKAGE_DIR" --configuration release
  BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --configuration release --show-bin-path)"
  BUILD_BINARY="$BUILD_DIR/$APP_NAME"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$PROJECT_TEMPLATE"
if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  /usr/bin/lipo -create \
    "$ARM64_BUILD_DIR/$APP_NAME" \
    "$X86_64_BUILD_DIR/$APP_NAME" \
    -output "$APP_BINARY"
else
  cp "$BUILD_BINARY" "$APP_BINARY"
fi
chmod +x "$APP_BINARY"

# Bundle the app icon. Source SVG: assets/brand/vibestick-icon.svg; the .icns
# is pre-rendered and committed so the build needs no rasterizer.
if [[ -f "$PACKAGE_DIR/AppIcon.icns" ]]; then
  cp "$PACKAGE_DIR/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

# Bundle a clean, writable-on-first-run project template. Never copy the
# checkout's .env, firmware secrets, build products, or downloaded components.
cp "$ROOT_DIR/.env.example" "$PROJECT_TEMPLATE/.env.example"
mkdir -p \
  "$PROJECT_TEMPLATE/app/macos" \
  "$PROJECT_TEMPLATE/bridge" \
  "$PROJECT_TEMPLATE/firmware/sticks3" \
  "$PROJECT_TEMPLATE/release/firmware" \
  "$PROJECT_TEMPLATE/release/macos/VibeStickMenuBar.app/Contents/MacOS" \
  "$PROJECT_TEMPLATE/release/runtime" \
  "$PROJECT_TEMPLATE/release/tools" \
  "$PROJECT_TEMPLATE/scripts" \
  "$PROJECT_TEMPLATE/tools/nvs"
/usr/bin/rsync -a --exclude '__pycache__/' \
  "$ROOT_DIR/bridge/src" "$PROJECT_TEMPLATE/bridge/"
/usr/bin/rsync -a --exclude '__pycache__/' \
  "$ROOT_DIR/bridge/tools" "$PROJECT_TEMPLATE/bridge/"
cp "$ROOT_DIR/bridge/pyproject.toml" "$PROJECT_TEMPLATE/bridge/pyproject.toml"
/usr/bin/rsync -a --exclude 'vibe_stick_secrets.h' \
  "$ROOT_DIR/firmware/sticks3/include" "$PROJECT_TEMPLATE/firmware/sticks3/"
/usr/bin/rsync -a \
  "$ROOT_DIR/firmware/sticks3/src" \
  "$ROOT_DIR/firmware/sticks3/generated" \
  "$PROJECT_TEMPLATE/firmware/sticks3/"
/usr/bin/rsync -a \
  "$ROOT_DIR/firmware/sticks3/components" \
  "$PROJECT_TEMPLATE/firmware/sticks3/"
cp \
  "$ROOT_DIR/firmware/sticks3/CMakeLists.txt" \
  "$ROOT_DIR/firmware/sticks3/partitions.csv" \
  "$ROOT_DIR/firmware/sticks3/sdkconfig.defaults" \
  "$ROOT_DIR/firmware/sticks3/dependencies.lock" \
  "$PROJECT_TEMPLATE/firmware/sticks3/"
/usr/bin/rsync -a --include '*.sh' --exclude '*' \
  "$ROOT_DIR/scripts/" "$PROJECT_TEMPLATE/scripts/"
/usr/bin/rsync -a --include '*.py' --exclude '*' \
  "$ROOT_DIR/scripts/" "$PROJECT_TEMPLATE/scripts/"
/usr/bin/rsync -a \
  "$ROOT_DIR/app/macos/VibeStickHUD" \
  "$ROOT_DIR/app/macos/VibeStickMenuBar" \
  "$PROJECT_TEMPLATE/app/macos/"

# Release payloads are built once here; the consumer installer never invokes
# idf.py or swiftc. Keep firmware filenames and offsets stable for the signed
# manifest and the runtime flashing script.
cp "$ROOT_DIR/firmware/sticks3/build/bootloader/bootloader.bin" \
  "$PROJECT_TEMPLATE/release/firmware/bootloader.bin"
cp "$ROOT_DIR/firmware/sticks3/build/partition_table/partition-table.bin" \
  "$PROJECT_TEMPLATE/release/firmware/partition-table.bin"
cp "$ROOT_DIR/firmware/sticks3/build/vibe_stick_sticks3.bin" \
  "$PROJECT_TEMPLATE/release/firmware/vibestick.bin"
/usr/bin/rsync -a "$ROOT_DIR/release/runtime/" "$PROJECT_TEMPLATE/release/runtime/"
/usr/bin/rsync -a "$ROOT_DIR/release/tools/" "$PROJECT_TEMPLATE/release/tools/"
cp "$ROOT_DIR/release/assets.sha256" "$PROJECT_TEMPLATE/release/assets.sha256"
/usr/bin/rsync -a "$ROOT_DIR/tools/nvs/" "$PROJECT_TEMPLATE/tools/nvs/"

HUD_SOURCE="$ROOT_DIR/app/macos/VibeStickHUD/main.swift"
MENUBAR_SOURCE="$ROOT_DIR/app/macos/VibeStickMenuBar/main.swift"
HUD_RELEASE="$PROJECT_TEMPLATE/release/macos/VibeStickHUD"
MENUBAR_RELEASE="$PROJECT_TEMPLATE/release/macos/VibeStickMenuBar.app/Contents/MacOS/VibeStickMenuBar"
if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  /usr/bin/xcrun swiftc "$HUD_SOURCE" -target "arm64-apple-macosx11.0" \
    -o "$DIST_DIR/.VibeStickHUD-arm64" -framework AppKit -framework QuartzCore
  /usr/bin/xcrun swiftc "$HUD_SOURCE" -target "x86_64-apple-macosx11.0" \
    -o "$DIST_DIR/.VibeStickHUD-x86_64" -framework AppKit -framework QuartzCore
  /usr/bin/lipo -create "$DIST_DIR/.VibeStickHUD-arm64" "$DIST_DIR/.VibeStickHUD-x86_64" -output "$HUD_RELEASE"
  /usr/bin/xcrun swiftc "$MENUBAR_SOURCE" -target "arm64-apple-macosx11.0" \
    -o "$DIST_DIR/.VibeStickMenuBar-arm64" -framework AppKit -framework Foundation
  /usr/bin/xcrun swiftc "$MENUBAR_SOURCE" -target "x86_64-apple-macosx11.0" \
    -o "$DIST_DIR/.VibeStickMenuBar-x86_64" -framework AppKit -framework Foundation
  /usr/bin/lipo -create "$DIST_DIR/.VibeStickMenuBar-arm64" "$DIST_DIR/.VibeStickMenuBar-x86_64" -output "$MENUBAR_RELEASE"
  rm -f "$DIST_DIR/.VibeStickHUD-arm64" "$DIST_DIR/.VibeStickHUD-x86_64" \
    "$DIST_DIR/.VibeStickMenuBar-arm64" "$DIST_DIR/.VibeStickMenuBar-x86_64"
else
  /usr/bin/xcrun swiftc "$HUD_SOURCE" -o "$HUD_RELEASE" -framework AppKit -framework QuartzCore
  /usr/bin/xcrun swiftc "$MENUBAR_SOURCE" -o "$MENUBAR_RELEASE" -framework AppKit -framework Foundation
fi
chmod 755 "$HUD_RELEASE" "$MENUBAR_RELEASE"

cat > "$PROJECT_TEMPLATE/release/macos/VibeStickMenuBar.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>VibeStickMenuBar</string>
  <key>CFBundleDisplayName</key><string>VibeStick</string>
  <key>CFBundleExecutable</key><string>VibeStickMenuBar</string>
  <key>CFBundleIdentifier</key><string>com.vibestick.menubar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

(cd "$PROJECT_TEMPLATE/release/firmware" && \
  /usr/bin/shasum -a 256 bootloader.bin partition-table.bin vibestick.bin > manifest.sha256)
BOOT_HASH="$(/usr/bin/shasum -a 256 "$PROJECT_TEMPLATE/release/firmware/bootloader.bin" | /usr/bin/awk '{print $1}')"
PART_HASH="$(/usr/bin/shasum -a 256 "$PROJECT_TEMPLATE/release/firmware/partition-table.bin" | /usr/bin/awk '{print $1}')"
APP_HASH="$(/usr/bin/shasum -a 256 "$PROJECT_TEMPLATE/release/firmware/vibestick.bin" | /usr/bin/awk '{print $1}')"
BOOT_SIZE="$(/usr/bin/stat -f %z "$PROJECT_TEMPLATE/release/firmware/bootloader.bin")"
PART_SIZE="$(/usr/bin/stat -f %z "$PROJECT_TEMPLATE/release/firmware/partition-table.bin")"
APP_SIZE="$(/usr/bin/stat -f %z "$PROJECT_TEMPLATE/release/firmware/vibestick.bin")"
cat > "$PROJECT_TEMPLATE/release/firmware/manifest.json" <<JSON
{
  "schema": 1,
  "product": "VibeStick",
  "version": "$APP_VERSION",
  "chip": "esp32s3",
  "flash_size": "8MB",
  "files": [
    {"offset": "0x0", "path": "bootloader.bin", "size": $BOOT_SIZE, "sha256": "$BOOT_HASH"},
    {"offset": "0x8000", "path": "partition-table.bin", "size": $PART_SIZE, "sha256": "$PART_HASH"},
    {"offset": "0x10000", "path": "vibestick.bin", "size": $APP_SIZE, "sha256": "$APP_HASH"}
  ],
  "configuration": {"offset": "0x610000", "size": "0x6000", "schema": 1}
}
JSON

for required in \
  .env.example \
  scripts/install.sh \
  scripts/install-python-runtime.sh \
  scripts/flash-prebuilt.sh \
  scripts/prepare-device-config.py \
  scripts/probe-rom-mode.sh \
  scripts/release-tool.sh \
  scripts/start-device.sh \
  scripts/verify-release-assets.sh \
  scripts/wait-for-device.sh \
  scripts/doctor.sh \
  bridge/src/vibe_stick/__init__.py \
  bridge/tools/vibe_stick_mic_recorder.swift \
  app/macos/VibeStickHUD/main.swift \
  app/macos/VibeStickMenuBar/main.swift \
  firmware/sticks3/CMakeLists.txt \
  firmware/sticks3/partitions.csv \
  firmware/sticks3/include/vibe_stick_secrets.example.h \
  release/firmware/bootloader.bin \
  release/firmware/partition-table.bin \
  release/firmware/vibestick.bin \
  release/firmware/manifest.json \
  release/firmware/manifest.sha256 \
  release/macos/VibeStickHUD \
  release/macos/VibeStickMenuBar.app/Contents/MacOS/VibeStickMenuBar \
  release/runtime/cpython-3.12.13-aarch64.tar.gz \
  release/runtime/cpython-3.12.13-x86_64.tar.gz \
  release/tools/esptool/arm64/esptool \
  release/tools/esptool/x86_64/esptool \
  tools/nvs/esp_idf_nvs_partition_gen/__main__.py; do
  if [[ ! -f "$PROJECT_TEMPLATE/$required" ]]; then
    echo "Missing bundled project resource: $required" >&2
    exit 1
  fi
done
if [[ -e "$PROJECT_TEMPLATE/.env" \
   || -e "$PROJECT_TEMPLATE/firmware/sticks3/include/vibe_stick_secrets.h" ]]; then
  echo "Refusing to package local VibeStick secrets." >&2
  exit 1
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>VibeStick 安装器</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
SIGNING_IDENTITY="${VIBE_STICK_SIGNING_IDENTITY:-}"
SIGNING_KIND="${VIBE_STICK_SIGNING_KIND:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
      | /usr/bin/awk '/Developer ID Application:/ { print $2; exit }'
  )"
  [[ -z "$SIGNING_IDENTITY" ]] || SIGNING_KIND="developer-id"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
      | /usr/bin/awk '/Apple Development:/ { print $2; exit }'
  )"
  [[ -z "$SIGNING_IDENTITY" ]] || SIGNING_KIND="apple-development"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="-"
  SIGNING_KIND="ad-hoc"
fi
if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  if [[ "$SIGNING_KIND" != "developer-id" ]]; then
    echo "Public packages require a Developer ID Application signing identity." >&2
    exit 1
  fi
  if [[ -z "${VIBE_STICK_NOTARY_PROFILE:-}" ]]; then
    echo "Public packages require VIBE_STICK_NOTARY_PROFILE for notarization." >&2
    exit 1
  fi
fi
NESTED_HUD="$PROJECT_TEMPLATE/release/macos/VibeStickHUD"
NESTED_MENUBAR="$PROJECT_TEMPLATE/release/macos/VibeStickMenuBar.app"
NESTED_ESPTOOL_ARM64="$PROJECT_TEMPLATE/release/tools/esptool/arm64/esptool"
NESTED_ESPTOOL_X86_64="$PROJECT_TEMPLATE/release/tools/esptool/x86_64/esptool"
ESPTOOL_ENTITLEMENTS="$ROOT_DIR/app/macos/Esptool.entitlements"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --options runtime --sign - "$NESTED_HUD" >/dev/null
  /usr/bin/codesign --force --options runtime --sign - "$NESTED_MENUBAR" >/dev/null
  /usr/bin/codesign --force --options runtime --entitlements "$ESPTOOL_ENTITLEMENTS" --sign - "$NESTED_ESPTOOL_ARM64" >/dev/null
  /usr/bin/codesign --force --options runtime --entitlements "$ESPTOOL_ENTITLEMENTS" --sign - "$NESTED_ESPTOOL_X86_64" >/dev/null
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$NESTED_HUD" >/dev/null
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$NESTED_MENUBAR" >/dev/null
  /usr/bin/codesign --force --options runtime --entitlements "$ESPTOOL_ENTITLEMENTS" --timestamp --sign "$SIGNING_IDENTITY" "$NESTED_ESPTOOL_ARM64" >/dev/null
  /usr/bin/codesign --force --options runtime --entitlements "$ESPTOOL_ENTITLEMENTS" --timestamp --sign "$SIGNING_IDENTITY" "$NESTED_ESPTOOL_X86_64" >/dev/null
fi

# The source manifest pins Espressif's upstream binaries. The bundled manifest
# pins the signed copies that the consumer installer will execute.
(cd "$PROJECT_TEMPLATE/release" && /usr/bin/shasum -a 256 \
  tools/esptool/arm64/esptool \
  tools/esptool/x86_64/esptool \
  runtime/cpython-3.12.13-aarch64.tar.gz \
  runtime/cpython-3.12.13-x86_64.tar.gz > assets.sha256)

# Hash the exact nested payload that will be refreshed into Application Support.
PROJECT_TEMPLATE_VERSION="$(
  cd "$PROJECT_TEMPLATE"
  find . -type f ! -name .vibestick-template-version -print \
    | LC_ALL=C sort \
    | while IFS= read -r file; do /usr/bin/shasum -a 256 "$file"; done \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{ print $1 }'
)"
printf '%s\n' "$PROJECT_TEMPLATE_VERSION" > "$PROJECT_TEMPLATE/.vibestick-template-version"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --options runtime --sign - "$APP_BUNDLE" >/dev/null
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE" >/dev/null
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build)
    # Build, bundle and codesign only — do not launch the GUI.
    echo "Built $APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    /usr/bin/codesign --verify --strict "$APP_BUNDLE"
    ;;
  --package|package)
    /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
    /usr/bin/file "$APP_BINARY"
    DMG_PATH="$DIST_DIR/VibeStickSetup-$APP_VERSION.dmg"
    DMG_STAGE="$DIST_DIR/.VibeStickSetup-dmg"
    rm -rf "$DMG_STAGE" "$DMG_PATH"
    mkdir -p "$DMG_STAGE"
    cp -R "$APP_BUNDLE" "$DMG_STAGE/"
    ln -s /Applications "$DMG_STAGE/Applications"
    /usr/bin/hdiutil create -quiet -volname "VibeStick Setup" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
    rm -rf "$DMG_STAGE"
    /usr/bin/codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$VIBE_STICK_NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$DMG_PATH"
    /usr/bin/xcrun stapler validate "$DMG_PATH"
    echo "Packaged $DMG_PATH"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
