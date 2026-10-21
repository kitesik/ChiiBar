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
for number in $(seq 0 30); do
    asset=$(printf 'Art/StampNumbers/%02d.png' "$number")
    [[ -s "$asset" ]] || { echo "Missing illustrated number: $asset" >&2; exit 1; }
done
[[ -s Art/StampNumbers/badge-pastel.png ]] || exit 1
cp -R Art/StampNumbers "$app/Contents/Resources/StampNumbers"
iconset="$(mktemp -d "${TMPDIR:-/tmp}/chiibar-icon.XXXXXX")/AppIcon.iconset"
mkdir -p "$iconset"
CHIIBAR_SPRITES="$PWD/Art/Sprites" "$app/Contents/MacOS/ChiiBar" --export-app-icon "$iconset/master.png"
for pixels in 16 32 128 256 512; do
    sips -z "$pixels" "$pixels" "$iconset/master.png" --out "$iconset/icon_${pixels}x${pixels}.png" >/dev/null
    retina=$((pixels * 2))
    sips -z "$retina" "$retina" "$iconset/master.png" --out "$iconset/icon_${pixels}x${pixels}@2x.png" >/dev/null
done
rm "$iconset/master.png"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ChiiBar</string>
    <key>CFBundleIdentifier</key><string>com.chiibar.app</string>
    <key>CFBundleName</key><string>치이카와 키우기</string>
    <key>CFBundleDisplayName</key><string>치이카와 키우기</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon.icns</string>
    <key>CFBundleShortVersionString</key><string>0.5.7</string>
    <key>CFBundleVersion</key><string>65</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
# Remove local build paths from debug symbols before signing.
strip -S "$app/Contents/MacOS/ChiiBar"
if [[ -n "${CHIIBAR_SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$CHIIBAR_SIGN_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
fi
codesign --verify --verbose=1 "$app"
echo "built $app"
