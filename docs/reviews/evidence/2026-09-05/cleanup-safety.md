# Cleanup safety sprint — tasks 1.2–1.5

Date: 2026-09-05. User authorized continuing the cleanup safety sprint and explicitly deferred GitHub issues #2, #5 and #6. No later implementation wave, live cleanup or release was performed.

## Result

**Tasks 1.2–1.5 are complete; cleanup acceptance criteria A1–A3 passed.** Independent source review passed after fixing its two findings. The production Debug app builds with App Sandbox enabled, passes strict signature verification, and has been launched from the exact fresh artifact. The final real sandbox and production-window checks passed with production-equivalent filesystem entitlements.

## Reproductions and automated checks

- Task 1.2 RED: 19 cleanup tests executed, eight methods failed with 37 assertions. Disposable sentinels demonstrated wrong-sibling deletion under an ancestor grant, obsolete bookmark deletion, prefix collision, stale windows and changed/removed/reused folder/connection identity. All original cleanup tests passed.
- Independent review exposed a further confirmation defect: replacing the shared access bookmark after preparing confirmation still allowed deletion. Two new regressions failed before repair, with eight assertions. Both exact-to-ancestor and same-scope replacement are now rejected before preflight/mutation.
- Final full suite: **49 tests passed, zero failures**, including 40 cleanup tests and the original settings/client isolation tests. All original 15 foundation tests still execute.
- Coverage includes current daemon/folder responses, missing/unavailable/mismatched configuration, path aliases, invalid relative paths, symlink escapes, already-gone targets, root replacement, explicit confirmation/selection drift, access-token replacement between items, legitimate stale-bookmark refresh, cancellation/connection changes during gated HTTP, window cancellation, failed selections/retry, partial outcomes, failed rescan, encoded folder IDs and cache bypass on safety preflights.
- HTTP, credentials, defaults and OS scope boundaries are injected in hostless tests. Production probes, path validation and removal operate on real files under unique disposable fixture directories. No live daemon request or user folder mutation is permitted by those tests.

[Preserved test/build/launch summaries](cleanup-safety-results.txt) include test names and results. Full Xcode logs and result bundles remain under `/private/tmp` and are ephemeral.

## Implementation and review

Access context now carries separate `scopeURL` and `configuredRoot` values. A parent grant authorizes access but never becomes the deletion root. The controller captures the configured filesystem identity, daemon identity and immediate connection revision. Before every item it fetches current daemon status and the individual folder configuration with cache bypass, checking identity before/after suspension. Missing or mismatched configuration fails closed. Detached removal rechecks the pinned root, candidate containment and cancellation permit immediately before removal.

Confirmation captures the canonical root, selected names, selection revision and opaque persisted bookmark token. A changed selection, reload, window/connection identity or replaced grant invalidates the old review. The controller's own stale-bookmark refresh is distinguished from subsequent external grant changes. Native window close explicitly cancels pending authorization. The native confirmation sheet shows the full root, scrollable selected names and permanent-delete consequences, defaults to Cancel, and disables deletion when the captured review is invalidated. Failed selections remain available; rescan failures remain visible. Access recovery is disabled while mutation/reconciliation is active.

Independent source review found and then verified fixes for:

1. Access replacement after confirmation was prepared (new RED→GREEN regressions above).
2. Grant Access/Try Again remaining interactive while an active deletion would discard the grant (controls now disabled).

The follow-up independent review reported **no remaining blocking findings** and checked the then-current 48-test result; the final added root-replacement regression brought the passing suite to 49. It did not rerun the suite. Actual sandbox and UI observations are recorded separately below.

## Sandbox and native UI checks

A separately signed fixture application uses production controller, bookmark store and native confirmation code with intercepted HTTP and isolated preferences/credentials. The production cleanup window/view types are extracted verbatim for UI verification. Its bundle identifier differs from the real app; no real app defaults or Syncthing data are used.

Final observations passed: exact and ancestor picker grants, fresh-process persisted bookmark deletion, cleared grant after relaunch, filesystem-permission denial, changed configuration while a window/confirmation is open, parent/other-root sentinel preservation, Cancel, stale confirmation disabling Delete, long scrollable selection review, Select/Deselect All, empty selection disabled, failed preflight with retained selection/retry, partial failure with retained selection and successful rescan/reload.

The initial exploratory harness additionally had the app-scope bookmark entitlement. The final rerun removed that extra entitlement and passed all controller, dialog, permission/obsolete-scope and production-window matrices. A final full UI chain also passed: blocked access gate → actual production Grant Access picker with ancestor selection → Select All → confirmation → contained deletion → rescan/reload → Close. Source hashes matched the current implementation. The harness bookmark was cleared afterward.

[Preserved sandbox sources, results and scope](cleanup-sandbox/README.md) include all five final result files and production-source hashes. The hostless root-replacement regression additionally confirms that moving/replacing the root after confirmation preserves both old/new roots without any new HTTP request or scope activation.

## Limits

Filesystem/path validation and removal are not atomic. Concurrent external mutation after the final check remains a race boundary; cancellation cannot undo or interrupt a recursive removal already started. The fix addresses demonstrated configured-root/identity confusion and fails closed on changes observed across its boundaries; it does not claim protection against every adversarial concurrent filesystem writer.

Clearing a persisted bookmark and denying POSIX filesystem permissions are tested separately. They are not a claim that the harness revoked a macOS TCC decision. Bookmarks are capabilities, not permanent assertions about a path's inode across fresh sessions; a fresh window/review pins the currently configured filesystem object.

This sprint does not address the already tracked status, refresh, pagination or UI backlog and is not whole-release approval. Run `/check ship` before a separately requested release.

## Build and handoff

Debug build used the plan's B command with ad-hoc signing. Strict code-signature verification passed and the built app's App Sandbox entitlement is true. No Release/notarization claim is made. Xcode needed approved access outside the tool filesystem sandbox for its cache/test services. The app build's only matched warning was skipped AppIntents metadata extraction.

The old `/Applications/syncthingStatus.app` process quit gracefully and its exit was confirmed. Exactly one running instance was then verified at:

`/private/tmp/syncthingStatus-v17-build/Build/Products/Debug/syncthingStatus.app`

The `/tmp` and `/private/tmp` aliases were canonicalized for the executable-path comparison. This is the final runnable app, not the sandbox fixture harness or XCTest runner.

## API references

The safety preflight uses the official [individual folder configuration endpoint](https://docs.syncthing.net/rest/config.html) and [system status daemon identity](https://docs.syncthing.net/rest/system-status-get.html), checked 2026-09-05. These GET requests do not mutate daemon configuration.

## Deferred GitHub work

User decision, 2026-09-05: handle these after the cleanup safety sprint; no issue reply or closure was sent here. Explicit tasks remain in `docs/TASKS.md`.

- [#2 — genuine monochrome icons](https://github.com/Xpycode/syncthingStatus/issues/2): implement proper monochrome rendering with recognizable status states in later UI work.
- [#5 — long-path layout](https://github.com/Xpycode/syncthingStatus/issues/5): reproduce the screenshot and explicitly verify the fix in later UI work.
- [#6 — Homebrew installation](https://github.com/Xpycode/syncthingStatus/issues/6): support is published; complete existing validation follow-ups and respond with custom-tap instructions in separately requested work.
