#!/bin/bash
# notarize.sh — build, sign, notarize, and staple syncthingStatus.app for direct distribution.
#
# Adapted from Magpie scripts/notarize.sh (2026-07-12). Archive → Developer-ID export flow:
#   1. Clean `xcodebuild archive`, then `-exportArchive` (method=developer-id). The EXPORT pass
#      re-signs every NESTED Mach-O with Developer ID + hardened runtime + secure timestamp —
#      Sparkle's Autoupdate/Updater.app/Installer.xpc/Downloader.xpc ship ADHOC-signed inside the
#      SPM artifact and a plain `xcodebuild build` leaves them adhoc, which Apple's notary rejects.
#      (Never `codesign --deep` to fix it — that mis-signs the XPC services. Export re-signs right.)
#   2. Verify EVERY nested Mach-O is Developer ID + hardened runtime BEFORE a notary round-trip.
#   3. Zip the .app and submit to Apple's notary service (notarytool submit --wait).
#   4. Staple the ticket onto the .app and confirm Gatekeeper accepts it.
#
# Credentials: the account-wide `conjoyn-notary` keychain profile (App Store Connect API key —
# creds are per-account, not per-app, so every app reuses it).
set -euo pipefail

# --- config ----------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root
PROJECT="${ROOT_DIR}/01_Project/syncthingStatus.xcodeproj"
SCHEME="syncthingStatus"
TEAM_ID="FDMSRXXN73"
IDENTITY="Developer ID Application"
NOTARY_PROFILE="${NOTARY_PROFILE:-conjoyn-notary}"

DERIVED="${ROOT_DIR}/01_Project/build/notarize"
ARCHIVE="${DERIVED}/syncthingStatus.xcarchive"
EXPORT_DIR="${DERIVED}/export"
EXPORT_OPTS="${DERIVED}/exportOptions.plist"
APP="${EXPORT_DIR}/syncthingStatus.app"       # the exported, Developer-ID-resigned app
OUT_DIR="${ROOT_DIR}/04_Exports"
ZIP="${OUT_DIR}/syncthingStatus.zip"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# --- 0. preflight: credentials exist? --------------------------------------
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: no notarytool keychain profile '$NOTARY_PROFILE'." >&2
    exit 1
fi

# --- 1a. clean archive -----------------------------------------------------
bold "==> Archiving Release (Developer ID, hardened runtime)…"
rm -rf "$DERIVED"
mkdir -p "$DERIVED"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    clean archive

[ -d "$ARCHIVE" ] || { echo "error: archive did not produce $ARCHIVE" >&2; exit 1; }

# --- 1b. export Developer ID (re-signs ALL nested code) --------------------
bold "==> Exporting Developer-ID app (re-signs nested Sparkle/XPC)…"
cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    -exportPath "$EXPORT_DIR"

[ -d "$APP" ] || { echo "error: export did not produce $APP" >&2; exit 1; }

# --- 2. verify EVERY nested Mach-O before we waste a notary round-trip ------
# Each must be Developer ID + hardened runtime (flags=0x10000(runtime)). An adhoc nested binary
# (flags=…0x10002(adhoc,runtime)) passes `--deep --strict` locally but is REJECTED by notarization.
bold "==> Verifying signatures (app + Sparkle nested Mach-Os)…"
codesign --verify --deep --strict --verbose=2 "$APP"

SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
assert_devid_runtime() {
    local label="$1" path="$2"
    [ -e "$path" ] || { echo "error: $label missing at $path" >&2; exit 1; }
    local info; info="$(codesign -dvv "$path" 2>&1)"
    case "$info" in
        *"flags=0x10000(runtime)"*) ;;
        *) echo "error: $label is not hardened-runtime (adhoc nested binary?) — notary would reject" >&2
           printf '%s\n' "$info" | grep -i 'flags=' >&2 || true; exit 1 ;;
    esac
    case "$info" in
        *"Authority=Developer ID Application"*) ;;
        *) echo "error: $label is not Developer-ID signed — notary would reject" >&2; exit 1 ;;
    esac
    echo "  ✓ ${label}"
}
assert_devid_runtime "app wrapper"       "$APP"
assert_devid_runtime "Sparkle.framework" "$SPK/Sparkle"
assert_devid_runtime "Autoupdate"        "$SPK/Autoupdate"
assert_devid_runtime "Updater.app"       "$SPK/Updater.app/Contents/MacOS/Updater"
assert_devid_runtime "Installer.xpc"     "$SPK/XPCServices/Installer.xpc/Contents/MacOS/Installer"
assert_devid_runtime "Downloader.xpc"    "$SPK/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
echo "Signature OK (every nested Mach-O is Developer ID + hardened runtime)."

# The sandbox entitlements come from build settings (empty .entitlements file) — assert the
# export kept them, since the app is useless without network.client.
ent="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
for key in com.apple.security.app-sandbox com.apple.security.network.client; do
    printf '%s' "$ent" | grep -q "$key" \
        || { echo "error: exported app lost entitlement $key" >&2; exit 1; }
done
echo "  ✓ sandbox + network.client entitlements intact"

# Sandboxed Sparkle apps must opt into the installer launcher service and allow
# Sparkle to communicate with its installer/status helpers via temporary Mach lookup.
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
installer_launcher="$(/usr/libexec/PlistBuddy -c 'Print :SUEnableInstallerLauncherService' "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [ "$installer_launcher" != "true" ]; then
    echo "error: SUEnableInstallerLauncherService is not true; sandboxed Sparkle installs will fail" >&2
    exit 1
fi
for service in "${bundle_id}-spks" "${bundle_id}-spki"; do
    printf '%s' "$ent" | grep -Fq "$service" \
        || { echo "error: exported app lost Sparkle Mach lookup entitlement $service" >&2; exit 1; }
done
echo "  ✓ Sparkle sandbox installer configuration intact"

# --- 3. submit to the notary service ---------------------------------------
mkdir -p "$OUT_DIR"
rm -f "$ZIP"
bold "==> Zipping for submission…"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

bold "==> Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

# --- 4. staple + final Gatekeeper check ------------------------------------
bold "==> Stapling ticket…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

bold "==> Gatekeeper assessment…"
spctl -a -vvv -t exec "$APP"

bold "==> Done. Notarized + stapled app: $APP"
