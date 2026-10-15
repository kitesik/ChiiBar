#!/usr/bin/env bash
# Render every preview PNG from fixture state into build/previews.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="${CHIIBAR_SWIFTPM_SCRATCH:-$HOME/Library/Caches/ChiiBar/SwiftPM}"
swift build --scratch-path "$scratch"
mkdir -p build/previews
CHIIBAR_SPRITES="$PWD/Art/Sprites" "$scratch/debug/ChiiBar" --render-previews build/previews
