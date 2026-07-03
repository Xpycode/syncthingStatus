# Project State

> **Size limit: <100 lines.** This is a digest, not an archive.

## Identity
- **Project:** syncthingStatus
- **One-liner:** macOS menu bar app that surfaces Syncthing's sync state without opening the web UI
- **Tags:** macOS, Menu Bar, SwiftUI, Sparkle, Syncthing
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`

## Current Position
- **Phase:** v1.6.0 release prep — feature complete; cross-peer stuck-delete now verified end-to-end
- **Focus:** Code-quality pass done (2026-07-03): OSLog release blocker closed (last `print()` removed), cancellation-handling bugs fixed (typed check replaces locale-fragile string matching; `fetchStatus` no longer flashes false-Disconnected on cancelled refresh), dead `automaticallyCheckForUpdates` setting removed. Remaining for release: README + release notes, then notarized build.
- **Status:** v1.6.0 build 162. Debug build green (compile-verified unsigned on the non-cert Mac; run/eyeball still pending on M1 Max). Release build not yet cut.
- **Last updated:** 2026-07-03

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
- None.

## Resolved
- **✅ OSLog release gate (2026-07-03):** the 30+ bare `print()` calls flagged in the 2026-05-01 review had already been converted in the v1.6.0 catch-up work; the last remaining one (DEBUG-only API-key-length print in `makeRequest`) is now removed. Diagnostic export captures all production logging.
- **✅ Local git repo re-established (2026-07-03):** `.git` was gone on both Macs and origin was stale at `a28caa8` (2026-04-28, v1.5.5 era). Bootstrapped via `git-bootstrap` skill (init → fetch → `reset --mixed origin/main` → verify → catch-up commit → push); non-destructive to files. All v1.6.0 work + docs now committed as `6318080` and pushed; local `main` == `origin/main`, tree clean. Root cause was the ProPro Syncthing folder syncing/losing `.git` in branch-flip churn — now mitigated by `.git`/`.stversions` being ignored on both Macs (see memory `project-syncthing-propro-setup`).

## Next Actions
1. **Eyeball the Rescan button live** — was killed at end of session; confirm rendering/click next session (demo mode can't produce idle+pending, so force a real out-of-sync or use the `DEMO_OOS` pattern from the 2026-06-03 log). Also smoke-test the 2026-07-03 cancellation fixes (refresh during settings change shouldn't flash Disconnected).
2. **Live-verify cleanup ⌘A:** next time a stuck-delete repro is available, confirm Select All / Deselect All + ⌘A in the cleanup window (2026-06-03's repro was fixed via git, not the app's Resolve flow).
3. **Release notes + README:** draft v1.6.0 release notes (Stuck Deletions + cleanup window + grant-access flow + diagnostic export + inline Rescan button). Update README. Appcast copy.
4. **Release prep:** switch to Release config, `xcrun notarytool` submit, build DMG, Sparkle EdDSA sign, update `appcast.xml`, push to GitHub.
5. **User-side cleanup (optional):** revoke the FDA grant for `syncthingStatus.app` in System Settings — superseded by bookmarks. Leave `syncthing` (the daemon) alone.

## References
- Implementation plan: `docs/IMPLEMENTATION-PLAN-stuck-deletes.md`
- Feature design doc: `docs/FEATURE-stuck-deletes-cleanup.md`
- Latest session log: `docs/sessions/2026-06-03.md` (out-of-sync diagnosis + inline Rescan button); prior review `docs/sessions/review-2026-05-01.md`
- Decisions: `docs/decisions.md` (latch + bookmark entries dated 2026-04-29)
- Syncthing infra (cross-project): memory `project-syncthing-propro-setup` — ProPro folder ignores `.git`/`.stversions`; code syncs via GitHub
- Debug install script: `tools/install-debug-build.sh`
- Build: v1.6.0 build 162 (Debug, with inline Rescan button)

---
*Updated by Claude. Source of truth for project position.*
