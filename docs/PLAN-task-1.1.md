# Task 1.1 — isolated production tests

Status: completed and verified 2026-09-05 on `fix/isolated-production-tests`. This expands [task 1.1 in the active plan](IMPLEMENTATION_PLAN.md#wave-1--cleanup-safety-active-sprint). All task 1.1 gates below passed; parent task 1.1 is complete. Tasks 1.2–1.5 remain open.

## Goal

Run hostless XCTest tests through the actual settings, client and cleanup controller, using disposable data and substituted system services, so task 1.2 can reproduce cleanup defects safely.

Task 1.1 establishes infrastructure and passing baseline behavior. Ancestor/obsolete-root regressions belong to 1.2, repairs to 1.3, confirmation changes to 1.4, and real sandbox validation to 1.5. Do not change deletion policy, refresh ownership, notification semantics or pagination here. The cleanup release blocker remains open.

## Source findings

Paths in this document are relative to `01_Project/` unless stated otherwise.

| Existing code | Gap to address |
|---|---|
| `syncthingStatus.xcodeproj/project.pbxproj`: one app target; synchronized source folder; Swift 5 language mode; macOS 15.5 | Add an explicit hostless test target and checked-in app/test schemes. Xcode 26.6 was verified during planning; hostless tests and the Debug app now compile successfully. |
| `SyncthingSettings.swift`: injected defaults, concrete private Keychain helper, asynchronous credential load/save | A unique defaults suite or Keychain service name alone does not isolate all effects. Use an in-memory credential adapter. |
| Settings initializer always calls legacy migration; `launchAtLogin` has an eager system getter and a system setter | Isolate the legacy migration source and both login-item operations, including property initialization. |
| `SyncthingClient.init(settings:session:)` already accepts a session | Reuse this seam. Settings subscriptions can launch refresh after a debounced credential change; await credential readiness before constructing the client. |
| Five notification submission sites call `UNUserNotificationCenter.current()` | Route submission through one injected delivery closure/adapter; the live default must acquire the center lazily. |
| `StuckDeletesController` constructs `FolderAccessBookmarks()` internally | Inject the bookmark store and security-scope start/stop operations, preserving the actual access probe and target selection. |
| `performDeletion` loads selection from `candidates`, validates and removes with real Foundation, rescans, sleeps two seconds, reloads | Enter via `loadCandidates()` and selected candidate IDs. Inject only the reconciliation wait; retain production validation/removal on temporary files. |
| `Helpers.swift` supplies `realPath`, formatting and sync helpers used by the client | Compile it from its original location. Importing SwiftUI for helpers does not require compiling app startup or views. |

## Architecture and isolation rules

- Compile the same seven production files into the test bundle: `Client.swift`, `Models.swift`, `Constants.swift`, `Helpers.swift`, `SyncthingSettings.swift`, `FolderAccessBookmarks.swift`, and `LaunchAtLoginHelper.swift`, plus any narrow dependency declarations added beside them. Keep the controller in `Client.swift` for this task. Do not copy sources, replace production classes with test lookalikes, or create a framework/package.
- Give the test target explicit source references to those files and its own test sources. Keep automatic app membership intact and prevent duplicate compilation. Exclude `App.swift`, `Views.swift`, icon/UI files, `UpdateController.swift`, assets, app Info.plist, app entitlements and Sparkle from the test target. No app target dependency or app executable import is needed.
- Configure a macOS unit-test bundle with a distinct identifier, generated test Info.plist, and empty `TEST_HOST`/`BUNDLE_LOADER`. Preserve app deployment, signing and sandbox settings. Hostless execution is not evidence of sandbox/TCC enforcement; record the runner's effective settings.
- Keep live initializer defaults equivalent to current behavior. Test fixtures must supply every effectful dependency explicitly. Avoid `isTesting` branches and environment-variable behavior switches.
- Each fixture owns an absolute temporary root, unique defaults suite, in-memory credentials, fake login-item state, captured notifications, scripted bookmark results and an ephemeral URLSession. No automatic config discovery or real config bookmark is used. Test URLs, configured roots and fake bookmark roots must all be fixture-owned.
- Install a custom `URLProtocol` on the injected ephemeral session. Claim every HTTP(S) request, return only scripted responses, and fail unexpected requests without forwarding to the network. Capture method, path, query and synthetic API-key assertions. Use per-fixture routing with synchronized storage; never a mutable global handler shared between tests. Apple documents session-specific custom protocols through [`protocolClasses`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/protocolclasses).
- Stub the bookmark/OS permission boundary, not `probeFolderAccess`, `validatePath`, `deleteOne`, candidate filtering or outcomes. Retain real `stat`, directory reads and `FileManager` removal within the disposable fixture. Later ancestor/obsolete-root tests must be able to exercise the defective root handoff unchanged.
- Async tests run controller operations on `@MainActor`, await explicit completion/expectations, and use a controllable reconciliation wait. Timeouts are failure bounds, not synchronization sleeps. Teardown drains/cancels owned work before removing only that fixture's resources.

## Acceptance criteria

- [x] The checked-in `syncthingStatusTests` scheme executes nonzero tests without starting the application, Sparkle, notification authorization or UI.
- [x] Tests compile the production controller/client/settings files from their original paths; no frozen review harness or helper-only substitute satisfies the gate.
- [x] Settings initialization, persistence and teardown use isolated defaults/legacy source, in-memory credentials and fake login-item operations. No real Keychain or login-item calls occur.
- [x] All test HTTP and notification delivery are captured. Unexpected HTTP requests fail locally; no daemon requests or configuration writes leave the runner.
- [x] A baseline test loads candidates through the real client/controller, selects a traversal candidate, invokes `performDeletion(selected:)`, records a failed item and preserves the fixture's sibling sentinel.
- [x] Exact-root deletion removes only the selected disposable candidate; missing access blocks deletion; unselected items survive. Rescan/reload are scripted and observable.
- [x] Tests complete repeatedly with no leaked work or fixture state; the runnable Debug app builds with its sandbox enabled and is relaunched according to the standing preference.

## Implementation steps

Execute serially: these steps share the project and production source files. Each step is a bounded implementation pass; split further if validation reveals a larger change. The six substeps remain under parent sprint item 1.1 rather than expanding the five-item sprint.

### Wave A — executable test bundle

- [x] **1.1a — Add hostless target and shared schemes.**
  - Files: `syncthingStatus.xcodeproj/project.pbxproj`, `syncthingStatus.xcodeproj/xcshareddata/xcschemes/{syncthingStatus,syncthingStatusTests}.xcscheme`, `syncthingStatusTests/CleanupSafetyTests.swift`.
  - Work: configure the membership and hostless settings above. Add one existing production `validatePath` rejection test using a temporary root, without constructing settings or client yet. Test scheme builds only the test bundle and lists it as a testable; app scheme retains ordinary build/run/archive actions.
  - Done: Xcode discovers and runs the named test; build logs show original production sources and no app startup sources. Do not instantiate effectful production defaults before Wave B is complete.
  - Backpressure: project plist/scheme parsing, `T(CleanupSafetyTests)`, inspect effective `TEST_HOST`, `BUNDLE_LOADER`, source membership and test count.

### Wave B — isolate external effects (depends on A)

- [x] **1.1b — Isolate settings initialization and persistence.**
  - Files: `syncthingStatus/SyncthingSettings.swift`, `syncthingStatus/LaunchAtLoginHelper.swift` if its adapter needs a declaration, `syncthingStatusTests/SettingsIsolationTests.swift`, test support.
  - Work: introduce a small credential read/save/delete interface implemented by the existing Keychain helper; inject a thread-safe in-memory implementation in tests. Inject legacy migration source selection (live default opens the old suite lazily; tests use nil or a disposable old suite). Replace eager login-item access with injected read/write operations. Preserve current live async load, autosave, migration and error handling.
  - Done: isolated settings load the synthetic credential; changing/resetting settings persists only into fixture stores. An explicit completion/drain seam for owned credential/persistence work makes readiness and teardown observable without sleeps or bypassing persistence logic. Drain pending debounced saves before releasing suites. No production default adapter is eagerly evaluated on the injected path.
  - Backpressure: `T(SettingsIsolationTests)` covering initialization plus credential save/delete, fixture legacy migration, login toggle and deterministic teardown; inspect every effectful initializer/default property.

- [x] **1.1c — Capture transport and notifications.** Depends on 1.1b.
  - Files: `syncthingStatus/Client.swift`, `syncthingStatusTests/ClientIsolationTests.swift`, `syncthingStatusTests/Support/StubURLProtocol.swift`, shared fixture support.
  - Work: reuse session injection; route all five notification deliveries through a narrow injectable operation with the existing completion/error behavior. Seed manual connection mode and synthetic credentials, await credential readiness, then construct the real client. Bootstrap its private URL/key state through `await client.refresh()` with scripted system status/config/version/connections responses; use empty folders/devices initially to bound requests.
  - Done: one real refresh reaches fixture responses; a notification-producing action is captured; an unexpected request returns a test failure without network fallback. No scheduler rewrite, disabled settings subscriptions or public credential-state setter is introduced.
  - Backpressure: `T(ClientIsolationTests)` with expected request count/content, captured notification and unexpected-request failure behavior; inspect all session and notification call sites.

- [x] **1.1d — Inject cleanup access and wait boundaries.** Depends on 1.1c.
  - Files: `syncthingStatus/FolderAccessBookmarks.swift`, `syncthingStatus/Client.swift`, test support and `CleanupSafetyTests.swift`.
  - Work: give the existing bookmark store a small interface (resolve/save/refresh/clear) and inject it into the controller. Keep resolution result type shared with the production implementation. Add injected scope start/stop operations and an async reconciliation wait whose live default preserves the existing two-second behavior. Script fake grants only for disposable roots. Include missing/clear persistence checks against the real bookmark store with isolated defaults.
  - Done: tests can choose missing/resolved/stale bookmark outcomes and observe balanced successful scope starts/stops, while the real controller still decides accessibility and deletion targets. Production construction remains source-compatible. Do not treat a false scope-start return alone as denied access or repair the known root bug here.
  - Backpressure: targeted access baseline in `T(CleanupSafetyTests)`; review dependency defaults and unchanged root handoff; no permission-denied claim based on hostless filesystem permissions.

### Wave C — behavior and handoff (depends on B)

- [x] **1.1e — Exercise the production cleanup pipeline.**
  - Files: `syncthingStatusTests/CleanupSafetyTests.swift`, `syncthingStatusTests/Support/CleanupFixture.swift` (or existing shared fixture support).
  - Work: return deleted-directory entries through scripted `db/need`, await `loadCandidates()`, then select actual published IDs. Include a traversal name such as `../outside`, a valid selected candidate and an unselected sentinel. Supply an exact-root grant; script scan and subsequent need responses. Use a controlled wait to observe deletion outcome before reload.
  - Done: traversal reports failure and preserves sibling contents; exact-root success removes only the selected item; a missing grant preserves all data and presents the access gate. Assert scan/reload requests and final controller state. Tests document that OS bookmarks/security scope/HTTP/wait are substituted while controller, decoding, filtering, validation and disk mutation are real. They pass against unchanged cleanup policy.
  - Backpressure: `T(CleanupSafetyTests)`; inspect sentinel contents as well as existence. Known failing ancestor/obsolete-root scenarios remain assigned to 1.2.

- [x] **1.1f — Verify isolation, build and record readiness.** Depends on 1.1e.
  - Files: affected source/project/test diff, `docs/PLAN-task-1.1.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/TASKS.md`, `docs/PROJECT_STATE.md`, evidence under `docs/reviews/evidence/` (repository-root paths).
  - Work: review every live singleton/system-store call reachable from test construction and teardown. Confirm test target membership and lazy defaults. Run the suite three times because async startup, persistence and fixture isolation are part of this task's acceptance gate. Run B once after the final source changes; verify app sandbox entitlements. Gracefully quit all instances of this app, confirm exit, launch the exact B artifact and verify the executable path.
  - Done: record actual test names/counts, command outcomes, isolation limits, build path and launch result. Mark parent 1.1 complete only when the whole gate passes; next is 1.2. Keep A1–A3 and the cleanup release blocker open. Any source fix arising during validation requires the relevant checks again.
  - Backpressure: T ×3, B, source/target isolation inspection, runtime path verification, D. No live cleanup or daemon mutation is part of this handoff.

## Commands and evidence

Use the full B, T and D commands in [the parent plan](IMPLEMENTATION_PLAN.md#backpressure-commands) from repository root. `T(ClassName)` appends `-only-testing:syncthingStatusTests/ClassName`. For the repeat gate, run T three times sequentially; preserve each result separately. Zero tests, skips and a successful build without executed tests do not pass.

Before implementation, create a local `fix/isolated-production-tests` branch while preserving existing documentation edits. No commit, push or publication is part of this planning request. During execution, inspect overlapping changes again before editing.

The task closes with a working test foundation, not proof that cleanup is safe. Real bookmark creation/persistence, picker grants and TCC behavior require task 1.5's disposable sandbox fixtures. The existing review harnesses remain historical evidence and are not modified to stand in for production tests.

## Execution log

Planning inspected the active plan, tracker, review, source, project configuration and Xcode version. Execution then added the target, dependency boundaries and production tests. All 15 tests passed three consecutive runs; independent isolation review found no blockers. B passed with App Sandbox enabled, and the exact fresh app was launched after the installed instance exited. See [verification evidence](reviews/evidence/2026-09-05/task-1.1-isolation.md). No live cleanup or daemon configuration mutation occurred.

| Wave | State | Evidence |
|---|---|---|
| A — test bundle | Complete | T(CleanupSafetyTests): 1 test, 0 failures; source membership and hostless settings verified |
| B — isolation | Complete | Six settings tests and three client tests pass; live defaults and test boundaries independently reviewed |
| C — baseline and handoff | Complete | Six cleanup tests; full T: 15 tests ×3, zero failures; B and fresh launch verified |
