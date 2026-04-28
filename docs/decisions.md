# Decisions Log

This file tracks the WHY behind technical and design decisions.

---

## Template

### [Date] - [Decision Title]
**Context:** [What situation prompted this decision?]
**Options Considered:**
1. [Option A] - [pros/cons]
2. [Option B] - [pros/cons]

**Decision:** [What we chose]
**Rationale:** [Why we chose it]
**Consequences:** [What this means going forward]

---

## Decisions

### 2026-04-28 — Whitelist healthy folder states; tighten the meaning of `.outOfSync`
**Context:** The menu bar icon was showing red ("Out of sync") even when Syncthing's web UI and API both reported every folder as `state: idle, needFiles: 0`. Restarting the app cleared it; the bug recurred after a while. Diagnosis: `StatusIconStateResolver.resolveState` treated *any* state other than literal `"idle"` as out-of-sync, so a single transient `scanning` reading captured into `folderStatuses` would latch the icon to red until something else (manual restart, config change) refreshed the entry.

**Options Considered:**
1. **Keep strict whitelist of `idle`, fix only the staleness in `Client.fetchFolderStatus`.** Smallest diff. Doesn't help the cases where Syncthing legitimately spends time in `scanning` / `scan-waiting` between idles — those would still flicker red.
2. **Whitelist all healthy/transient states; only declare `.outOfSync` for `idle` *and* `needBytes` over threshold.** More forgiving. Slightly slower to flag a real desync, but a status indicator should err toward calm.
3. **Add a debounce around state reads to ignore brief non-idle blips.** Adds latency and complexity; doesn't solve the underlying "what counts as healthy" semantic problem.

**Decision:** Option 2 — `healthyFolderStates` constant covers `idle / scanning / scan-waiting / sync-preparing / sync-waiting / cleaning / clean-waiting`. Plus folder `error` state promoted to its own red rule. Plus stale-state hygiene (Option 1's fixes) as a belt-and-braces measure.

**Rationale:** A status indicator's job is to be calm by default and loud when something is genuinely wrong. Treating routine scans as "wrong" trains the user to ignore the red icon — exactly what happened to this user. The threshold-based out-of-sync rule (`idle && needBytes > syncRemainingBytesThreshold`) reuses the user's own configurable threshold so power users still have a knob for "how behind is too behind."

**Consequences:** Slightly slower to surface a real desync (have to reach idle with significant pending bytes). The OSLog line in `Client.swift` provides backstop visibility — if the icon ever does false-red again, Console.app filtered on subsystem `com.lucesumbrarum.syncthingStatus` will show the failed fetch.

---

### 2026-04-28 — Per-field defensive Codable for Syncthing API structs
**Context:** Syncthing v2 silently renamed `lastScan` → `stateChanged` in `/rest/db/status`. With strict struct-level decoding, any single field rename voids the whole struct, the catch path leaves stale data in `folderStatuses`, and the resolver paints red on stale data.

**Decision:** Custom `init(from:)` on `SyncthingFolderStatus` decoding each field independently with `try?` and a sane default. `state` specifically defaults to `"idle"` because the *failure mode of guessing wrong* should be "icon stays calm" not "icon stuck red."

**Consequences:** Worth doing for any consumer of an evolving external JSON contract. Pattern reusable for `SyncthingDeviceCompletion`, `SyncthingConnection` if v2 changes those next.

---

### 2026-04-28 — Three-tier icon mode (monochrome / traffic) as a setting, default monochrome
**Context:** User asked for green/amber/red instead of binary normal/error.

**Decision:** New `IconColorMode` enum, default `monochrome` (existing visual behavior preserved). `traffic` mode promotes paused-device states and partial-sync states to amber via a new `.warning` icon. Asset-fallback in `SyncthingStatusIcon` so `.warning` collapses to `.normal` if the WARN PNG isn't bundled — let code ship before assets exist.

**Consequences:** Existing users see no change unless they opt in. Future variants (e.g. high-contrast mode, color-blind palette) can extend the same enum without touching the resolver.

---

### 2026-04-28 — Per-folder cooldown on sync-complete notifications, in-memory state
**Context:** "Every small sync raises a notification, training me to ignore them."

**Decision:** `syncNotificationCooldownMinutes` (default 5, range 0–60). Per-folder, not global, so a noisy folder doesn't suppress notifications from a calm folder that finally completes. State held in-memory (`lastSyncNotificationDates`); a relaunch resets cooldowns intentionally — "I just opened the app, I want to know what's happening."

---

### 2026-04-28 — Animation disabled but machinery retained
**Context:** New status icons are static (one frame each). User said "disable the animation for now."

**Decision:** `set(state:)` for the three sync states (`uploading`/`downloading`/`upAndDown`) routes to a static `applySyncingIcon` instead of `startAnimation`. The `frameSets` table and `startAnimation` / `handleAnimationTick` methods are intentionally retained, unreferenced.

**Rationale:** Re-enabling later is a one-block revert in `set(state:)`. Deleting and re-adding would lose the existing tuning (frame interval = 0.5s, runloop in `.common` mode). Sometimes the most valuable thing dead code preserves is the *decisions baked into it*.

---
*Add decisions as they are made. Future-you will thank present-you.*
