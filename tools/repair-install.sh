#!/bin/bash
#
# repair-install.sh — clean reinstall of syncthingStatus.app from a GitHub Release.
#
# Use this when the menu-bar update fails with "An error occurred while launching
# the installer", which usually means the running bundle is at a malformed path
# (e.g. /Applications/syncthingStatus.app.1 or /Applications/syncthingStatus V1.5.1
# without the .app extension). macOS won't register Sparkle's XPC services unless
# the parent bundle ends in `.app`, so auto-update can't replace it in place.
#
# Safe to re-run; idempotent: if the canonical install is already correct it just
# re-installs from the DMG without affecting anything else.
#
# Usage:
#   ./repair-install.sh              # installs the version pinned below
#   ./repair-install.sh 1.5.6        # installs an explicit version
#
# Requires:  curl, hdiutil, codesign (all macOS built-ins).
# Does NOT: ask for sudo, force-overwrite anything that doesn't belong to this app,
#           or touch ~/Library data (your settings + API keys are preserved).
#

set -euo pipefail

# --- config -----------------------------------------------------------------
DEFAULT_VERSION="1.5.5"
APP_NAME="syncthingStatus"
BUNDLE_ID="com.lucesumbrarum.syncthingStatus"
GITHUB_REPO="Xpycode/syncthingStatus"
CANONICAL_PATH="/Applications/${APP_NAME}.app"

VERSION="${1:-$DEFAULT_VERSION}"
DMG_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${APP_NAME}-v${VERSION}.dmg"
TS=$(date +%Y%m%d-%H%M%S)
TMPDIR_LOCAL=$(mktemp -d)
DMG_LOCAL="${TMPDIR_LOCAL}/${APP_NAME}-v${VERSION}.dmg"

trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

say()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m  %s\n" "$*"; }
fail() { printf "\033[1;31mxx\033[0m  %s\n" "$*" >&2; exit 1; }

# --- 1. quit any running instance -------------------------------------------
say "Quitting any running ${APP_NAME}…"
killall "${APP_NAME}" 2>/dev/null || true
# Give it a beat to finish writing settings before we start moving bundles.
sleep 1

# --- 2. find any malformed bundles in /Applications -------------------------
# We keep anything named exactly ${APP_NAME}.app (the canonical name) unless it
# refuses to replace cleanly. Anything else with the same bundle id (suffixed
# with version, ".1", missing .app extension, lowercased, etc.) gets moved to
# Trash with a timestamp so we don't trigger a Trash-side collision.
say "Looking for malformed bundles in /Applications…"
moved_any=0
shopt -s nullglob nocaseglob
for entry in /Applications/syncthingStatus*; do
    # Skip the one canonical path; we'll overwrite it cleanly later.
    if [[ "$entry" == "$CANONICAL_PATH" ]]; then
        continue
    fi

    # Only touch things that report our bundle id — never random user files.
    plist="${entry}/Contents/Info.plist"
    if [[ ! -f "$plist" ]]; then
        continue
    fi
    id=$(/usr/bin/plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null || echo "")
    if [[ "$id" != "$BUNDLE_ID" ]]; then
        warn "Skipping $entry — bundle id is '$id', not ours."
        continue
    fi

    target="${HOME}/.Trash/$(basename "$entry") (${TS})"
    say "Trashing $entry  →  $target"
    mv "$entry" "$target"
    moved_any=1
done
shopt -u nullglob nocaseglob

if [[ $moved_any -eq 0 ]]; then
    say "No malformed bundles found."
fi

# --- 3. download DMG --------------------------------------------------------
say "Downloading ${APP_NAME} v${VERSION}…"
if ! curl --fail --location --silent --show-error -o "$DMG_LOCAL" "$DMG_URL"; then
    fail "Download failed: $DMG_URL"
fi
size=$(stat -f '%z' "$DMG_LOCAL")
say "Got DMG (${size} bytes)."

# --- 4. mount, copy, eject --------------------------------------------------
say "Mounting DMG…"
mount_output=$(hdiutil attach "$DMG_LOCAL" -nobrowse -plist 2>&1)
mount_point=$(echo "$mount_output" | /usr/bin/plutil -extract 'system-entities' xml1 -o - - 2>/dev/null \
              | /usr/bin/grep -A1 mount-point | tail -1 | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/' || true)

# Fallback if plist parsing didn't pan out (varies by macOS version)
if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
    mount_point=$(ls -d "/Volumes/${APP_NAME} ${VERSION}"* 2>/dev/null | head -1)
fi
[[ -z "$mount_point" || ! -d "$mount_point" ]] && fail "Couldn't determine DMG mount point."

src_app="${mount_point}/${APP_NAME}.app"
[[ ! -d "$src_app" ]] && fail "DMG is missing ${APP_NAME}.app at $src_app"

# Verify Apple thinks the DMG's app is signed + notarized before we install it.
say "Verifying notarization on the DMG copy…"
if ! /usr/sbin/spctl -a -t install "$src_app" >/dev/null 2>&1; then
    /usr/bin/hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    fail "Gatekeeper rejected $src_app — refusing to install."
fi

# If a canonical install exists, push it aside (kept in Trash, recoverable).
if [[ -d "$CANONICAL_PATH" ]]; then
    say "Stashing existing $CANONICAL_PATH to Trash."
    mv "$CANONICAL_PATH" "${HOME}/.Trash/$(basename "$CANONICAL_PATH") (${TS})"
fi

say "Installing to $CANONICAL_PATH…"
/bin/cp -R "$src_app" "$CANONICAL_PATH"

say "Ejecting DMG…"
# Retry once because Spotlight/Finder may briefly hold the volume.
if ! /usr/bin/hdiutil detach "$mount_point" >/dev/null 2>&1; then
    sleep 2
    /usr/bin/hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
fi

# --- 5. final sanity check + launch ----------------------------------------
installed_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "${CANONICAL_PATH}/Contents/Info.plist")
installed_build=$(/usr/bin/plutil -extract CFBundleVersion raw "${CANONICAL_PATH}/Contents/Info.plist")
say "Installed ${APP_NAME} ${installed_version} (build ${installed_build}) at ${CANONICAL_PATH}"

say "Launching…"
/usr/bin/open "$CANONICAL_PATH"

say "Done. Auto-update will work for future releases."
