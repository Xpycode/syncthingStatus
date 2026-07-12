# Project State

> **Size limit: <100 lines.** This is a digest, not an archive.

## Identity
- **Project:** syncthingStatus
- **One-liner:** macOS menu bar app that surfaces Syncthing's sync state without opening the web UI
- **Tags:** macOS, Menu Bar, SwiftUI, Sparkle, Syncthing
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`

## Current Position
- **Phase:** v1.6.0 release **UNPAUSED (2026-07-12)** — the sandbox/tilde blocker is fixed and verified end-to-end (grant → bookmark → scoped delete → rescan, via DEMO_OOS on a sandboxed build). Remaining: inline-Rescan eyeball, `/check ship`, notarized release cut.
- **Focus:** 2026-07-12: appcast incident hotfixed (drafted 1.6.0 item had gone live and 404'd for every 1.5.5 user — parked in `docs/appcast-v1.6.0-draft.xml`); real-home `~` expansion (`getpwuid`) applied at probe/grantAccess/panel/reveals; probe rewritten on `stat(2)`+errno (ENOENT=absent, EPERM=needs grant); panel-pick compare robust via `fileResourceIdentifier`; cleanup window now probes access at open (gate-first).
- **Status:** v1.6.0 build 162, Debug ad-hoc build green and live-verified on M1 Max. Bookmark persistence across relaunch confirmed. Release build not yet cut.
- **Last updated:** 2026-07-12 (blocker fixed — release prep resumes)

## Progress
```
[###################.] 95% — minimums covered, release prep + cross-peer verification remaining
```

| Stage | Status | Notes |
|-------|--------|-------|
| Phase 0 — popover gap fix (`needDeletes` decode) | **done** | Out-of-sync now matches WebUI |
| Phase 1 — detection signal + 30-s debounce | **done** | `stuckDeleteCounts` published from `fetchFolderStatus` |
| Phase 1.x — detection latch fix | **done** | Two-stage state machine; rescan churn no longer flaps the alert |
| Phase 2 — popover orange alert row | **done** | Sibling inside `statusContent`, preserves popover sizing |
| Phase 3 — cleanup window | **done** | Per-folder dedup, `db/need` listing, "Reveal" per row |
| Phase 4 — destructive action | **done** | Selection + confirm + access gate + path validation + rescan + outcome |
| Phase 4.x — security-scoped bookmark refactor | **done** | `FolderAccessBookmarks.swift` + `NSOpenPanel`; replaces FDA gate; sandbox-preserving |
| Phase 5 — full polish + docs | **mostly done** | Settings toggle, diagnostic export, About panel, popover versions, ⌘A select-all all shipped. README + release notes still pending. |
| Phase 5.x — App Minimums audit | **done** | DiagnosticLogger.swift + Settings UI for export; About panel now shows Syncthing version; popover Local Device shows app + Syncthing versions stacked. |
| Phase 6 — manual verification | **mostly done** | M1 Max end-to-end verified. Cross-peer round-trip verified 2026-06-03 via a real ProPro stuck-delete with M4-Pro online (recovered + reconciled; both nodes agree, 3315==3315 dirs). Cleanup-window ⌘A select-all still not live-tested (this repro was resolved via git, not the app's Resolve flow). |
| Inline Rescan button (out-of-sync row) | **done + eyeballed** | `FolderStatusRow.folderStatusLabel` — orange `arrow.clockwise` + tooltip, calls `rescanFolder`; shown only in the "Out of sync" state. Context-menu Rescan kept as fallback. Live-eyeballed 2026-07-12 evening via DEMO_OOS rig (button renders, tooltip correct, click POSTs `db/scan` — OSLog-confirmed). |

## Tech Stack
- Swift / SwiftUI on macOS (deployment target macOS 15.5)
- Combine for client state propagation
- Sparkle 2.8.1 for in-app updates (EdDSA signed appcast)
- App Sandbox (`com.apple.security.app-sandbox`) + security-scoped bookmarks (`UserDefaults` keyed `FolderAccessBookmark.<folderID>`) for filesystem access outside the container
- Syncthing REST API (v2.x) — `db/status`, `db/completion`, `db/need`, `db/scan`, `system/connections`, `system/config`
- UserNotifications framework, OSLog (`com.lucesumbrarum.syncthingStatus`, categories: `FolderStatus`, `StuckDeletes`, `FolderAccess`)

## Active Decisions (2026-04-29)
- **App Sandbox stays on** — App Store distribution is preserved at the cost of bookmark plumbing (security-scoped via `NSOpenPanel`); FDA-based gate retired.
- **Detection latch** — entry requires `state == idle` + 30-s debounce; persistence is state-agnostic (`needDeletes > 0 && no real sync work`); only `needDeletes`-resolution or real sync work unlatches.
- **`db/need`** (receiver vantage) over `db/remoteneed` (sender vantage) for candidate listing — see `decisions.md`.
- Phase 0 popover-gap fix shippable in isolation (decoded `needDeletes` + `needTotalItems` on `SyncthingFolderStatus`).
- Dedicated `NSWindow` over popover-attached sheet for cleanup UI; per-folder dedup with focus-existing semantics.
- Selection state lives in the SwiftUI View with `.onChange` intersection — not in the controller.
- `nonisolated static validatePath` rejects `..`, `/`, `\0`, escaping paths via symlink-resolved strict-prefix check.
- `CocoaError` typed catches over NSError integer codes; ENOENT counts as success (idempotent on race).
- Path-validation for grant URL lives on `grantAccess(_:)` in the controller (not in the AppKit closure) — `lastError` is `private(set)`.
- Closure-bridged AppKit (dismiss + request-access) keeps `Client.swift` framework-agnostic.
- Loosened `makeRequest<T: Codable>` to `<T: Decodable>` — response types only need `Decodable`.
- **Diagnostic logging via `OSLogStore` export**, not file-tee — sandbox-clean, App-Store safe, no churn at 25 existing log sites. Bookend `notice` lines at app launch and export-time guarantee a non-empty file on clean sessions.
- **About panel uses `orderFrontStandardAboutPanel(options:)` with `.credits`** for the Syncthing version — reuses Apple's standard panel rather than building a custom window.

## Blockers
- none

## Resolved
- **✅ Sandbox/tilde access blocker (2026-07-12):** real-home `~` expansion via `getpwuid`
  (`SyncthingFolder.realPath`/`.realURL`) at probe, grantAccess, grant panel, Finder reveals, and
  config discovery; probe on `stat(2)`+errno (ENOENT → `.notFound`, EPERM → `.needsBookmark` — the
  sandbox *allows* metadata reads, `fileExists` just conflates the errors); `fileResourceIdentifier`
  equality in grantAccess. Verified end-to-end via DEMO_OOS (grant accepted, bookmark at real path,
  2 ok/0 failed, rescan, persistence across relaunch). Also: cleanup window probes at open now
  (gate-first — the grant panel no longer interrupts mid-delete). See decisions.md 2026-07-12.
- **✅ Live-appcast incident (2026-07-12):** the drafted 1.6.0 `<item>` had shipped to production in
  `c92b947` (appcast.xml on `main` IS the Sparkle feed) — 1.5.5 users got a 404ing update prompt.
  Parked in `docs/appcast-v1.6.0-draft.xml`; feed verified back at 1.5.5-latest (`88305d9`).
- **✅ OSLog release gate (2026-07-03):** the 30+ bare `print()` calls flagged in the 2026-05-01 review had already been converted in the v1.6.0 catch-up work; the last remaining one (DEBUG-only API-key-length print in `makeRequest`) is now removed. Diagnostic export captures all production logging.
- **✅ Local git repo re-established (2026-07-03):** `.git` was gone on both Macs and origin was stale at `a28caa8` (2026-04-28, v1.5.5 era). Bootstrapped via `git-bootstrap` skill (init → fetch → `reset --mixed origin/main` → verify → catch-up commit → push); non-destructive to files. All v1.6.0 work + docs now committed as `6318080` and pushed; local `main` == `origin/main`, tree clean. Root cause was the ProPro Syncthing folder syncing/losing `.git` in branch-flip churn — now mitigated by `.git`/`.stversions` being ignored on both Macs (see memory `project-syncthing-propro-setup`).

## Done for v1.6.0 (ship line — everything not here is v1.7 by default)
- [x] Stuck-deletes: detect → alert → cleanup window → scoped delete → rescan, no crash (verified 2026-07-12)
- [x] Sandbox `~` folders grantable; bookmarks survive relaunch (verified 2026-07-12)
- [x] Inline Rescan ↻ fires `db/scan` (verified 2026-07-12 evening)
- [x] Popover/out-of-sync counts match WebUI; no false-red icon
- [ ] Notarized, stapled, Sparkle-signed DMG; appcast item live only after the DMG exists

## Next Actions
1. ~~Eyeball the inline Rescan ↻ button~~ ✅ **done 2026-07-12 evening** via DEMO_OOS injection (needFiles-based, stuck-latch untouched). Two observations, both non-blocking: repeat clicks while the daemon is mid-scan time out (`db/scan` blocks until scan completes; failure only logs, no UI noise); tooltip appears at the system-default delay (felt slow — `NSInitialToolTipDelay` default could shorten it app-wide if wanted).
2. **Run `/check ship`** before the release cut.
3. **Release notes + README:** ✅ drafted (2026-07-03) — README `## What's New in Version 1.6.0` + badges/manual-download link/Features/API lists updated. **⚠️ Incident (2026-07-12):** the drafted 1.6.0 appcast `<item>` had gone live when pushed (appcast.xml on `main` IS the Sparkle feed) — every 1.5.5 install offered a broken update (DMG 404). Hotfixed: item parked in `docs/appcast-v1.6.0-draft.xml`. **At release cut:** fill its `REPLACE_ME_*` placeholders (`edSignature`, `length`, `pubDate`), move it back to the top of `appcast.xml`, push only after the GitHub release + DMG exist.
4. **Release prep (once blocker fixed):** reuse the **`conjoyn-notary`** keychain profile (creds are account-wide, not per-app — no new password); adapt Conjoyn/Magpie `make-dmg.sh`+`notarize.sh` (syncthingStatus has no release scripts); Release build → notarytool → staple → DMG → Sparkle EdDSA sign → fill appcast → git tag + `gh release create` + upload DMG.
5. **Website (once released):** already catalogued at `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com` — bump `apps-data.md` (line 102: version/size/features) + `public/apps/syncthingstatus.html`, copy the new DMG to the site's `downloads/` (dl.php self-hosts it), then `deploy.sh` (lftp → Strato).
6. **User-side cleanup (optional):** revoke the FDA grant for `syncthingStatus.app` in System Settings — superseded by bookmarks. Leave `syncthing` (the daemon) alone.

## References
- Implementation plan: `docs/IMPLEMENTATION-PLAN-stuck-deletes.md`
- Feature design doc: `docs/FEATURE-stuck-deletes-cleanup.md`
- Latest session log: `docs/sessions/2026-07-12.md` (appcast incident + sandbox/tilde fix + verification)
- Decisions: `docs/decisions.md` (latch + bookmark entries dated 2026-04-29)
- Syncthing infra (cross-project): memory `project-syncthing-propro-setup` — ProPro folder ignores `.git`/`.stversions`; code syncs via GitHub
- Debug install script: `tools/install-debug-build.sh`
- Build: v1.6.0 build 162 (Debug, with inline Rescan button)

---
*Updated by Claude. Source of truth for project position.*
