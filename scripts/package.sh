#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${BUILD_ROOT:-$project_root/build}"
release_dir="${RELEASE_DIR:-$project_root/dist}"
mkdir -p "$release_dir"
xcodebuild -skipPackagePluginValidation -project "$project_root/Portiva.xcodeproj" -scheme Portiva -configuration Release -derivedDataPath "$build_root" build
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/portiva-package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$build_root/Build/Products/Release/Portiva.app" "$stage_dir/Portiva.app"
ln -s /Applications "$stage_dir/Applications"
cp "$project_root/INSTALL.txt" "$stage_dir/Önce okuyun.txt"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$stage_dir/Portiva.app/Contents/Info.plist")
hdiutil create -volname Portiva -srcfolder "$stage_dir" -ov -format UDZO "$release_dir/Portiva-$version.dmg"
hdiutil verify "$release_dir/Portiva-$version.dmg"
codesign --verify --deep --strict "$stage_dir/Portiva.app"
