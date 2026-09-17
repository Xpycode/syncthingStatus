# syncthingStatus usability and code review — 2026-09-05

**Verdict: needs work. One confirmed cleanup data-loss risk should block the next release.** The app remains useful as a compact monitor, but its status rules and several controls do not consistently mean what their labels suggest. Fix those before expanding features or redesigning the shell.

Review scope: current application source, a fresh running Debug build, live popover/Settings/main-window inspection, accessibility inspection, isolated behavioral harnesses, and official Syncthing documentation. Three smaller supporting agents independently reviewed code, usability, and web evidence; the main reviewer verified and consolidated their findings. No application source or user preferences were edited; no live cleanup, pause/resume, or daemon configuration changes were performed.

## Project status

- v1.6.1, build 163, released August 10; current focus is v1.7 maintenance.
- Homebrew tap publication and installation documentation were completed September 5. Website Homebrew handoff remains pending in the project record.
- No active sprint. Two Homebrew checks remain deferred: full audit with supported Xcode and installation/upgrade smoke testing. Installed Xcode is 26.6; the recorded audit requirement is 27.0.
- Recorded next action: investigate refresh overruns with an offline peer.
- The checkout was clean on `main` at entry and matched its locally recorded upstream. No remote fetch was performed for this status review. The pre-clear follow-up also records the task backlog, blocker plan, session handoff, and preserved reproduction evidence.

## Ranked findings

| Priority | Finding and impact | Evidence | Smallest useful change |
|---|---|---|---|
| **Release blocker** | **Cleanup can delete from the wrong root.** A permitted parent-folder access grant becomes the deletion root. A stored bookmark also remains usable after the configured folder path changes. | `Client.swift:1886`, `1905`, `2001`, `2011`, `2079`, `2128`. Source trace plus isolated destructive fixture reproduction. | Keep the access-scope URL separate from the configured Syncthing folder root; validate their relationship again before deletion. Resolve targets relative to the current configured root. |
| **High** | **The menu bar can claim “In sync” while work remains or status is unavailable.** This contradicts the folder row and undermines the app's central promise. | `App.swift:87`, `98`, `117`; `Helpers.swift:59`, `98`; `Models.swift:103`; `Client.swift:821`. Extracted-source fixture results below. | Use one status policy for rows and icon, represent missing/invalid status explicitly, and require known status for every relevant folder before claiming success. |
| **High** | **Overlapping refreshes can cancel the current refresh and discard its replacement.** Sequential peer/folder requests can also starve later entries when one is slow. | `Client.swift:1237`, `1247`, `792`, `1193`; `App.swift:449`, `461`. Reproduced scheduler behavior with simulated cancellation unwind. | Give refresh scheduling one owner. Coalesce ordinary timer ticks; explicitly cancel and await obsolete work when connection settings change. Avoid unbounded overlapping refreshes. |
| **Important** | **Per-folder notification switches misrepresent runtime behavior.** With no selected IDs, every switch is off but notifications are enabled for all folders. Switching off the last selected folder enables all again. | Runtime `Client.swift:980`; UI `Views.swift:2068`; default `SyncthingSettings.swift:111`. Predicate comparison reproduces the mismatch. | Represent “all folders” separately from an explicit selected set; migrate the legacy empty value to “all.” Make the displayed selection truthful. |
| **Important** | **Folder pause/resume rewrites the entire daemon configuration.** Another edit between GET and POST can be overwritten; two concurrent folder actions can undo each other. | `Client.swift:1386`, `1390`, `1413`. Verified read-modify-write source path; concurrency not exercised against the user's daemon. | PATCH only `paused` on the individual folder configuration endpoint. |
| **Important** | **Connection recovery is buried below appearance settings.** The disconnected screen gives generic instructions; the actionable reason is truncated in a footer. Automatic discovery probes the sandbox home. | `Client.swift:330`; `Views.swift:188`, `223`, `1891`, `1921`, `2217`. Live Settings capture confirms the connection section is below the initial visible area. | Put Connection first. Show the actual error in full and offer the existing config-file picker directly for missing/revoked access. Use the real-home location as the picker hint; a corrected path alone does not grant sandbox access. |
| **Important** | **Cleanup only inspects the first 1,000 needed items.** Later candidates are absent from the list without an indication that results are incomplete. | `Client.swift:1317`, `1322`, `1856`; `Models.swift:187`; official pagination contract. No 1,001-item live daemon test was performed. | Fetch subsequent pages on demand until a short/empty page, deduplicate, and support cancellation. Do not rely on a `total` response field. |
| **Usability** | **The information hierarchy hides the most useful content.** The live detailed window puts an idle chart ahead of devices and folders; the popover repeats pause buttons and five footer actions. | `Views.swift:53`, `62`, `236`, `803`, `1296`; fresh screenshots below. | Put device/folder problems and status first; keep idle charts collapsed or later. Keep the complete popover list initially, but remove the redundant Update action and rename “Window” to “Details.” |
| **Usability** | **Action scope is unclear in accessibility output.** Global Pause All and individual pause buttons are all exposed as “Pause.” The cleanup selection toggle has an empty label. | Live AX inspection; `Views.swift:161`, `805`, `1299`, `1836`. Refresh does have an inferred accessible name, so it is not an unlabeled-control finding. | Supply labels such as “Pause all devices,” “Pause Pro14,” and “Select [candidate name].” Preserve visible compact controls. |
| **Maintainability** | **Production code carries substantial testing/demo machinery and duplicated request handling.** This increases the number of states a routine change must preserve. | `App.swift:852`; `Client.swift:439`, `1477`; `SyncthingStatusIcon.swift:79`, `108`. | Isolate the demo generator, put developer scenario controls behind DEBUG, remove unused animation machinery if animation is no longer planned, and consolidate transport/error handling. Preserve a simple public demo entry if that feature remains intentional. |

