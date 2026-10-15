#!/usr/bin/env bash
# Export the original vector masters through the normal app renderer.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="${CHIIBAR_SWIFTPM_SCRATCH:-$HOME/Library/Caches/ChiiBar/SwiftPM}"
swift build --scratch-path "$scratch"
"$scratch/debug/ChiiBar" --export-sprites Art/Sprites
