# Project State

## Identity
- **Project:** syncthingStatus — macOS menu bar app showing Syncthing's sync state.
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`
- **Stack:** Swift / SwiftUI, Combine, Syncthing REST API v2, Sparkle 2.8.1.
- **Minimum macOS:** 15.5; release supports Intel and Apple Silicon.

## Now
- **Phase:** post-release; v1.6.1 (build 163) released 2026-08-10.
- **Focus:** v1.7 maintenance, starting with refresh overruns when devices are offline.
- **Blockers:** full Homebrew audit requires Xcode 27.0 on this Mac (26.6 installed); cask style and download/checksum checks passed.
- **Next:** reproduce the refresh overrun with an offline peer and identify the slow request.
- **Updated:** 2026-09-05.

## Recent
- **2026-09-05:** published the Homebrew tap, added README install/upgrade links, slimmed this digest, and recorded the release checklist plus a website handoff.
- **2026-08-10:** released v1.6.1 with working automatic update installation; website updated too.
- **2026-08-09:** fixed connections to local Syncthing instances using self-signed HTTPS certificates.
- **2026-07-12:** released v1.6.0 with stuck-delete cleanup, folder access grants, Rescan, and working Launch at Login.
- **2026-06-03:** verified cross-peer stuck-delete recovery and added the inline Rescan control.

## Backlog
- **v1.7 priority:** investigate refresh overruns with offline devices. Requests can outlast the 10-second refresh interval and be cancelled by the next cycle; suspect disconnected-device `db/completion` reaching the 30-second resource timeout. About-version flickering is already fixed.
- **v1.7 polish:** Feedback / Donate / Help, window frame autosave, CHANGELOG, split the large Views and Client files, refresh About credits on reconnect.
- **Remote HTTPS:** consider opt-in certificate pinning if more NAS / remote-host reports arrive; self-signed certificate auto-trust is restricted to loopback.
- **User follow-up:** reply to the HTTPS reporter with v1.6.1 and the one-time manual-download instruction.
- **Signing-key housekeeping:** label the Group B Sparkle entry in Strongbox; optional named Keychain import. Custody details remain in the historical snapshot.
- **Cookbook candidates:** real-home tilde expansion with `stat(2)` / errno probing; `SMAppService.mainApp` for Launch at Login.
- **Optional user cleanup:** revoke the obsolete Full Disk Access grant for this app; retain the daemon's grant.
- **Website handoff:** add the Homebrew option to the app page; instructions left in `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com/docs/HANDOFF-syncthingstatus-homebrew.md` and linked from that project's task list. Website edit/deploy pending.

## Infrastructure
- **Release:** GitHub `Xpycode/syncthingStatus`; v1.6.1 DMG notarized and stapled. Appcast and website were verified live at release.
- **Homebrew:** `Casks/syncthingstatus.rb` is live in this repository's custom tap; fresh public tap and fetch verified 2026-09-05. Install commands and validation limits: [Homebrew distribution](homebrew.md).
- **Upgrade caveat:** versions ≤1.6.0 cannot install their own updates; users need one manual DMG installation. Sparkle installation was verified end-to-end from v1.6.1.
- **Live feed:** root `appcast.xml` on `main` is production. Publish the DMG before exposing an appcast item; keep drafts outside the live feed.
- **Filesystem access:** App Sandbox stays enabled; security-scoped bookmarks keyed `FolderAccessBookmark.<folderID>` replace Full Disk Access.
- **Diagnostics:** OSLog subsystem `com.lucesumbrarum.syncthingStatus`, exported through `OSLogStore`.
- **Cross-Mac:** Syncthing's ProPro folder ignores `.git` and `.stversions`; GitHub carries Git history. On 2026-09-05 all apparent local edits matched upstream exactly; local history was aligned without changing working files.
- **Release tools:** `tools/notarize.sh`, `tools/make-dmg.sh`; debug install: `tools/install-debug-build.sh`.

## Detail (read only if needed)
- [Decisions](decisions.md) — durable choices, including summaries preserved during migration.
- [Sessions](sessions/_index.md) — complete work and validation history.
- [Tasks](TASKS.md) — deferred Homebrew validation; no active sprint.
- [Stuck-delete implementation plan](IMPLEMENTATION-PLAN-stuck-deletes.md) and [feature design](FEATURE-stuck-deletes-cleanup.md).
- [Pre-migration state](archive/project-state-2026-08-10.md) — historical phase tables, verification details, resolved incidents, and signing-key housekeeping references; contains superseded status.
- [Homebrew distribution](homebrew.md) — cask validation, publication, and release maintenance.

## Resume
- Investigate the v1.7 refresh overrun with an offline peer; rerun the full Homebrew audit when Xcode 27.0 is available.
- For every public app release, follow [Release maintenance](homebrew.md#release-maintenance): GitHub DMG first, then Sparkle + cask metadata, website deployment, and live checks. Ordinary edits do not require a release.
