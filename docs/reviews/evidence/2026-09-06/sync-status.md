# Wave 2 — truthful sync status

Scope: plan tasks 2.1–2.3 / A4. User authorized the next planned phase on 2026-09-06.

## Decision table

| Subject / observation | Meaning |
|---|---|
| Paused folder | Paused, regardless of its last counters |
| Missing, malformed, failed folder observation, or unknown state | Status unavailable |
| Folder error | Folder error |
| Scanning, syncing, scan/sync waiting/preparing, cleaning/waiting | Named active state; never complete |
| Idle folder with any bytes/files/directories/symlinks/deletes/aggregate items pending | Out of sync |
| Idle folder with validated zero pending counters | Up to date |
| Paused peer | Paused |
| Peer connection explicitly disconnected | Offline; API reachability remains separate |
| Peer connection or completion missing/failed | Status unavailable |
| Connected peer below 100%, or with any bytes/items/deletes pending | Pending |
| Connected peer at 100% with validated zero pending counters | Up to date |
| Missing/failed configuration | Configuration unavailable |
| Empty configured folder list | No folders |
| All configured folders and peers known complete | In sync; completion notifications may proceed |

Threshold preferences no longer erase actual pending work. This intentionally removes approximate
"complete" semantics from rows, icons and notifications, including bytes below the configured threshold.
Legacy preference values remain stored for compatibility. Their Settings sliders are replaced in the
same section by a read-only explanation of known completion. Startup also shows Connecting rather than
an unverified In sync tooltip.

The folder decoder requires the state, existing file/byte metrics, and individual pending counters.
The aggregate is optional for compatibility; absence uses the individual sum. Wrong types, negatives,
missing required fields and overflow fail decoding. Unknown extra fields are tolerated. Aggregate and
individual counts are never added together for display; contradictory nonnegative counts remain pending.
Peer decoding requires completion, globalBytes, needBytes, needItems and needDeletes.

Failed snapshots are **discarded**, including their real-folder cache, rather than retaining stale
numeric values. Absence has an explicit unavailable meaning on every status surface. This avoids an
extra freshness wrapper solely to display stale numbers. Cancellation also invalidates the affected
observation. The next successful response restores known status. Configuration failures keep the list
for recovery but mark its status unavailable. Configuration changes invalidate changed folder identities. Successful status responses following a
failed configuration are not published until configuration is known again.

A folder failure clears its pending-to-complete history, so recovery to an idle snapshot cannot invent
a completion event. Paused/error/unknown states likewise do not complete. Global notification delivery
checks the same resolver, requires the refresh to finish, and excludes demo mode. The app uses a tested
transition gate: both active and idle pending work arm completion; unavailable, paused, error, offline
and empty-folder states reset the history. Network activity only
arms the app's notification latch if actual pending sync work was observed.

## API contract

Checked 2026-09-06 against official Syncthing documentation:

- [Folder status](https://docs.syncthing.net/rest/db-status-get.html): individual `need*` fields include
  directories and symlinks, and represent work needed to become up to date.
- [Device completion](https://docs.syncthing.net/rest/db-completion-get.html): percentage is accompanied
  by `needBytes`, `needItems`, and `needDeletes`; remoteState is meaningless for aggregate requests.

## Regression evidence

- Original extracted production resolver/decoders/helpers: 4 tests failed with 15 assertions, covering
  pending small bytes/files/directories/symlinks/aggregate items, missing status, malformed status and
  four pending peer deletes. `status-policy-red.txt` records the executed failures.
- Corrected controller fixtures run through initial refresh to prepare synthetic credentials, then
  scripted config/status endpoints. A temporary copy restored the original production
  `fetchDeviceCompletions`, `trackSyncEvent` and `handleGlobalSyncComplete` methods: stale peer completion,
  unknown global completion and idle-with-four-deletes completion regressions failed.
  `status-publication-red.txt` and `status-notification-red.txt` preserve the meaningful failures.
- An initial publication test draft did not prepare the client's internal credentials. Its unconsumed
  fixture requests were caught by teardown; that run is not counted as regression evidence. The corrected
  fixtures assert configured folders and seeded status before testing failures.

Automated suite: **70 tests passed**, including 21 status tests and all 49 previous tests.
Sandboxed Debug build passed and the exact fresh executable was launched after graceful termination
of the old app. Independent Sol review approved tasks 2.1–2.3/A4 after its findings were fixed.
Native sandbox checks verify compact/detailed rows, the Settings section and icon-state mapping;
see [native evidence](status-ui/README.md). Compact/detailed AX trees had 82/72 nodes. Icon validation
checks the exact resolver-to-asset-state mapping; it does not capture final menu-bar PNG pixels.
Final build/launch evidence: [status-build.txt](status-build.txt). All previous instances exited and
PID 5280 was verified at the resolved fresh executable path; App Sandbox remains enabled.

## Independent review repairs

- Extracted the actual global notification transition gate from AppDelegate. Regression tests first
  reproduced missing idle-pending completion and completion across unavailable/paused intervals.
- Configuration failure now clears folder completion history and cached numeric status; responses
  from later status endpoints in the same failed-config refresh cannot republish known completion.
- Split unavailable icon state from soft warnings. Both modes render unavailable as WARN; explicit
  pause/offline/no-folder states retain their existing neutral-vs-traffic-light choice and tooltip.
  Genuine monochrome rendering remains the deferred GitHub #2 work.
- Unknown stuck-delete counts are hidden. The internal latch remains unresolved rather than logging
  a false "cleared" result from an unsuccessful observation.
- Added `starting` from [upstream folder states](https://github.com/syncthing/syncthing/blob/main/lib/model/folderstate.go).
- Review regressions failed with six assertions before repair; the failed-config continuation case
  failed with two assertions. `status-review-red.txt` and `status-config-publication-red.txt` preserve them.

## Limits

This gate does not repair refresh ownership, old-generation publication or slow-peer starvation (Wave 3).
It does not alter daemon configuration, cleanup authorization, notification folder selection (Wave 4),
release metadata, or publish a release. Hostless tests intercept HTTP and capture notifications and use
isolated defaults, in-memory credentials and fake login state. Native UI evidence is recorded separately.
