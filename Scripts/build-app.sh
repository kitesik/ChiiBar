#!/usr/bin/env bash
# Release build into build/ChiiBar.app (menu bar only, ad-hoc signed). Does not install or launch.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="${CHIIBAR_SWIFTPM_SCRATCH:-$HOME/Library/Caches/ChiiBar/SwiftPM}"
if [[ "${CHIIBAR_UNIVERSAL:-0}" == 1 ]]; then
    for arch in arm64 x86_64; do
        swift build -c release --scratch-path "$scratch" --triple "$arch-apple-macosx14.0"
    done
    arm_dir="$(swift build -c release --scratch-path "$scratch" --triple arm64-apple-macosx14.0 --show-bin-path)"
    intel_dir="$(swift build -c release --scratch-path "$scratch" --triple x86_64-apple-macosx14.0 --show-bin-path)"
    mkdir -p build
    lipo -create "$arm_dir/ChiiBar" "$intel_dir/ChiiBar" -output build/ChiiBar-universal
    binary=build/ChiiBar-universal
else
    swift build -c release --scratch-path "$scratch"
    bin_dir="$(swift build -c release --scratch-path "$scratch" --show-bin-path)"
    binary="$bin_dir/ChiiBar"
fi
app=build/ChiiBar.app
if [[ -d "$app" ]]; then
    backup="$(mktemp -d "${TMPDIR:-/tmp}/chiibar-build.XXXXXX")"
    mv "$app" "$backup/ChiiBar.app"
fi
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/ChiiBar"
# Drawn artwork, when there is any, replaces the code drawings (see Sources/ChiiBar/SpriteArt.swift).
if [[ -d Art/Sprites ]]; then
    mkdir -p "$app/Contents/Resources"
    mkdir -p "$app/Contents/Resources/Sprites"
    cp -R Art/Sprites/Manga "$app/Contents/Resources/Sprites/Manga"
fi
cp -R Art/Homes "$app/Contents/Resources/Homes"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ChiiBar</string>
    <key>CFBundleIdentifier</key><string>com.chiibar.app</string>
    <key>CFBundleName</key><string>신분상승 토큰 치이카와</string>
    <key>CFBundleDisplayName</key><string>신분상승 토큰 치이카와</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.4.10</string>
    <key>CFBundleVersion</key><string>38</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
# Remove local build paths from debug symbols before signing.
strip -S "$app/Contents/MacOS/ChiiBar"
codesign --force --sign - "$app"
codesign --verify --verbose=1 "$app"
echo "built $app"
