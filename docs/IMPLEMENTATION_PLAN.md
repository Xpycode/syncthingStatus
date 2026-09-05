# Implementation plan — v1.7 review fixes

Updated: 2026-09-06. **Cleanup safety sprint (tasks 1.1–1.5) complete; A1–A3 passed.** The user authorized continuing the cleanup safety sprint on 2026-09-05 and deferred the GitHub follow-ups. This is the active plan; older plans describe historical work.

## Goal and scope

Make cleanup target the correct folder, make sync health trustworthy, and make refresh and recovery predictable before polishing the existing app.

The [September review](reviews/2026-09-05-usability-code-review.md) supplies the findings and preserved reproductions. [Tasks](TASKS.md) tracks the active sprint. Source inspection confirms the app already has bookmarks, path validation, cleanup confirmation, cancellation handling, notifications and a config picker: repair those paths. The Xcode project now has a hostless production test target and shared app/test schemes from task 1.1. Current production controller tests and a separate sandbox/UI harness verify the cleanup repairs.

Waves 1–4 address correctness and recovery; Wave 5 covers usability. Wave 6 is separate maintenance and may be deferred without delaying a verified safety fix. Wave 7 verifies the chosen scope. A separately requested safety-only release can branch from the completed Wave 1 gate into a scoped regression/ship review; later criteria stay openly deferred rather than being marked passed. New Feedback/Donate/Help features, certificate pinning, framework migration and polling-to-events conversion remain outside this plan. No production appcast/cask changes or release are authorized by planning.

## Deferred GitHub follow-ups

