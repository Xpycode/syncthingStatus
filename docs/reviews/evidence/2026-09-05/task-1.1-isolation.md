# Task 1.1 — production test foundation verified

Verified 2026-09-05 with Xcode 26.6 (17F113). Task 1.1 is complete. Cleanup root/identity defects remain open for tasks 1.2–1.5; this is not release approval.

## Results

| Gate | Observed result |
|---|---|
| Initial hostless target | One production-validator baseline executed, zero failures. |
| Settings isolation | Six targeted tests passed after adding the dependency/readiness/persistence APIs. The initial expected RED compilation identified the missing credential interface. |
| Integrated suite, run 1 | 15 tests, zero failures; all named tests executed. |
| Integrated suite, run 2 | 15 tests, zero failures. |
| Integrated suite, run 3 | 15 tests, zero failures. |
| Independent review | Read-only reviewer found no blocking production behavior or isolation issue. |
| Runnable app build | Debug build succeeded; strict code-signature verification passed. App Sandbox entitlement remains true. |
| Fresh launch | Installed instance quit gracefully and exited. Fresh build launched; exactly one matching application instance was verified at the new executable path. |

The [preserved results](task-1.1-results.txt) contain test names, counts, result-bundle paths and launch output. Full build/test logs and xcresults remain under `/private/tmp` and may be removed by the OS.

## What the tests execute

The test bundle compiles these original production files directly: `Client.swift`, `Models.swift`, `Constants.swift`, `Helpers.swift`, `SyncthingSettings.swift`, `FolderAccessBookmarks.swift`, and `LaunchAtLoginHelper.swift`. Its synchronized test folder adds test sources automatically. App target membership remains unchanged. `App.swift`, `Views.swift`, UI/icon/update sources, app resources and Sparkle are excluded from the test target.

The target dependency graph contains only the test target. Effective settings use the distinct `com.lucesumbrarum.syncthingStatus.tests` bundle identifier, generated Info.plist, empty host/loader, no app entitlements and `ENABLE_APP_SANDBOX=NO`. The app executable is not a test host. This runner does not verify real sandbox or TCC enforcement.

Production cleanup tests bootstrap folder configuration through the actual client, load and decode needed-item responses, filter candidate directories, select published IDs and call `performDeletion(selected:)`. The production access probe, path validator, detached filesystem removal, scan request and candidate reload all execute. Assertions cover traversal rejection with sibling contents preserved, exact-root deletion of only the selected item, missing access, stale bookmark refresh, and balanced successful scope starts/stops. A false scope-start result is not treated as denial for an otherwise readable fixture root.

## Substituted effects and lifecycle

- Each settings fixture owns a unique defaults suite. Legacy migration receives nil or a separate disposable suite; opaque bookmark data used by persistence tests is never resolved as an OS grant.
- Credential operations use a lock-protected in-memory store. Login-item read/write operations use fake state. Live defaults still invoke the existing Keychain and login-item implementations.
- Tests await the real background credential read and main-thread publication before constructing clients. Persistence flushing cancels pending debounce work, invokes the existing persistence functions, drains the serial credential queue, and handles work queued during suspension before returning.
- Each ephemeral session has a unique synthetic host and a synchronized response script. Its custom URLProtocol intercepts HTTP(S), consumes scripted replies and fails unexpected requests locally. Teardown checks unexpected and unconsumed requests. Sessions have no shared cache, cookie store or credential storage.
- All five production notification delivery sites use the injected submission boundary. Tests capture requests and invoke completion; the live default obtains `UNUserNotificationCenter.current()` only when delivering.
- Cleanup bookmark resolution and security-scope operations are substituted. Real filesystem probes and removal stay inside a unique temporary fixture root. A controllable async gate replaces only the two-second reconciliation wait.
- Tests join deletion tasks and await client operations before teardown. Client subscriptions are released before settings persistence is drained, session state is invalidated, routing is unregistered, and fixture directories/suites are removed.

Independent review confirmed these boundaries and the unchanged defective root handoff. It suggested an optional concurrent two-HTTP-fixture routing test; source inspection found the registry synchronized, and that extra test was not required to close this task. No broad scheduler or cleanup-policy changes were made.

## Commands and runtime handoff

B and T were run as recorded in the [active plan](../../../IMPLEMENTATION_PLAN.md#backpressure-commands), with local ad-hoc signing. Xcode needed execution outside the Codex filesystem sandbox for its cache/test services; the initial restricted attempt stopped before compilation. No test or assertion was skipped to work around this. The only matched build warning was skipped AppIntents metadata extraction because there is no AppIntents dependency. Debug ad-hoc signing disables hardened runtime; this is not a distribution build.

Logs:

- `/private/tmp/syncthingStatus-1.1a-test.log`
- `/private/tmp/syncthingStatus-1.1a-build-settings.json`
- `/private/tmp/syncthingStatus-settings-red.log`
- `/private/tmp/syncthingStatus-settings-green.log`
- `/private/tmp/syncthingStatus-1.1-integration.log`
- `/private/tmp/syncthingStatus-1.1-repeat-2.log`
- `/private/tmp/syncthingStatus-1.1-repeat-3.log`
- `/private/tmp/syncthingStatus-1.1-build.log`
- `/private/tmp/syncthingStatus-1.1-launch.log`

Fresh app: `/private/tmp/syncthingStatus-v17-build/Build/Products/Debug/syncthingStatus.app`. The launch check canonicalized `/private/tmp` and `/tmp` aliases before comparing executable paths. The app remains running for user testing.

No live cleanup, daemon configuration mutation, update publication, notarization, picker/TCC test or UI redesign was performed. Tasks 1.2–1.5 must still reproduce and repair root identity and verify the real sandbox flow before the cleanup blocker can be cleared.
