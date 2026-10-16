#!/usr/bin/env bash
# Public distribution requires Developer ID, Apple notarization and a stapled ticket.
# Credentials stay in the login keychain, never in this repository or command arguments.
set -euo pipefail
cd "$(dirname "$0")/.."
app=build/ChiiBar.app
[[ -n "${CHIIBAR_NOTARY_PROFILE:-}" ]] || { echo 'Set CHIIBAR_NOTARY_PROFILE to your existing notarytool keychain profile.' >&2; exit 1; }
[[ -d "$app" ]] || { echo 'Build the signed app first.' >&2; exit 1; }
metadata=$(codesign -dv --verbose=4 "$app" 2>&1)
[[ "$metadata" == *'Authority=Developer ID Application:'* ]] || { echo 'Developer ID Application signature required; ad-hoc builds cannot be notarized.' >&2; exit 1; }
[[ "$metadata" == *'runtime'* ]] || { echo 'Hardened runtime required.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
work_dir=$(mktemp -d /tmp/chiibar-notarization.XXXXXX)
ditto -c -k --keepParent "$app" "$work_dir/ChiiBar.zip"
xcrun notarytool submit "$work_dir/ChiiBar.zip" --keychain-profile "$CHIIBAR_NOTARY_PROFILE" --wait --output-format json > "$work_dir/result.json"
python3 - "$work_dir/result.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    sys.exit('Apple notarization was not accepted. Inspect the local result before distributing.')
print('Apple notarization accepted.')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
# Repackage AFTER stapling: this is the only artifact to publish.
archive="build/ChiiBar-${version}-notarized-universal.zip"
ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive"
echo "Verified notarized release: $archive"
