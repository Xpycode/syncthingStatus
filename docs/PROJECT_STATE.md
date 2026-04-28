# Project State

> **Size limit: <100 lines.** This is a digest, not an archive.

## Identity
- **Project:** syncthingStatus
- **One-liner:** macOS menu bar app that surfaces Syncthing's sync state without opening the web UI
- **Tags:** macOS, Menu Bar, SwiftUI, Sparkle, Syncthing
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`

## Current Position
- **Phase:** Maintenance / shipping
- **Focus:** Cutting v1.5.5 release — Sparkle DMG, README refresh, GitHub release upload
- **Status:** Notarized .app received, ready to package
- **Last updated:** 2026-04-28

## Progress
```
[################....] 80% — bug fix + new icons + new settings done; release work in progress
```

| Stage | Status | Notes |
|-------|--------|-------|
| Bug fix (false-red) | **done** | Resolver leniency + stale-state pruning + defensive decoding |
| Traffic-light icon mode | **done** | Setting added, default monochrome |
| Notification cooldown | **done** | Per-folder, default 5 min |
| New asset integration | **done** | New AppIcon + 4 status icons (animation disabled) |
| v1.5.5 packaging | **active** | Sparkle sign, DMG, appcast, README, upload |

## Tech Stack
- Swift / SwiftUI on macOS (deployment target macOS 15.5)
- Combine for client state propagation
- Sparkle 2.8.1 for in-app updates (EdDSA signed appcast)
- Syncthing REST API (v2.x compatible) — `db/status`, `db/completion`, `system/connections`, `system/config`
- UserNotifications framework

## Active Decisions
- 2026-04-28: Whitelist healthy folder states (`idle`, `scanning`, `scan-waiting`, `sync-preparing`, `sync-waiting`, `cleaning`, `clean-waiting`); only declare out-of-sync when `idle` *and* `needBytes > syncRemainingBytesThreshold`. See `decisions.md`.
- 2026-04-28: Defensive per-field Codable for `SyncthingFolderStatus` — `state` defaults to `"idle"` if undecodable, so v2 API renames can't latch a false-red icon.
- 2026-04-28: Three-tier icon mode (monochrome / traffic) as a setting; default monochrome to preserve existing visuals.
- 2026-04-28: Sync-complete notifications throttled per-folder (default 5 min, configurable 0–60).
- 2026-04-28: Animation disabled in this release; machinery retained in `SyncthingStatusIcon.swift` for clean reactivation later.

## Blockers
None — release packaging in progress.

## Next Actions
1. Sparkle EdDSA sign the notarized `04_Exports/Archive/V1.5.5/syncthingStatus.app`.
2. Build `syncthingStatus-v1.5.5.dmg`.
3. Update `appcast.xml` with new `<item>` (signature, length, release notes).
4. Refresh `README.md` (new app + status icons, document new Status Icon and notification cooldown settings).
5. Hand off final artefacts to user for GitHub Release upload + git push.

## References
- Notarized build: `04_Exports/Archive/V1.5.5/syncthingStatus.app`
- Sparkle docs: `SPARKLE-SIGNING.md`
- Session log: `docs/sessions/2026-04-28.md`
- Decisions: `docs/decisions.md`

---
*Updated by Claude. Source of truth for project position.*