### Cleanup target proof

The access picker explicitly accepts an ancestor. The probe returns that bookmarked ancestor as `.granted(url)`, and deletion passes it into `validatePath`. The validator correctly confines the candidate to the supplied root, but the supplied root is wrong.

For a configured folder `Sync/Project`, grant `Sync` and select candidate `OtherFolder`:

```text
Expected: Sync/Project/OtherFolder
Actual:   Sync/OtherFolder
Fixture result: sibling removed; intended candidate preserved
```

A second fixture reproduced the corresponding old-root/new-root mismatch after a configured path change. These harnesses extract the actual path validator and model the verified access-root handoff. They do not exercise the complete sandbox/open-panel flow. Every created or deleted item was inside the harness's own temporary fixture.

Evidence: [ancestor harness](evidence/2026-09-05/AncestorRootHarness.swift), [ancestor output](evidence/2026-09-05/harness-output.txt), [stale-root harness](evidence/2026-09-05/StaleRootHarness.swift), [stale-root output](evidence/2026-09-05/stale-harness-output.txt).

Until corrected, avoid the stuck-deletion cleanup feature. Its permanent-delete confirmation should also identify the configured root and selected names; a count alone cannot help users detect a target mismatch.

### Status and refresh proof

The harness compiles the repository's `Models.swift` and extracts the unchanged resolver, pending-work helper, effective-sync helper, and refresh methods. Transport/state dependencies are stubs. Results:

```text
Pending small file: rowPending=true, icon=inSync
Pending directory: rowPending=true, summary='', icon=inSync
Malformed empty response: rowPending=false, icon=inSync
Missing folder status: icon=inSync
95 percent with four deletes: effectivelySynced=true
Two overlapping refreshes: started=1, completed=0, refreshing=false
```

The last case simulates an asynchronous request taking time to unwind after cancellation. It proves the scheduler flaw under that condition; it does not establish that an offline peer specifically causes a 30-second request. Both live peers were offline during inspection, but no deliberately delayed daemon request or request-duration instrumentation was used.

