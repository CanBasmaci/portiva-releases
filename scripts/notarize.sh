#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_TEAM_ID:?Set your paid Apple Developer team ID}"
: "${NOTARY_PROFILE:?Set the name of your existing notarytool Keychain profile}"
if ! security find-identity -v -p codesigning | grep -q 'Developer ID Application:'; then
    echo 'Developer ID Application certificate with private key is required. Free Apple accounts cannot notarize.' >&2
    exit 1
fi
build_root="${BUILD_ROOT:-$project_root/build/distribution}"
release_dir="${RELEASE_DIR:-$project_root/dist/notarized}"
mkdir -p "$build_root" "$release_dir"
export_plist="$build_root/ExportOptions.plist"
/usr/libexec/PlistBuddy -c Clear -c 'Add :method string developer-id' -c 'Add :signingStyle string manual' -c 'Add :signingCertificate string Developer ID Application' -c "Add :teamID string $DEVELOPER_TEAM_ID" "$export_plist"
xcodebuild -skipPackagePluginValidation -project "$project_root/Portiva.xcodeproj" -scheme Portiva -configuration Release -archivePath "$build_root/Portiva.xcarchive" DEVELOPMENT_TEAM="$DEVELOPER_TEAM_ID" CODE_SIGN_IDENTITY='Developer ID Application' OTHER_CODE_SIGN_FLAGS='--timestamp' archive
xcodebuild -exportArchive -archivePath "$build_root/Portiva.xcarchive" -exportPath "$build_root/export" -exportOptionsPlist "$export_plist"
app_path="$build_root/export/Portiva.app"
codesign --verify --deep --strict "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$build_root/Portiva-notary.zip"
xcrun notarytool submit "$build_root/Portiva-notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$build_root/notary-result.json"
python3 - "$build_root/notary-result.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization not accepted. Inspect notary-result.json and retrieve the submission log.')
PY
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$release_dir/Portiva-$version.zip"
echo "Notarized application and ZIP ready: $release_dir"
echo 'Publish the verified archive and checksums to GitHub Releases. No GitHub upload has been performed.'
