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

### 2026-04-29 — Latch stuck-delete detection across state transitions
**Context:** Live testing on M1 Max revealed the stuck-deletes alert row flapping every ~60 s. `updateStuckDeletesSignal()` was using the same fingerprint (`state == idle && needDeletes > 0 && needFiles == 0 && needBytes == 0`) for both initial detection and ongoing persistence. Each periodic rescan briefly transitioned the folder to `scanning`, the fingerprint failed, `firstSeenStuckAt` was wiped, the folder was dropped from `stuckDeleteCounts`, and the 30-s entry debounce restarted. Net effect: the popover's "Resolve…" button was visible roughly 50 % of the time and unusable as an entry point.

**Options Considered:**
1. **Drop `state == idle` from the fingerprint entirely.** Simplest. But would let initial detection fire mid-scan during startup, producing false positives on a freshly-launched app whose folders are still being inspected.
2. **Two-stage state machine: idle-required for entry, state-agnostic for persist.** Detection still requires a 30-s idle window (defensive against startup churn). Once the alert publishes, it stays as long as `needDeletes > 0 && needFiles == 0 && needBytes == 0` — i.e., the items remain stuck-eligible regardless of which transient state the folder cycles through.
3. **Add a separate, longer "exit debounce" timer.** Symmetric with the entry debounce. More moving parts, harder to reason about, and provides no real benefit over the latched approach since rescan transitions are the noise we want to ignore wholesale.

**Decision:** Option 2. `isStuckEligible` (state-agnostic) drives persistence; `isIdleStable` (state-restricted) drives entry. `lastLoggedStuckState[id] == true` is the latch flag — once set, the persistence path keeps republishing the count from each poll's `needDeletes`.

**Rationale:** The user's mental model of "stuck" is about the items, not the folder's instantaneous state. A folder mid-rescan with the same 10 stuck deletions is *just as stuck* as a folder at idle with the same 10. Treating rescans as "maybe it's resolving itself" was wrong — the rescan can't resolve a stuck delete (that's the whole point of the bug).

**Consequences:** Alert is now sticky until something *real* changes (count drops, sync work appears). Side-fix in the same commit: the "log only on transitions" path was re-firing `cleared` every poll because the where-clause checked `newCounts[id] == nil`, true forever after clearing. Gated on the previously-stored `wasDetected == true` so we log exactly once per transition.

---

### 2026-04-29 — Security-scoped bookmark via NSOpenPanel instead of Full Disk Access
**Context:** End-to-end testing showed the FDA gate firing for `/Users/sim/ProgrammingProjects` even after the user added syncthingStatus to the FDA list and toggled it on. Two compounding issues:
- The folder root isn't in a TCC-protected location (Documents/Desktop/iCloud), so the user's mental model of "where does FDA matter" doesn't match the OS's actual gate.
- The app is sandboxed (`com.apple.security.app-sandbox = true` from Xcode's Signing & Capabilities, despite the `.entitlements` file being empty in source). The probe's `contentsOfDirectory(atPath:)` returns `.fileReadNoPermission` because the path is outside the sandbox container, regardless of TCC state.
- FDA *can* override the sandbox, but only on processes started after the grant. The user has to add the app via `+`, toggle on, fully quit, and relaunch — at which point most users have given up.

**Options Considered:**
1. **Drop sandbox.** Five-second toggle in Signing & Capabilities, FDA prompt vanishes, full filesystem access. **But** Mac App Store requires sandbox — kills that distribution channel forever.
2. **Stay sandboxed, swap FDA for security-scoped bookmarks via `NSOpenPanel`.** Proper sandbox pattern. Apple-documented. ~half-day refactor. One folder picker per Syncthing folder root, ever; no FDA prompts; no quit/relaunch dance.
3. **Stay sandboxed, add a temp-exception entitlement (`com.apple.security.temporary-exception.files.absolute-path.read-write`).** Avoids the bookmark plumbing but pins the app to specific paths at signing time — useless for a tool that operates on user-configured Syncthing folder roots.

**Decision:** Option 2. User explicitly committed to keeping App Store distribution viable, even at the cost of more refactor work.

**Consequences:**
- New `FolderAccessBookmarks.swift` (bookmark store keyed by Syncthing folder ID, in `UserDefaults` under `FolderAccessBookmark.<id>`, with `refresh(_:for:)` for in-place stale recovery).
- `StuckDeletesController` rename pass: `fdaBlocked → accessBlocked`, `recheckFDA → recheckAccess`, `openFDASettingsAction → requestAccessAction`. `AccessProbeResult.permissionDenied` removed; `.granted` now carries the resolved `URL`; `.needsBookmark` is the new "user must act" state.
- `performDeletion` wraps the entire delete loop in `startAccessingSecurityScopedResource()` on the resolved folder root URL. Process-level access covers the detached `Task.detached` per-item operations — no per-item start/stop.
- `StuckDeletesWindowController` opens `NSOpenPanel` as a sheet on the cleanup window. `directoryURL` set to the *parent* of `folder.path` so the user can pick the folder root in one click. `panel.prompt = "Grant Access"`.
- Path-validation lives on the controller (`grantAccess(_:)`), not in the AppKit closure — `lastError` is `private(set)` and the closure can't write it.
- Stale bookmarks refresh transparently inside the probe's access scope. Genuine path issues (`notFound`, `notADirectory`, `other`) still classify correctly — the "actionable error vs. misleading gate" property from the original FDA fix-pass carries forward.
- Existing FDA grant on the user's machine becomes vestigial after this lands. Worth mentioning in release notes so users can revoke it.

---

### 2026-04-28 — Animation disabled but machinery retained
**Context:** New status icons are static (one frame each). User said "disable the animation for now."

**Decision:** `set(state:)` for the three sync states (`uploading`/`downloading`/`upAndDown`) routes to a static `applySyncingIcon` instead of `startAnimation`. The `frameSets` table and `startAnimation` / `handleAnimationTick` methods are intentionally retained, unreferenced.

**Rationale:** Re-enabling later is a one-block revert in `set(state:)`. Deleting and re-adding would lose the existing tuning (frame interval = 0.5s, runloop in `.common` mode). Sometimes the most valuable thing dead code preserves is the *decisions baked into it*.

---

### 2026-07-03 — Cancellation detection is typed, never string-matched
**Context:** `SyncthingClient.refresh()` cancels the previous in-flight refresh by design, so every fetcher must treat cancellation as "superseded, do nothing" rather than a failure. Five call sites did this by checking `error.localizedDescription.contains("cancelled")`; `fetchStatus()` didn't check at all and flipped `isConnected = false` on a cancelled request (false "Disconnected"/red-icon flash — same family as the v1.5.5 false-red bug).

**Decision:** One shared helper, `isCancellationError(_:)` in `Client.swift`, checking `error is CancellationError || (error as? URLError)?.code == .cancelled`. All fetchers (including `fetchStatus` and `StuckDeletesController.loadCandidates`) guard on it before mutating any published state.

**Alternatives considered:** Keep per-site string matching — rejected: `localizedDescription` is localized by definition, so on a non-English macOS the substring never matches, the guards silently die, and transient cancellations leak into the error banner. Catch `CancellationError` only — rejected: URLSession surfaces cancellation as `URLError(.cancelled)`, not `CancellationError`, so both must be covered.

**Consequences:** Cancelled refreshes are invisible to the UI on every locale. Any future fetcher must call `isCancellationError` first in its `catch` — string-matching error descriptions is off the table as a pattern.

---
*Add decisions as they are made. Future-you will thank present-you.*