On 2026-09-05 the user authorized continuing only the cleanup safety sprint. GitHub [#2](https://github.com/Xpycode/syncthingStatus/issues/2) (genuine monochrome rendering) and [#5](https://github.com/Xpycode/syncthingStatus/issues/5) (long-path layout reproduction/fix) belong with later UI work. [#6](https://github.com/Xpycode/syncthingStatus/issues/6) needs Homebrew validation follow-through and a response. All three are explicitly linked in `TASKS.md`; handle after cleanup safety, without making them prerequisites for a safety fix.

## Acceptance criteria

| ID | Given / when | Required result |
|---|---|---|
| A1 | Root `Sync/Project`, grant `Sync`, selected `candidate` | Delete only `Sync/Project/candidate`; preserve `Sync/candidate`. Exact-root grants also work. |
| A2 | Folder path/identity, connection or access changes after cleanup/confirmation opens | Obsolete confirmation cannot authorize deletion; revalidate current configuration and require fresh selection review. Preserve the old root. |
| A3 | Absolute/empty/traversal/NUL/root-itself/symlink-escape candidate, or missing/revoked access | Reject unsafe mutation. Already-gone valid candidates retain idempotent success. Confirmation names the configured root and selected items. |
| A4 | Pending bytes/items/deletes, missing/malformed status, or latest fetch failure | Rows and icon cannot claim fully in sync. Known complete data agrees across surfaces; paused/offline peers remain distinct from API failure. |
| A5 | Overlapping refresh triggers, cancellation unwind or connection changes | One owner coalesces ordinary work; replacements complete and obsolete results cannot publish. Slow entries do not indefinitely starve later entries. |
| A6 | Legacy notification settings load; user switches off the final selected folder | Legacy empty migrates to explicit All; explicit empty selection means None, survives relaunch, and matches delivered notifications. |
| A7 | Pause/resume overlaps unrelated daemon edits | Only the target folder's paused field changes; failure stays visible and does not emit success. |
| A8 | Cleanup candidates span pages, or a later page fails/is cancelled | Candidates beyond 1,000 are reachable and deduplicated; incomplete/stale results cannot become an actionable complete list. |
| A9 | First launch, missing/revoked config access, invalid key or connection failure | Connection settings appear first; full error and direct picker/manual recovery are available. Notification permission waits for connection or explicit intent. |
| A10 | User operates Details/popover/cleanup visually, by keyboard or accessibility | Status precedes idle charts; controls name their scope; confirmation is reviewable; commands validate to focus. |

## Execution and validation

- First sprint: **1.1–1.5 only**. Promote subsequent waves after predecessor gates pass. Tasks in one wave are not automatically safe for parallel edits: `Client.swift`, `Views.swift` and `App.swift` overlap. Delegate bounded fixture work/review to Sol or Luna with explicit ownership. Split a numbered task further if it cannot fit a short implementation pass.
- Source paths below are relative to `01_Project/syncthingStatus/`; test classes are proposed files in `01_Project/syncthingStatusTests/`. New filenames/test commands describe work to create, not existing infrastructure.
- Use a hostless XCTest bundle compiling the same production files or narrowly extracted production components as the app. Exclude `App.swift`/`Views.swift` and app startup; move the status resolver out of `App.swift` when needed. No copied methods, app-hosted lifecycle, or general framework. Controller tests can compile the real `Client.swift` and its dependencies with injected external effects; helper-only tests are insufficient to close the cleanup gate.
- Use unique temporary roots, defaults suites, credential storage, stubbed HTTP and captured notifications. `SyncthingSettings` starts asynchronous Keychain work, so defaults injection alone is insufficient. `FolderAccessBookmarks` already accepts defaults, but the controller constructs its own default store: inject it. Tests must not touch real preferences, bookmarks, Keychain, login items, daemon configuration or notifications.
- Each behavioral fix needs a meaningful failing regression before repair and a passing result after it. Async tests use controllable gates, not timing sleeps. Cleanup tests enter through production candidate/controller selection and `performDeletion(selected:)`, assert preserved sibling sentinels, and state which external boundaries are stubbed. Real sandbox picker/access behavior is a separate manual gate.
- Keep App Sandbox enabled. After a successful runnable build for user testing, gracefully quit all instances of this app, confirm exit, launch the exact fresh artifact and verify its executable path. Do not hand off a test runner or replace the app after a failed build.
- UI tasks below specify proposed placement. Follow the master [UI protocol](/Users/sim/ProgrammingProjects/0-DIRECTIONS/__DIRECTIONS/36_ui-changes-protocol.md) and [control conventions](/Users/sim/ProgrammingProjects/0-DIRECTIONS/__DIRECTIONS/47_project-ui-conventions.md): trace bindings, use AppKit wrappers for new/replaced interactive controls, and verify behavior. An instruction to execute these specified placements supplies approval; clarify only material placement changes. No conversion of untouched controls or primary-window `NavigationSplitView`.

### Backpressure commands

Run from repository root. **T is available: task 1.1 created and verified the target and shared scheme.** Missing/skipped tests are not passes. Record any toolchain adjustment without weakening sandbox coverage.

**B — runnable Debug build** (local ad-hoc signing, not release validation):

```sh
xcodebuild -project 01_Project/syncthingStatus.xcodeproj -scheme syncthingStatus -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/syncthingStatus-v17-build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

**T — hostless production regression suite** (shared scheme created in 1.1):

```sh
xcodebuild -project 01_Project/syncthingStatus.xcodeproj -scheme syncthingStatusTests -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/syncthingStatus-v17-tests CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

`T(ClassName)` means append `-only-testing:syncthingStatusTests/ClassName` to T and confirm tests execute. **V** means B plus the named manual/AX scenario, with observations recorded in session/review evidence. **D** means `git diff --check` plus inspection of affected docs. **R** means B with Release replacing Debug. B/R do not establish notarization or publication readiness.

## Tasks

### Wave 1 — cleanup safety (active sprint)

- [x] **1.1 — Establish isolated production tests.** Targets: `../syncthingStatus.xcodeproj/project.pbxproj`, shared app/test schemes, `../syncthingStatusTests/`, minimal seams in `Client.swift`, `SyncthingSettings.swift`, `FolderAccessBookmarks.swift`.
  - Detailed execution plan: [task 1.1 — six substeps across three waves](PLAN-task-1.1.md), including legacy-defaults migration, login-item initialization, credential persistence, captured notifications, and the existing transport seam. Completed 2026-09-05: 15 tests passed three consecutive runs, independent isolation review found no blockers, and the sandboxed Debug build passed and was launched. [Evidence](reviews/evidence/2026-09-05/task-1.1-isolation.md).
  - Success: hostless tests run real production behavior with isolated side effects; production controller and dependencies can compile without app startup. Limit extraction/injection to what the tests need.
  - Backpressure: T with a meaningful existing-behavior case such as invalid-path rejection; B; inspect target membership and initialization effects.

- [x] **1.2 — Capture root and identity regressions.** Depends on 1.1. Targets: `CleanupSafetyTests.swift`, controller seams in `Client.swift`.
  - Success: controller-level fixtures reproduce ancestor-root and obsolete-root deletion. Include exact-root success, removed/mismatched folder, changed connection with reused ID, stale window, revoked/missing access, prefix collision, empty/absolute/traversal/NUL/root/symlink escapes and already-gone items. Assert intended target and untouched sibling/old-root sentinels (A1–A3).
  - Completed: eight controller regressions reproduced the original defects (19 tests, eight failing methods); two additional access-snapshot regressions failed before the independent-review fix. Preserved [evidence](reviews/evidence/2026-09-05/cleanup-safety.md). Reproduction alone did not mark A1–A3 passed.

- [x] **1.3 — Separate access scope from current target identity.** Depends on 1.2. Targets: `Client.swift` (`grantAccess`, `probeFolderAccess`, `performDeletion`, `deleteOne`, `validatePath`), `FolderAccessBookmarks.swift` if needed.
  - Success: typed context separates scope URL, configured root and connection/folder identity. Fetch current folder configuration by ID before deletion; fail closed on unavailable/mismatched configuration. Canonical comparison handles tilde/path aliases without mistaking them for new roots. Obsolete windows abort and require reload/review, even when a broad grant covers the new root. Scope spans mutation; deletion receives only configured root. Recheck identity across async boundaries/between items. A1–A3 pass.
  - Backpressure: T(CleanupSafetyTests), B; review symlink containment and validation-to-removal race assumptions. Do not claim path checks eliminate all concurrent filesystem races.

- [x] **1.4 — Bind confirmation to reviewed root and selection.** Depends on 1.3. Targets: `Views.swift` (`StuckDeletesView`, `CandidateRow`), controller confirmation state and deletion errors.
  - Success: existing confirmation shows configured root plus a scrollable selected-name list and permanent-delete consequences. Snapshot reviewed selection/identity; changes invalidate confirmation. Label selection controls by candidate; retain failed selections for retry. Missing access offers folder regrant; replace obsolete Full Disk Access guidance on this path.
  - Backpressure: T(CleanupSafetyTests) for stale confirmation/selection; V with Cancel, Select All, empty selection, failed preflight, partial failure/retry and rescan outcome using disposable fixtures.

- [x] **1.5 — Close the destructive-path gate.** Depends on 1.3–1.4. Targets: cleanup diff/tests, new evidence under `docs/reviews/evidence/`, task/state docs.
  - Success: independent review traces access picker → selection → confirmation → mutation. Investigate disagreements. Real sandbox fixtures cover exact/ancestor grants, relaunch persistence, revoked/obsolete grants and path change with an open window. Record automated/manual coverage separately; clear the blocker only after A1–A3 pass.
  - Completed: 49 tests passed (40 cleanup), independent source review passed after its two findings were fixed, and real sandbox/native-window fixtures passed with production-equivalent filesystem entitlements. Fresh Debug app built/launched. [Evidence and limits](reviews/evidence/2026-09-05/cleanup-safety.md). This closes A1–A3, not whole-release readiness.

### Wave 2 — one truthful status policy

Depends on Wave 1. Establish status semantics before refresh publication and notification work.

- [ ] **2.1 — Specify and test the status decision table.** Targets: `Models.swift`, `Helpers.swift`, resolver in `App.swift` → new `SyncStatusPolicy.swift`, `SyncStatusTests.swift`.
  - Success: fixtures cover known complete, bytes/files/directories/symlinks/deletes, malformed/missing data, failed latest fetch with cached values, paused folders, scanning/syncing and offline peers. Empty folder list says no folders. Thresholds cannot erase pending item/delete counts; device completion with four deletes is not complete.
  - Backpressure: T(SyncStatusTests), recording the review's false-healthy cases failing before repair.

- [ ] **2.2 — Preserve status validity through decoding/publication.** Depends on 2.1. Targets: `Models.swift` (`SyncthingFolderStatus`), `Client.swift` (`fetchFolderStatus`), `SyncStatusPolicy.swift`.
  - Success: distinguish known zero from required-field absence, malformed payload and latest-fetch failure; cached data is explicitly stale/unavailable. Tolerate unknown extra fields and avoid double-counting total/individual counters.
  - Backpressure: T(SyncStatusTests), B.

- [ ] **2.3 — Route display and completion consumers through the policy.** Depends on 2.2. Targets: icon resolver, `Helpers.swift` pending/effective-sync helpers, `Views.swift` summaries, `Client.swift` completion tracking.
  - Success: A4 passes across rows and both icon styles; unknown/pending status cannot trigger global or folder completion notifications. Peer availability stays distinct from API reachability.
  - Backpressure: T(SyncStatusTests), V with idle, pending-delete, unavailable, paused and offline-peer fixtures.

### Wave 3 — refresh ownership and bounded progress

Depends on Wave 2. Scheduler cancellation is reproduced; the specific offline-peer timeout remains a hypothesis.

- [ ] **3.1 — Add deterministic scheduler regressions.** Targets: `Client.swift` refresh seams, `RefreshTests.swift`.
  - Success: controlled gates reproduce cancellation unwind dropping the replacement. Cover timer/manual bursts, URL/key/config-grant changes, late old results, interval changes, shutdown and demo transitions; count active passes and published generations without sleeps.
  - Backpressure: T(RefreshTests); record the known failure before repair.

- [ ] **3.2 — Give monitoring one owner.** Depends on 3.1. Targets: `Client.swift` refresh/settings subscriptions, `App.swift` monitoring/timer triggers.
  - Success: ordinary triggers join/coalesce active work into at most one follow-up. Connection changes cancel/await old work and start the latest generation; only that generation publishes state/notifications. No duplicate timers or false-disconnected cancellation; manual refresh eventually completes (A5).
  - Backpressure: T(RefreshTests), B, independent concurrency review.

- [ ] **3.3 — Measure request costs and settle the offline observation.** Depends on 3.2. Targets: existing OSLog request paths, new measurement evidence, TASKS Inbox.
  - Success: record endpoint duration, cancellation and entry order using delayed stubs and a read-only offline-peer observation when available; exclude credentials/bodies. Explicitly record reproduced, not reproduced, or unavailable. Keep the Inbox observation if real evidence is unavailable; do not block the confirmed scheduler fix.
  - Backpressure: documented measurement run and T(RefreshTests) for timing/cancellation behavior. No timeout diagnosis from stubbed delay alone.

- [ ] **3.4 — Keep slow entries from starving later entries.** Depends on 3.2–3.3. Targets: `Client.swift` folder/completion loops and request cancellation, `RefreshTests.swift`.
  - Success: select and record a small concurrency/deadline bound from measured costs before implementing it. Delayed first/middle/last entries do not prevent fast entries publishing within that bound; failures affect relevant status only. No unbounded fan-out or polling-interval workaround. Stub evidence can validate fairness without proving the offline hypothesis.
  - Backpressure: T(RefreshTests) asserting request cap, bounded progress and generation isolation; V for responsive refresh and stable About version.

### Wave 4 — notifications, daemon actions and recovery

Depends on Wave 3. Tasks 4.1–4.4 overlap source files; execute serially unless ownership is separated.

- [ ] **4.1 — Persist explicit notification selection.** Targets: `SyncthingSettings.swift` keys/init/save/reset, client notification predicate, existing per-folder Settings section, `NotificationSelectionTests.swift`.
  - Success: place All/Selected mode beside the existing folder list. Legacy empty/missing migrates to All; nonempty to Selected. Selected empty means None. In All, every row shows enabled and new folders are included; turning one off creates an explicit remaining selection. Persist mode and deduplicated IDs; retain global enable/cooldown behavior (A6).
  - Backpressure: T(NotificationSelectionTests) for migration, reset, reload, all/one/none and captured delivery; V for switches and relaunch.

- [ ] **4.2 — Patch only the requested pause state.** Targets: `Client.swift` (`setFolderPausedState`, narrow JSON helper), `FolderPauseTests.swift`.
  - Success: PATCH individual folder endpoint with only `paused`, correct ID encoding and JSON headers; no whole-config write/fallback. Different-folder requests preserve unrelated edits; opposite actions on one folder serialize/coalesce to latest intent. Notify/update only after success and directly refresh through the new owner. Handle 401/403/404/server failure visibly (A7).
  - Backpressure: T(FolderPauseTests) asserting method/path/body and concurrent fixture state, B; use a disposable daemon for any live mutation test.

- [ ] **4.3 — Load complete cleanup pages with cancellation.** Targets: client `fetchDbNeed`, controller `loadCandidates`, `Models.swift` response, cleanup loading UI, `CleanupPaginationTests.swift`.
  - Success: paginate on demand across progress/queued/rest until a short/empty raw page; termination uses raw count before filtering/deduplication, never `total`. Accumulate privately, deduplicate relative identities; conflicting duplicates fail the load for retry rather than guess deletion eligibility. Detect repeated/nonprogressing pages. Disable deletion while incomplete; close/reload/identity change cancels obsolete publication (A8).
  - Backpressure: T(CleanupPaginationTests) for 0/1,000/1,001, exact multiples, mixed arrays, duplicates/conflicts, full pages with no candidates, repeated page, page-two failure and cancellation; T(CleanupSafetyTests), V.

- [ ] **4.4 — Reuse the picker for direct connection recovery.** Targets: `Views.swift` Settings/Disconnected/Footer and `selectSyncthingConfig`, small shared picker action if needed, client credential errors, `App.swift` permission trigger, `ConnectionRecoveryTests.swift`.
  - Success: automatic/manual Connection sections lead Settings. Show full error beside disconnected recovery controls; reuse picker for missing/revoked config access and manual settings for key/URL errors. Preserve real-home picker hint; discovery does not grant sandbox access. Request notifications on first successful connection with notifications enabled or explicit intent, respecting prior denial (A9).
  - Backpressure: T(ConnectionRecoveryTests) for error/action and authorization policy with injected effects; V using isolated clean preferences, picker cancel/regrant, bad config/key, loopback HTTPS and denied permission.

- [ ] **4.5 — Verify combined recovery/action flows.** Depends on 4.1–4.4. Targets: integration evidence and task/state docs.
  - Success: A5–A9 pass through reconnect during refresh/cleanup loading, notification changes, pause actions and unavailable/partial-failure states; no stale publication or misleading success. Keep unresolved offline observation separate.
  - Backpressure: T, V for those combined cases, D.

### Wave 5 — focused UI and accessibility polish

Depends on Wave 4. Preserve the existing popover/window shell and verify its height-measurement chain.

- [ ] **5.1 — Put monitoring status before idle charts.** Targets: `Views.swift` Content/Header/Footer.
  - Success: Details shows problems/folders/devices before statistics/charts; keep complete popover list. Clarify API reachable versus peers offline. Rename Window to Details; remove footer Update but preserve Settings/main-menu update access. Keep one explicitly scoped global pause control.
  - Backpressure: V at existing 700-point Details height, short/long lists, light/dark, pending work/offline peers, reachable footer and scrolling.

- [ ] **5.2 — Group advanced settings and verify disconnected sizing.** Targets: Settings tuning/diagnostics, height producers and `App.swift` sizing only if reproduced; TASKS Inbox.
  - Success: Connection/basic notifications remain visible; thresholds/polling/diagnostics move to Advanced after basic settings. Reproduce first-launch sizing with isolated preferences and no grant, fixing only observed failure. Preserve max-reduction/outer-observer measurement behavior; record evidence if unconfirmed.
  - Backpressure: V for first launch, long errors, connected/disconnected transitions, short/long lists and max-height settings. No automated tests solely for section ordering.

- [ ] **5.3 — Make action scope accessible and discoverable.** Targets: header/device/folder/cleanup controls, `App.swift` commands/focused actions, narrow AppKit wrappers as needed.
  - Success: labels distinguish all devices from named device/folder and candidate selection. Reuse action handlers in an app action menu for Refresh/Web UI/global pause and focused Rescan/cleanup/selection where applicable. Disable invalid targets; preserve confirmation/access gates and standard About/Settings/Updates/Quit slots. Follow master `46_main-menu.md`; shortcuts have one command owner.
  - Backpressure: V with AX/VoiceOver, keyboard, focus changes and Help menu search; T(CleanupSafetyTests) if routing changes.

- [ ] **5.4 — Verify the combined UI changes.** Depends on 5.1–5.3. Targets: screenshots/AX evidence and task/state docs.
  - Success: A9–A10 pass in the fresh app; readable confirmation, truthful scope, visible recovery and unclipped primary actions. Explicitly record untested appearance/accessibility states.
  - Backpressure: V for connected/offline/disconnected, Settings, Details, cleanup and menus; D.

### Wave 6 — optional separate maintenance

Depends on Wave 5. Explicitly defer these if needed; they must not hold a verified safety repair or mix into Wave 1 changes.

- [ ] **6.1 — Extract cleanup and Settings responsibilities.** Targets: `Client.swift` → `StuckDeletesController.swift`; `Views.swift` → `StuckDeletesView.swift` / `SettingsView.swift`; target memberships.
  - Success: move behavior without changing state ownership/bindings. Skip moves already made as necessary test seams and record why.
  - Backpressure: T(CleanupSafetyTests), T(CleanupPaginationTests), B, focused V for Settings/cleanup.

- [ ] **6.2 — Isolate demo generation and developer scenarios.** Targets: client demo methods → `DemoData.swift`, app demo menu.
  - Success: preserve a simple public demo entry; compile screenshot/layout developer controls only in DEBUG. Demo entry/exit restores monitoring without stale real data or real cleanup/daemon actions.
  - Backpressure: T(RefreshTests) for demo transitions, B, V for entry/exit; Release menu inspection in Wave 7.

- [ ] **6.3 — Consolidate duplicated HTTP helpers.** Targets: client request helpers, small `SyncthingTransport.swift` if useful, `TransportTests.swift`.
  - Success: preserve credentials, query/ID encoding, raw/decoded/empty responses, PATCH, errors, cancellation and loopback-only self-signed trust; no general networking framework. Add missing transport contract regressions before consolidation.
  - Backpressure: T(TransportTests), T(RefreshTests), T(FolderPauseTests), T(CleanupPaginationTests), B; local HTTPS fixture for trust behavior.

- [ ] **6.4 — Remove demonstrably unused icon animation code.** Targets: `SyncthingStatusIcon.swift` and call sites.
  - Success: trace references; remove only dead machinery and retain active icon states/intentional animation. If still used, document and skip instead of changing behavior to meet a cleanup quota.
  - Backpressure: `rg -n 'animation|animate|Timer' 01_Project/syncthingStatus`, B, V for both icon styles/state transitions.

### Wave 7 — integration and release readiness

Depends on Waves 1–5 and selected Wave 6 tasks. Publication remains a separate requested action.

- [ ] **7.1 — Verify the selected implementation as a whole.** Targets: production/test source, fresh artifacts, new review evidence, plan/task/state docs.
  - Success: suite passes; independent destructive-path/concurrency reviews have no unresolved blockers; A1–A10 automated/manual evidence is attached for the full v1.7 scope. Release compiles; verify new demo/menu behavior if 6.2 was included, otherwise preserve existing availability. Explicitly record deferred maintenance and runtime limits. Recheck previously passing work only when integration changes or unresolved risks warrant it.
  - Backpressure: T, B, R, V combined smoke flow, D. Record the exact fresh user-testing artifact and verified running path.

- [ ] **7.2 — Record release readiness and distribution limits.** Depends on 7.1. Targets: release-readiness review, `docs/homebrew.md`, task/state docs and release notes for verified changes.
  - Success: run `/check ship` before recommending release. Recheck the recorded Homebrew supported-Xcode prerequisite and test install/upgrade separately from the existing installation; record unavailable checks rather than passing them. Keep website Homebrew handoff visible. For separately requested publication, follow `homebrew.md` Release maintenance: DMG first, then live Sparkle/cask metadata and website deployment.
  - Backpressure: `/check ship`, applicable audit/install commands in `docs/homebrew.md`, D. Distribution toolchain limits do not block ordinary source fixes.

## API contracts checked

Verified 2026-09-05 against official documentation:

- Individual folder config supports PATCH of supplied child fields. [Configuration endpoints](https://docs.syncthing.net/rest/config.html).
- Needed-item pagination spans three arrays, has no `total`, and is expensive: keep on demand. [Needed items](https://docs.syncthing.net/rest/db-need-get.html).
- `need*` counters represent remaining work, including directories/symlinks/deletes; status calls are expensive. [Folder status](https://docs.syncthing.net/rest/db-status-get.html).

## Blockers and operational learnings

- Cleanup root/identity blocker cleared: A1–A3 passed automated, independent-review and real sandbox/UI gates. Later correctness and recovery waves remain queued.
- Test infrastructure is complete in 1.1; the target and shared scheme are available. Homebrew full audit has a recorded toolchain limitation; offline timeout and disconnected sizing remain observations until measured.
- Hostless tests do not prove sandbox picker/TCC behavior. Stale bookmark data differs from an obsolete configured root. A false return from starting security scope alone does not establish denied access.
- A broad grant can cover a new folder, but old selections cannot silently transfer. Canonical path checks are not a promise against every filesystem race; record assumptions after review.
- Pagination is not an atomic daemon snapshot. Fail incomplete/conflicting loads visibly and retain target/confirmation validation.
- Model fit: deep reasoning for destructive identity/concurrency; Sol/Luna for bounded fixture work and independent review with explicit source ownership.

## Execution log

Plan expanded with Sol/Luna source inspection on 2026-09-05. No application fixes, tests, builds, runtime preference changes or publication occurred during planning.

| Wave | State | Completion evidence |
|---|---|---|
| 1 — cleanup | Complete: 1.1–1.5; A1–A3 passed | [Cleanup verification](reviews/evidence/2026-09-05/cleanup-safety.md): 49 tests, independent review, real sandbox/UI, Debug build/launch |
| 2 — status | Queued | Pending |
| 3 — refresh | Queued | Pending |
| 4 — controls/recovery | Queued | Pending |
| 5 — UI/accessibility | Queued | Pending |
| 6 — maintenance | Queued; separately deferrable | Pending |
| 7 — verification/readiness | Queued | Pending |
