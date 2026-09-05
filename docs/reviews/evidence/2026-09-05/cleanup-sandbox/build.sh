#!/bin/zsh
set -eu
base=/private/tmp/syncthingStatus-sandbox-probe
project=/Users/sim/ProgrammingProjects/1-macOS/_Published/syncthingStatus/01_Project
xcrun swiftc -swift-version 5 -module-cache-path "$base/module-cache" "$base/Harness.swift" "$base/ControllerSupport.swift" "$base/ProductionCleanupUI.swift" "$project/syncthingStatus/CleanupConfirmationDialog.swift" "$project/syncthingStatusTests/Support/SettingsFixture.swift" "$project/syncthingStatus/Client.swift" "$project/syncthingStatus/Models.swift" "$project/syncthingStatus/Constants.swift" "$project/syncthingStatus/Helpers.swift" "$project/syncthingStatus/SyncthingSettings.swift" "$project/syncthingStatus/FolderAccessBookmarks.swift" "$project/syncthingStatus/LaunchAtLoginHelper.swift" -o "$base/FixtureAccess.app/Contents/MacOS/FixtureAccess"
codesign --force --sign - --entitlements "$base/entitlements.plist" "$base/FixtureAccess.app"