Syncthing defines the `need*` counters as work required to become up to date, including separate directory and symlink counts. That supports using item counts as well as bytes when reporting folder health. [Official folder-status contract](https://docs.syncthing.net/rest/db-status-get.html).

Evidence: [status/refresh harness](evidence/2026-09-05/status-refresh-harness.swift), [results](evidence/2026-09-05/status-refresh-results.txt), [notification predicate comparison](evidence/2026-09-05/notification-results.txt).

## Usability and simplicity assessment

The compact popover is already serviceable: names, paths, counts, status words, and speeds are readable. Keep that familiar layout while improving what it says and which controls receive emphasis. The main window should make detailed device/folder state easier to reach; in the inspected 700-point window, the idle chart dominates and folders are below the visible area.

“Connected” currently means the local API is reachable, even when configured peers are disconnected. The live app demonstrated that combination. Offline laptops are not necessarily a sync error, so do not automatically turn every such state red. A clearer summary such as “Syncthing reachable · peers offline” communicates both facts without inventing an alarm.

Keep Connection and basic notification choices readily visible. Move sync thresholds, refresh tuning, and diagnostics into an Advanced area. Defer the startup notification permission prompt until a successful connection or a deliberate notification choice (`App.swift:300`). These are proposed usability changes, not release blockers.

The main menu should expose useful app actions before developer scenarios: Web UI, Refresh, and Pause/Resume All are candidates. Current production Demo Mode includes screenshot presets and layout tests. Avoid replacing this with another large menu hierarchy.

The codebase has **12 Swift files and 6,982 physical lines** including comments and blanks. `Views.swift` has 2,280 lines and `Client.swift` 2,204; together they contain about **64%** of the Swift source. `App.swift` adds 974 lines. Size alone is not a defect; the problem is that polling, notifications, demo snapshots, and destructive cleanup share one client file, while most product UI lives in one view file.

A small decomposition is sufficient: move the already distinct cleanup controller and demo generator into their own files, separate Settings/cleanup views from monitoring views, and consolidate the six HTTP request helpers. Avoid adding a general service framework or switching UI frameworks merely to shorten files. Add focused tests around deletion roots, status resolution, refresh ownership, and notification selection before these changes.

## Web evidence and limits

- Syncthing calls `/db/status` expensive and advises sparing use. The app fetches every folder each cycle and permits a five-second interval. This is a documented performance concern, not a measured CPU regression; measure endpoint durations before adding concurrency or replacing polling with events. [Folder status](https://docs.syncthing.net/rest/db-status-get.html).
- The config API supports PATCH on an individual folder. A `paused`-only update is smaller and avoids overwriting unrelated fields. [Configuration endpoints](https://docs.syncthing.net/rest/config.html).
- `/db/need` pagination spans all three result arrays. Its documentation explicitly says `total` was removed; a fix must not depend on that field. [Needed-items endpoint](https://docs.syncthing.net/rest/db-need-get.html).
- Aggregated device completion is supported. Separate deletion/item counters still matter to the application's meaning of “synced.” [Completion endpoint](https://docs.syncthing.net/rest/db-completion-get.html).
- Apple Settings/accessibility guidance was researched, but the main review's browser returned JavaScript-only pages. No finding relies on an unverified quotation from those pages; concrete UI judgments above come from source, live screenshots, and accessibility inspection.

Two agent suggestions were intentionally excluded as unsupported: undocumented fields in an old API example do not establish that current cleanup responses are incompatible; `startAccessingSecurityScopedResource()` returning false does not alone prove a vulnerability on an already accessible path. Actual scope/root validation remains essential.

## Validation and handoff

- Fresh Debug build passed with Xcode 26.6 and cached Sparkle dependency. The only matched build warning was skipped AppIntents metadata extraction because the app has no AppIntents dependency. This was an ad-hoc development build, not a release/notarization check.
- Gracefully quit the installed instance, confirmed termination, and launched the exact fresh artifact. Review-time process inspection found only that artifact running. At pre-clear close, the temporary build was retired and the installed `/Applications/syncthingStatus.app` relaunched.
- Fresh build: [syncthingStatus.app](/private/tmp/syncthingStatus-review-build/Build/Products/Debug/syncthingStatus.app). [Build log](/private/tmp/syncthingStatus-review-build.log).
- Live screenshots: [popover](/private/tmp/syncthingStatus-review-popover.png), [Settings](/private/tmp/syncthingStatus-review-settings.png), [detailed window](/private/tmp/syncthingStatus-review-window.png).
- Inspected the live connected app with offline peers and idle folders. Did not alter preferences to simulate first launch, exercise live destructive operations, change daemon configuration, or test release update installation. Dark appearance and a full VoiceOver session remain untested.
- No automated test target was found in the Xcode project. The isolated review harnesses passed as reproductions of the defects; they are not passing regression tests for corrected code. Coverage was not measured.
- Reproduction sources and outputs are preserved in [the evidence directory](evidence/2026-09-05/README.md). Screenshots and the build remain under `/private/tmp` and may be removed by the OS. The pre-clear follow-up commits the review and handoff documents; application source remains unchanged.

Recommended next work: fix cleanup target identity first; then unify status semantics and refresh ownership; then correct notification selection and direct connection recovery. Follow with the small UI/code simplification pass. Re-run a release review after those fixes rather than treating this successful Debug build as release approval.
