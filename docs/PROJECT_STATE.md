# Project State

## Identity
- **Project:** syncthingStatus — macOS menu bar app showing Syncthing's sync state.
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`
- **Stack:** Swift / SwiftUI, Combine, Syncthing REST API v2, Sparkle 2.8.1.
- **Minimum macOS:** 15.5; release supports Intel and Apple Silicon.

## Now
- **Phase:** post-release; v1.6.2 (build 165) released 2026-09-17.
- **Focus:** v1.6.2 (165) is live on all channels; user testing the updater from installed 1.6.1. v1.7 work remains on `fix/isolated-production-tests`.
- **Blockers:** The inherited cleanup blocker is mitigated in 1.6.2 by disabling cleanup; permanent repair remains in v1.7.
- **Next:** user verifies the updater from installed 1.6.1; resume separate v1.7 acceptance on `fix/isolated-production-tests` afterward.
- **Updated:** 2026-09-17.

## Recent
- **2026-09-17:** full Homebrew audit passed with Xcode 27.2; published v1.6.2 (165) with the accepted long-name layout fix and cleanup disabled; all channels verified, README/changelog updated. Installed 1.6.1 retained for user updater testing.
- **2026-09-05:** completed the app/code/usability review; reproduced a cleanup data-loss risk, false healthy status, and dropped refreshes; preserved evidence and queued fixes for next session.
- **2026-09-05:** published the Homebrew tap, added README install/upgrade links, slimmed this digest, and recorded the release checklist plus a website handoff.
- **2026-08-10:** released v1.6.1 with working automatic update installation; website updated too.
- **2026-08-09:** fixed connections to local Syncthing instances using self-signed HTTPS certificates.

## Backlog
- **Review queue:** one active cleanup blocker, 11 confirmed backlog items (nine review follow-ups and two Homebrew checks), and two observations awaiting reproduction are tracked in [Tasks](TASKS.md). See the [review](reviews/2026-09-05-usability-code-review.md) for evidence and priority.
- **v1.7 priority:** investigate refresh overruns with offline devices. Requests can outlast the 10-second refresh interval and be cancelled by the next cycle; suspect disconnected-device `db/completion` reaching the 30-second resource timeout. About-version flickering is already fixed.
- **v1.7 polish:** Feedback / Donate / Help, window frame autosave, split the large Views and Client files, refresh About credits on reconnect.
- **Remote HTTPS:** consider opt-in certificate pinning if more NAS / remote-host reports arrive; self-signed certificate auto-trust is restricted to loopback.
- **User follow-up:** reply to the HTTPS reporter with v1.6.1 and the one-time manual-download instruction.
- **Signing-key housekeeping:** label the Group B Sparkle entry in Strongbox; optional named Keychain import. Custody details remain in the historical snapshot.
- **Cookbook candidates:** real-home tilde expansion with `stat(2)` / errno probing; `SMAppService.mainApp` for Launch at Login.
- **Optional user cleanup:** revoke the obsolete Full Disk Access grant for this app; retain the daemon's grant.
- **Website:** Homebrew instructions are live; v1.6.2 page/catalogue/sitemap/download deployed and verified 2026-09-17; counters and feedback preserved.

## Infrastructure
- **Release:** GitHub `Xpycode/syncthingStatus`; v1.6.2 (165) Universal DMG notarized/stapled. GitHub, updater, Homebrew fetch and homepage download hashes verified live 2026-09-17. Cleanup is temporarily disabled.
- **Homebrew:** `Casks/syncthingstatus.rb` is live in this repository's custom tap; v1.6.2 public fetch and full strict online audit passed 2026-09-17 with Xcode 27.2. Install commands and validation limits: [Homebrew distribution](homebrew.md).
- **Upgrade caveat:** versions ≤1.6.0 cannot install their own updates; users need one manual DMG installation. Sparkle installation was verified end-to-end from v1.6.1.
- **Live feed:** root `appcast.xml` on `main` is production. Publish the DMG before exposing an appcast item; keep drafts outside the live feed.
- **Filesystem access:** App Sandbox stays enabled; security-scoped bookmarks keyed `FolderAccessBookmark.<folderID>` replace Full Disk Access.
- **Diagnostics:** OSLog subsystem `com.lucesumbrarum.syncthingStatus`, exported through `OSLogStore`.
- **Cross-Mac:** Syncthing's ProPro folder ignores `.git` and `.stversions`; GitHub carries Git history. On 2026-09-05 all apparent local edits matched upstream exactly; local history was aligned without changing working files.
- **Release tools:** `tools/notarize.sh`, `tools/make-dmg.sh`; debug install: `tools/install-debug-build.sh`.

## Detail (read only if needed)
- [Decisions](decisions.md) — durable choices, including summaries preserved during migration.
- [Sessions](sessions/_index.md) — complete work and validation history.
- [Tasks](TASKS.md) — active cleanup blocker, review follow-ups, Homebrew checks, and reproduction inbox.
- [Active review-fix plan](IMPLEMENTATION_PLAN.md) — exact next-session pickup and cleanup acceptance checks.
- [App and code review](reviews/2026-09-05-usability-code-review.md) — ranked findings and preserved reproduction evidence.
- [Stuck-delete implementation plan](IMPLEMENTATION-PLAN-stuck-deletes.md) and [feature design](FEATURE-stuck-deletes-cleanup.md).
- [Pre-migration state](archive/project-state-2026-08-10.md) — historical phase tables, verification details, resolved incidents, and signing-key housekeeping references; contains superseded status.
- [Homebrew distribution](homebrew.md) — cask validation, publication, and release maintenance.

## Resume
- v1.6.2 is published with cleanup disabled. Permanent cleanup repair and later acceptance work are on `fix/isolated-production-tests`; use that branch’s current plan/state when resuming v1.7.
- Deferred: 11 confirmed backlog items and two unconfirmed observations, plus one active release blocker. No half-done application edit.
- Model fit: deep capability + high reasoning for destructive-path identity and refresh concurrency; use smaller agents for bounded independent validation.
- For every public app release, follow [Release maintenance](homebrew.md#release-maintenance): GitHub DMG first, then Sparkle + cask metadata, website deployment, and live checks. Ordinary edits do not require a release.
