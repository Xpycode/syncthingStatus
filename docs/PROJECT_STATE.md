# Project State

> **Size limit: <100 lines.** This is a digest, not an archive.

## Identity
- **Project:** syncthingStatus
- **One-liner:** macOS menu bar app that surfaces Syncthing's sync state without opening the web UI
- **Tags:** macOS, Menu Bar, SwiftUI, Sparkle, Syncthing
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`

## Current Position
- **Phase:** v1.6.0 release **PAUSED (2026-07-03)** — DEMO_OOS eyeball caught a release-blocking bug: the stuck-deletes access flow can't complete for `~/`-configured folders under sandbox (see Blockers). Notes/website/notarization all ready; blocked on the fix.
- **Focus:** Code-quality pass done (2026-07-03): OSLog release blocker closed (last `print()` removed), cancellation-handling bugs fixed (typed check replaces locale-fragile string matching; `fetchStatus` no longer flashes false-Disconnected on cancelled refresh), dead `automaticallyCheckForUpdates` setting removed. README + v1.6.0 release notes now drafted (README "What's New" + appcast `<item>`, signature/length/pubDate left as `REPLACE_ME_*` for the release cut). Remaining for release: live eyeball on M1 Max, then notarized build + fill appcast placeholders.
- **Status:** v1.6.0 build 162. Runs on the M1 Max via ad-hoc signing. DEMO_OOS eyeball confirmed the popover alert row, out-of-sync state, cleanup window + ⌘A/Select-All, and that the destructive action fails closed — but **exposed the `~/`-folder sandbox access blocker** (see Blockers). **Release paused.** Release build not cut.
- **Last updated:** 2026-07-03 (release paused — sandbox/tilde blocker found)

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
| Inline Rescan button (out-of-sync row) | **done** | `FolderStatusRow.folderStatusLabel` — orange `arrow.clockwise` + tooltip, calls `rescanFolder`; shown only in the "Out of sync" state. Context-menu Rescan kept as fallback. |

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
- **🔴 Stuck-deletes access flow broken for `~/` folders under sandbox (2026-07-03).**
  **What:** every Syncthing folder path is literal `~/…`. `probeFolderAccess` (Client.swift:1909)
  calls `fileExists(atPath: "~/…")` — `fileExists` never expands `~` → always `.notFound` → the
  misleading "path may differ between peers" error, blocking the grant prompt. Confirmed via DEMO_OOS.
  **Suspected companion:** app is sandboxed, so `~`→container home; `grantAccess` (1847) compares the
  user's real NSOpenPanel pick against `standardizingPath("~/…")` (container) → would reject a valid
  selection. **Tried:** DEMO_OOS eyeball surfaced it; confirmed folder paths carry literal `~` via the
  config API. **Unblock:** real-home `~` expander (`getpwuid(getuid())→pw_dir`) at probe + grantAccess;
  probe defaults to `.needsBookmark` when it can't stat; re-verify grant→delete end-to-end. Next
  session confirms the grantAccess half first. Root cause it survived: 2026-06-03 "verified" was
  git-resolved, never ran the app's grant→delete path.

## Resolved
- **✅ OSLog release gate (2026-07-03):** the 30+ bare `print()` calls flagged in the 2026-05-01 review had already been converted in the v1.6.0 catch-up work; the last remaining one (DEBUG-only API-key-length print in `makeRequest`) is now removed. Diagnostic export captures all production logging.
- **✅ Local git repo re-established (2026-07-03):** `.git` was gone on both Macs and origin was stale at `a28caa8` (2026-04-28, v1.5.5 era). Bootstrapped via `git-bootstrap` skill (init → fetch → `reset --mixed origin/main` → verify → catch-up commit → push); non-destructive to files. All v1.6.0 work + docs now committed as `6318080` and pushed; local `main` == `origin/main`, tree clean. Root cause was the ProPro Syncthing folder syncing/losing `.git` in branch-flip churn — now mitigated by `.git`/`.stversions` being ignored on both Macs (see memory `project-syncthing-propro-setup`).

## Next Actions
1. **🔴 FIRST: confirm + fix the sandbox/tilde blocker** (see Blockers; full recipe in the 2026-07-03 Session 4 **Resume** block). Confirm the `grantAccess` container-mismatch via a temporary path-logging diagnostic, then apply the real-home `~` expander at probe + grantAccess and re-verify grant→delete end-to-end via DEMO_OOS. **This gates the release.**
2. **Eyeball the inline Rescan ↻ button** — still pending; note it lives in the *detailed* row (main Window `folderStatusLabel`), NOT the popover compact row (which shows "N deletes" but no ↻). Cleanup ⌘A / Select-All **was confirmed working** via DEMO_OOS 2026-07-03. **NB:** run Debug via ad-hoc (`CODE_SIGN_IDENTITY="-"`, memory `dev-signing-cert-gap`) — no dev cert on either Mac.
3. **Release notes + README:** ✅ drafted (2026-07-03) — README `## What's New in Version 1.6.0` + badges/manual-download link/Features/API lists updated; `appcast.xml` 1.6.0 `<item>` added. **Still open (release-cut only):** fill the appcast `REPLACE_ME_*` placeholders (`edSignature`, `length`, `pubDate`) after the signed DMG exists.
4. **Release prep (once blocker fixed):** reuse the **`conjoyn-notary`** keychain profile (creds are account-wide, not per-app — no new password); adapt Conjoyn/Magpie `make-dmg.sh`+`notarize.sh` (syncthingStatus has no release scripts); Release build → notarytool → staple → DMG → Sparkle EdDSA sign → fill appcast → git tag + `gh release create` + upload DMG.
5. **Website (once released):** already catalogued at `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com` — bump `apps-data.md` (line 102: version/size/features) + `public/apps/syncthingstatus.html`, copy the new DMG to the site's `downloads/` (dl.php self-hosts it), then `deploy.sh` (lftp → Strato).
6. **User-side cleanup (optional):** revoke the FDA grant for `syncthingStatus.app` in System Settings — superseded by bookmarks. Leave `syncthing` (the daemon) alone.

## References
- Implementation plan: `docs/IMPLEMENTATION-PLAN-stuck-deletes.md`
- Feature design doc: `docs/FEATURE-stuck-deletes-cleanup.md`
- Latest session log: `docs/sessions/2026-07-03.md` (**Session 4 has the sandbox/tilde blocker + Resume block**; earlier sessions: git reconcile, code-quality, release-notes draft, M1 Max run)
- Decisions: `docs/decisions.md` (latch + bookmark entries dated 2026-04-29)
- Syncthing infra (cross-project): memory `project-syncthing-propro-setup` — ProPro folder ignores `.git`/`.stversions`; code syncs via GitHub
- Debug install script: `tools/install-debug-build.sh`
- Build: v1.6.0 build 162 (Debug, with inline Rescan button)

---
*Updated by Claude. Source of truth for project position.*
