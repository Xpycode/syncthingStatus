#!/bin/bash
# make-dmg.sh — wrap the notarized syncthingStatus.app in a notarized DMG for distribution.
#
# Adapted from Magpie scripts/make-dmg-plain.sh (2026-07-12): Finder-free, hdiutil-based.
# create-dmg's styled Finder window fails on macOS 26+ with "-1743 Not authorised to send Apple
# events to Finder" even with Automation→Finder granted (confirmed while cutting Magpie 1.1.1),
# so this builds a PLAIN window — the app beside an /Applications drop-link, no background art.
# Everything else (Developer-ID sign + Apple notarize + staple + Gatekeeper check) matches the
# styled flow exactly; the result installs offline with no Gatekeeper prompt.
#
# Usage:
#   tools/make-dmg.sh            # builds + notarizes the app (via notarize.sh), then the DMG
#   SKIP_APP=1 tools/make-dmg.sh # reuse an already-notarized + stapled app (no re-notarize)
#
# Output: 04_Exports/syncthingStatus-v<version>.dmg — filename matches the appcast enclosure URL
# (https://github.com/Xpycode/syncthingStatus/releases/download/v<version>/…).
# After this, sign_update the DMG and fill the appcast's length + edSignature.
set -euo pipefail

# --- config ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IDENTITY="Developer ID Application"
NOTARY_PROFILE="${NOTARY_PROFILE:-conjoyn-notary}"

DERIVED="${ROOT_DIR}/01_Project/build/notarize"
APP="${DERIVED}/export/syncthingStatus.app"
OUT_DIR="${ROOT_DIR}/04_Exports"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# --- 0. preflight ----------------------------------------------------------
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: no notarytool keychain profile '$NOTARY_PROFILE'." >&2
    exit 1
fi

# --- 1. obtain a notarized + stapled app (reuse, or delegate to notarize.sh)
if [ "${SKIP_APP:-0}" = "1" ] && [ -d "$APP" ] && xcrun stapler validate "$APP" >/dev/null 2>&1; then
    bold "==> SKIP_APP=1 — reusing already-stapled app at $APP"
else
    bold "==> Building + notarizing the app (delegating to notarize.sh)…"
    NOTARY_PROFILE="$NOTARY_PROFILE" "${SCRIPT_DIR}/notarize.sh"
fi
[ -d "$APP" ] || { echo "error: expected app not found at $APP" >&2; exit 1; }
xcrun stapler validate "$APP" >/dev/null 2>&1 || {
    echo "error: $APP is not stapled — notarize.sh did not complete" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ -n "$VERSION" ] || { echo "error: could not read app version" >&2; exit 1; }
DMG="${OUT_DIR}/syncthingStatus-v${VERSION}.dmg"
VOLNAME="syncthingStatus ${VERSION}"
bold "==> Packaging syncthingStatus ${VERSION} (Finder-free)"

# --- 2. stage app + Applications drop-link (+ volume icon file) -------------
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto "$APP" "$STAGING/syncthingStatus.app"
ln -s /Applications "$STAGING/Applications"
ICNS="$APP/Contents/Resources/AppIcon.icns"
[ -f "$ICNS" ] && cp "$ICNS" "$STAGING/.VolumeIcon.icns"

# --- 3. build compressed image directly — no mount, no Finder --------------
mkdir -p "$OUT_DIR"
rm -f "$DMG"
bold "==> hdiutil create (UDZO)…"
hdiutil create -srcfolder "$STAGING" -volname "$VOLNAME" -fs HFS+ -format UDZO -ov "$DMG"
[ -f "$DMG" ] || { echo "error: DMG was not produced at $DMG" >&2; exit 1; }

# --- 4. sign the DMG -------------------------------------------------------
bold "==> Signing the DMG…"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
codesign --verify --verbose=2 "$DMG"

# --- 5. notarize + staple --------------------------------------------------
bold "==> Submitting the DMG to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
bold "==> Stapling ticket onto the DMG…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# --- 6. final Gatekeeper assessment ----------------------------------------
bold "==> Gatekeeper assessment (install-time)…"
spctl -a -vvv -t open --context context:primary-signature "$DMG"

SIZE_BYTES="$(stat -f%z "$DMG")"
bold "==> Done. Notarized + stapled DMG: $DMG"
echo "Size: ${SIZE_BYTES} bytes  ← appcast enclosure length"
echo "NEXT: sign_update '$DMG' → paste sparkle:edSignature into the appcast item."
