#!/bin/bash
#
# install-debug-build.sh — replace /Applications/syncthingStatus.app with a
# locally-built Debug zip and relaunch.
#
# Companion to tools/repair-install.sh, which pulls a notarized release from
# GitHub. This one is for the iterate-on-M1-Max loop: AirDrop the Debug zip
# from the M4, run this, watch logs.
#
# Usage:
#   ./install-debug-build.sh
#       Installs from ~/Desktop/syncthingStatus-v1.6.0-debug.zip (default).
#
#   ./install-debug-build.sh /path/to/some-debug.zip
#       Installs from an explicit zip path.
#
# Safe to re-run; idempotent.

set -euo pipefail

DEFAULT_ZIP="${HOME}/Desktop/syncthingStatus-v1.6.0-debug.zip"
APP_NAME="syncthingStatus"
BUNDLE_ID="com.lucesumbrarum.syncthingStatus"
CANONICAL_PATH="/Applications/${APP_NAME}.app"

ZIP_PATH="${1:-$DEFAULT_ZIP}"
TS=$(date +%Y%m%d-%H%M%S)
TMPDIR_LOCAL=$(mktemp -d)

trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

say()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m  %s\n" "$*"; }
fail() { printf "\033[1;31mxx\033[0m  %s\n" "$*" >&2; exit 1; }

# --- 1. validate input ------------------------------------------------------
[[ -f "$ZIP_PATH" ]] || fail "Zip not found: $ZIP_PATH"
say "Source: $ZIP_PATH"

# --- 2. unzip into temp + sanity-check bundle id ----------------------------
say "Unpacking…"
/usr/bin/ditto -x -k "$ZIP_PATH" "$TMPDIR_LOCAL"
src_app="${TMPDIR_LOCAL}/${APP_NAME}.app"
[[ -d "$src_app" ]] || fail "Zip did not contain ${APP_NAME}.app at top level."

src_id=$(/usr/bin/plutil -extract CFBundleIdentifier raw "${src_app}/Contents/Info.plist" 2>/dev/null || echo "")
[[ "$src_id" == "$BUNDLE_ID" ]] || fail "Bundle id mismatch: '$src_id' (expected $BUNDLE_ID)."

src_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "${src_app}/Contents/Info.plist")
src_build=$(/usr/bin/plutil -extract CFBundleVersion raw "${src_app}/Contents/Info.plist")
say "Incoming: ${APP_NAME} ${src_version} (build ${src_build})"

# Strip quarantine — AirDrop / Safari / Mail set this and it triggers
# Gatekeeper warnings on first launch even for self-signed Debug builds.
say "Stripping quarantine xattr…"
/usr/bin/xattr -dr com.apple.quarantine "$src_app" 2>/dev/null || true

# --- 3. quit running instance -----------------------------------------------
if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    say "Quitting running ${APP_NAME}…"
    /usr/bin/killall "$APP_NAME" 2>/dev/null || true
    # Give it a beat to flush UserDefaults before we replace the bundle.
    sleep 1
fi

# --- 4. stash existing install (recoverable) --------------------------------
if [[ -d "$CANONICAL_PATH" ]]; then
    old_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "${CANONICAL_PATH}/Contents/Info.plist" 2>/dev/null || echo "?")
    old_build=$(/usr/bin/plutil -extract CFBundleVersion raw "${CANONICAL_PATH}/Contents/Info.plist" 2>/dev/null || echo "?")
    say "Stashing existing install (${old_version} build ${old_build}) → Trash"
    mv "$CANONICAL_PATH" "${HOME}/.Trash/$(basename "$CANONICAL_PATH") (${TS})"
fi

# --- 5. install -------------------------------------------------------------
say "Installing to ${CANONICAL_PATH}…"
/bin/cp -R "$src_app" "$CANONICAL_PATH"

# --- 6. launch + show what's running ----------------------------------------
say "Launching…"
/usr/bin/open "$CANONICAL_PATH"

installed_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "${CANONICAL_PATH}/Contents/Info.plist")
installed_build=$(/usr/bin/plutil -extract CFBundleVersion raw "${CANONICAL_PATH}/Contents/Info.plist")
say "Now running: ${APP_NAME} ${installed_version} (build ${installed_build})"

cat <<TIP

Tail StuckDeletes logs in another terminal:

  /usr/bin/log stream --predicate 'subsystem == "com.lucesumbrarum.syncthingStatus" AND category == "StuckDeletes"' --style compact

Or, after reproducing the cleanup flow, dump the last 5 minutes:

  /usr/bin/log show --predicate 'subsystem == "com.lucesumbrarum.syncthingStatus" AND category == "StuckDeletes"' --last 5m --style compact

TIP
