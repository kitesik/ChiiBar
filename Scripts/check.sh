#!/usr/bin/env bash
# Build and run tests. Command Line Tools ship swift-testing but leave its frameworks
# off the default search paths, so pass them explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="${CHIIBAR_SWIFTPM_SCRATCH:-$HOME/Library/Caches/ChiiBar/SwiftPM}"
dev="$(xcode-select -p)"
swift build --scratch-path "$scratch"
if [[ "$dev" == *CommandLineTools ]]; then
    fw="$dev/Library/Developer/Frameworks"
    lib="$dev/Library/Developer/usr/lib"
    export DYLD_FRAMEWORK_PATH="$fw${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
    export DYLD_LIBRARY_PATH="$lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    swift test --scratch-path "$scratch" \
        -Xswiftc -F -Xswiftc "$fw" \
        -Xlinker -rpath -Xlinker "$fw" \
        -Xlinker -rpath -Xlinker "$lib"
else
    swift test --scratch-path "$scratch"
fi
