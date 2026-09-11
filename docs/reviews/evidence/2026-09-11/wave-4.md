# Wave 4 implementation and acceptance evidence

Date: 2026-09-11  
Scope: tasks 4.1–4.5 / acceptance criteria A6–A9  
Implementation commits: `5633ec3`, `f7bc4dc`

## Implemented

- Explicit per-folder notification scope (`All` / `Selected`) with legacy migration, deduplicated persistence, selected-none semantics, and a separate global “All Synced” path.
- Targeted `PATCH /rest/config/folders/{id}` pause/resume with a `paused`-only body, per-folder serialization, connection-identity isolation, confirmed-success publication, and same-connection failure retention.
- Strict `db/need` pagination across all buckets with metadata validation, private accumulation, duplicate/conflict handling, cancellation/identity invalidation, and terminal-generation actionability.
- Typed connection recovery, one shared real-home-aware config picker, complete selectable error text, Connection-first Settings ordering, and deferred notification authorization with visible denied-state recovery.

## Review corrections

An independent reviewer found authorization reentrancy, denied-permission recovery, pause error lifetime, and connection-transition gaps in the original checkpoint. Commit `f7bc4dc` now:

- serializes only eligible notification requests without dropping explicit intent behind an ineligible status lookup;
- refreshes denied/authorized state at launch and app activation and provides an AppKit System Settings action;
- binds pause intents, success, errors, and queued opposite actions to the connection revision, preparing current credentials before a new intent;
- retains a pause failure across refreshes on the same daemon but clears it on connection change;
- expands strict pagination coverage for full non-candidate pages and malformed metadata.

The final independent blocker-only review found no remaining correctness blockers. `git diff --check` passed.

## Automated evidence

The final hostless production suite passed:

```text
Executed 114 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

Command:

```sh
xcodebuild test -project 01_Project/syncthingStatus.xcodeproj \
  -scheme syncthingStatusTests -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/syncthingStatus-wave4-final-tests-5 \
  CODE_SIGNING_ALLOWED=NO
```

The additions cover concurrent authorization, denied-to-authorized refresh, pause failure and queued-intent isolation across connection changes, later successful refreshes, full non-candidate pages, and missing/mismatched pagination metadata.

## Disposable live fixtures

The final production sources were compiled into narrow command-line harnesses under `/private/tmp/wave4-daemon-fixture-agent`; dependencies used isolated defaults, in-memory credentials, fake login-item state, ephemeral URL sessions, and captured notifications.

Against bundled Syncthing v2.1.2 with a disposable home, loopback GUI/API, loopback sync listener, and discovery/relay/NAT/telemetry/upgrades disabled, the pause harness reported:

```text
pause=passed;notifications=1
resume=passed;unrelatedPaused=true;notifications=2
```

The proxy recorded only targeted folder PATCHes with `{"paused":true}` then `{"paused":false}`; the unrelated paused sentinel remained paused. This closes task 4.2 and A7. The deterministic opposite-intent and connection-transition sequences remain covered by production-code tests because the current UI cannot issue an opposite action while it still renders the old state.

Against the controlled loopback `db/need` responder, the production cleanup controller reported:

```text
success=passed;actionable=true;candidates=1001
failure=passed;actionable=false;candidates=0;error=Syncthing returned HTTP 503 for db/need.
failure=passed;actionable=false;candidates=0;error=The data couldn’t be read because it is missing.
cancel=passed;actionable=false;candidates=0
```

All fixture listeners on ports 28384–28386 were stopped and teardown was verified. No real Syncthing configuration, folder state, credentials, defaults, bookmarks, login item, or notification authorization was changed by the fixtures.

## Build and app handoff

The final ad-hoc Debug build succeeded at:

```text
/private/tmp/syncthingStatus-v17-build/Build/Products/Debug/syncthingStatus.app
```

The prior instance was gracefully quit, and the exact fresh executable was launched and verified as PID 27785.

## Remaining acceptance gate

Wave 4 is partially accepted: 4.2/A7 pass. Tasks 4.1, 4.3–4.5 and A6/A8/A9 remain unchecked because their plan explicitly requires live UI/TCC coverage.

The production app cannot safely provide a whole-app isolated matrix in the current login: startup hardwires standard defaults, a fixed Keychain service, real bookmark/login-item state, the production bundle's notification identity, and a live client. A different bundle ID alone does not isolate the fixed Keychain service. Remaining cases therefore require a unique-bundle component fixture with injected stores/services or a disposable macOS account/VM:

- All / one / selected-none notification UI and relaunch persistence;
- config picker cancel/regrant, bad config/key/URL, loopback HTTPS, denied-to-granted TCC UI recovery;
- cleanup-window pagination, retry/reload/cancellation presentation;
- combined reconnect/cleanup/notification/action flows.

The controlled production-controller pagination checks are strong integration evidence, but they are not claimed as the required live cleanup-window UI gate.

## Unique-bundle UI fixture checkpoint

Execution resumed with an isolated acceptance app rather than the production identity. `tools/build-wave4-acceptance-fixture.sh` compiles the production app under `WAVE4_ACCEPTANCE_FIXTURE` as `com.lucesumbrarum.syncthingStatus.wave4fixture`, with its own defaults and fixture credential store, fake launch-at-login state and Sparkle startup disabled. `tools/wave4-fixture-server.py` supplies a disposable loopback Syncthing API/config/root, including later-page failure, malformed-page and slow-page scenarios. `tools/wave4-ax.swift` provides narrow accessibility dump/action support.

The fixture built ad-hoc with App Sandbox, user-selected read/write and network-client entitlements. Starting from a nonexistent fixture defaults domain, live accessibility inspection confirmed:

- the full missing-config error and typed “Select Syncthing config.xml…” recovery action;
- production `NSOpenPanel` presentation with the real-home hint;
- cancellation returned to the error state with the recovery action still available;
- selecting only `/private/tmp/syncthingStatus-wave4-ui-live/config.xml` connected the app to `127.0.0.1:28484`;
- the fixture folder and Resolve alert appeared; and
- Settings opened with Connection first, the selected fixture path and notification controls.

The user stopped execution before notification disclosure/scope interaction could be completed. All/one/selected-none relaunch persistence, cleanup-window pagination/retry/cancel presentation, notification TCC denied/granted recovery and combined flows remain open. Tasks 4.1, 4.3–4.5 and A6/A8/A9 therefore remain unchecked. The fixture app and responder were stopped.

Checkpoint validation passed: 114/114 hostless tests, a normal non-fixture unsigned Debug compile, the isolated fixture build/signing/entitlement checks, shell/Python/Swift tool checks and `git diff --check`. The live fixture used only its unique defaults/credential identity and disposable loopback files; production preferences, Keychain credentials, bookmarks and daemon state were not changed.
