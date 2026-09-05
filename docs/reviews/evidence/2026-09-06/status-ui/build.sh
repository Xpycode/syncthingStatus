#!/bin/zsh
set -eu
here=${0:A:h}
root=${here:h:h:h:h:h}
project="$root/01_Project"
tmp=/private/tmp/syncthingStatus-status-ui-probe
app="$tmp/StatusUIFixture.app"
developer_frameworks="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/Library/Frameworks"
developer_swift_lib="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/usr/lib"

python3 "$here/extract-ui.py"
rm -rf "$tmp"
mkdir -p "$app/Contents/MacOS" "$tmp/module-cache"
cp "$here/fixture-Info.plist" "$app/Contents/Info.plist"
export CLANG_MODULE_CACHE_PATH="$tmp/module-cache"
export SWIFT_MODULECACHE_PATH="$tmp/module-cache"

xcrun swiftc -swift-version 5 -module-cache-path "$tmp/module-cache" \
  -I "$developer_swift_lib" -L "$developer_swift_lib" -lXCTestSwiftSupport \
  -F "$developer_frameworks" -framework XCTest \
  -Xlinker -rpath -Xlinker "$developer_frameworks" -Xlinker -rpath -Xlinker "$developer_swift_lib" \
  "$here/Harness.swift" "$here/ProductionStatusRows.swift" \
  "$project/syncthingStatus/Client.swift" "$project/syncthingStatus/Models.swift" \
  "$project/syncthingStatus/Constants.swift" "$project/syncthingStatus/Helpers.swift" \
  "$project/syncthingStatus/SyncStatusPolicy.swift" "$project/syncthingStatus/SyncStatusPresentation.swift" \
  "$project/syncthingStatus/SyncthingSettings.swift" "$project/syncthingStatus/FolderAccessBookmarks.swift" \
  "$project/syncthingStatus/LaunchAtLoginHelper.swift" \
  "$project/syncthingStatusTests/Support/SettingsFixture.swift" \
  "$project/syncthingStatusTests/Support/StubURLProtocol.swift" \
  -o "$app/Contents/MacOS/StatusUIFixture"
xcrun swiftc "$here/AXStatusDump.swift" -o "$tmp/ax-status-dump"
codesign --force --sign - --entitlements "$here/entitlements.plist" "$app"
echo "built=$app"
