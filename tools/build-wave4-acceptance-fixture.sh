#!/bin/zsh
set -euo pipefail

project_root=${0:A:h:h}
derived_data=${1:-/private/tmp/syncthingStatus-wave4-ui-fixture}

xcodebuild build \
  -project "$project_root/01_Project/syncthingStatus.xcodeproj" \
  -scheme syncthingStatus \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  PRODUCT_BUNDLE_IDENTIFIER=com.lucesumbrarum.syncthingStatus.wave4fixture \
  PRODUCT_NAME=syncthingStatusWave4Fixture \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG WAVE4_ACCEPTANCE_FIXTURE' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=YES

print -r -- "$derived_data/Build/Products/Debug/syncthingStatusWave4Fixture.app"
