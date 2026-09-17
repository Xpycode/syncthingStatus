# Tasks

> **Persistent task tracker.** Lives in `docs/`. Progress syncs to PROJECT_STATE.md.

## Backlog
<!-- Ideas and future work. Added by /interview, user input, or discovered during development. -->
<!-- Priority: top = highest, bottom = lowest -->

- [ ] [Review] Put folder/device status before idle charts, clarify API reachability versus peer availability, reduce redundant footer controls, and rename Window to Details. Clarify peer wording when byte completion is 100% but deletes remain (Wave 2 fixture displays “Syncing (100%)” with the pending-delete count).
- [ ] [Review] Clarify shared versus device-local folder totals: the compact row currently shows an unlabeled local file/byte count that can legitimately differ across Macs because of ignore rules. Prefer shared/global inventory in the compact row; retain both in Details and explain large healthy differences neutrally, without a warning or notification.
- [ ] [Review] Give global and per-item pause/selection controls explicit accessible scope; verify cleanup selection labels and focused main-menu action discoverability.
- [ ] [Review] Separate cleanup/demo and Settings/view responsibilities, consolidate HTTP helpers, and reduce developer scenario/unused animation code while preserving intentional public demo behavior.
- [ ] Re-run the full Homebrew cask audit with supported developer tools (Xcode 27.0 required on this Mac; 26.6 currently installed). See `homebrew.md` for commands and completed checks.
- [ ] Smoke-test Homebrew installation and upgrade without replacing the existing app installation; public tap/fetch, DMG checksum, signature, and notarization checks already passed.

### GitHub follow-ups — deferred until after cleanup safety

User confirmed 2026-09-05: continue the cleanup safety sprint; handle these separately afterward. They must not delay a verified cleanup safety fix.

- [ ] [GitHub #2](https://github.com/Xpycode/syncthingStatus/issues/2) — implement genuine monochrome menu-bar rendering in the UI wave; the existing setting retains colored assets. Preserve distinguishable sync/error states.
- [ ] [GitHub #6](https://github.com/Xpycode/syncthingStatus/issues/6) — complete the existing Homebrew validation follow-ups, then reply with the published custom-tap instructions and resolve the issue as appropriate. Publication/replies are separate work; no reply sent in this sprint.

## Current Sprint
<!-- Active work. Populated by /plan or /execute. Keep focused (3-7 tasks). -->
<!-- When done: /log moves to tasks-archive.md -->

- [ ] **4.1** Verify explicit All/Selected per-folder notification scope with isolated preferences and relaunch. Implementation plus automated migration, delivery and authorization-concurrency cases pass in `5633ec3` + `f7bc4dc`.
- [ ] **4.3** Verify fail-closed cleanup pagination through the live UI. Automated suites and production-controller success/failure/malformed/cancellation checks pass against a controlled responder; the cleanup-window UI gate remains.
- [ ] **4.4–4.5** Verify isolated picker/error/TCC recovery and combined A6–A9 flows. Typed recovery and concurrency tests, the full 114-test suite, independent review and Debug build pass.

Wave 4 is partially accepted: 4.2/A7 passed with a disposable daemon. The unique-bundle fixture now passes clean recovery, picker cancel/regrant, loopback connection and Connection-first Settings. Notification-scope relaunch, cleanup-window pagination/retry/cancel and TCC denied/granted/combined UI cases remain; no additional task is checked. This is not release approval.

## Inbox

- [ ] Specific offline-peer 30-second resource-timeout hypothesis remains unconfirmed. On 2026-09-06, a read-only probe measured a 16.7808 s completion success (overrun reproduced), while the fresh app logged a failure at its 10 s request timeout. Do not equate these with a proven 30 s timeout. [Measurements](reviews/evidence/2026-09-06/refresh.md).
- [ ] Verify disconnected-popover sizing with clean preferences and no config grant. Only the connected branch emits content height; source inspection suggests a first-run sizing risk, but it was not live-tested.

---

## Progress Calculation

```
Sprint Progress = checked in Current Sprint / total in Current Sprint
Overall Progress = (archived count + checked) / (backlog + current + archived)
```

Archived task count is read from `tasks-archive.md` header.

## Workflow Integration

| Command | Action |
|---------|--------|
| `/interview` | Adds tasks to Backlog |
| `/plan` | Moves Backlog → Current Sprint |
| `/execute` | Checks off tasks as waves complete |
| `/log` | Archives checked tasks, updates PROJECT_STATE.md progress bar |
| `/status` | Reports progress from checkbox counts |

---
*Location: `docs/TASKS.md`. Parsed by Directions app.*
