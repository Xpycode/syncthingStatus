# Tasks

> **Persistent task tracker.** Lives in `docs/`. Progress syncs to PROJECT_STATE.md.

## Backlog
<!-- Ideas and future work. Added by /interview, user input, or discovered during development. -->
<!-- Priority: top = highest, bottom = lowest -->

- [ ] [Review: high] Unify icon/row sync semantics and represent missing or malformed folder status explicitly; account for pending items/deletes. See `reviews/2026-09-05-usability-code-review.md` and preserved status fixtures.
- [ ] [Review: high] Give refresh scheduling one owner; prevent cancellation from discarding the replacement refresh and protect later peers/folders from slow requests. Keep the specific offline-peer timeout cause in Inbox until measured.
- [ ] [Review] Correct per-folder notification selection: an empty stored array currently enables all notifications while displaying every switch as off; model all versus selected folders explicitly.
- [ ] [Review] Change folder pause/resume to a targeted config PATCH so concurrent configuration edits are not overwritten by whole-config POST.
- [ ] [Review] Put Connection first and show actionable, untruncated recovery with the existing config picker; defer notification permission until connection/intent. Consider Advanced grouping for tuning and diagnostics.
- [ ] [Review] Page cleanup's db/need results beyond 1,000 items, deduplicate, and support cancellation; do not depend on the removed total field.
- [ ] [Review] Put folder/device status before idle charts, clarify API reachability versus peer availability, reduce redundant footer controls, and rename Window to Details.
- [ ] [Review] Give global and per-item pause/selection controls explicit accessible scope; verify cleanup selection labels and focused main-menu action discoverability.
- [ ] [Review] Separate cleanup/demo and Settings/view responsibilities, consolidate HTTP helpers, and reduce developer scenario/unused animation code while preserving intentional public demo behavior.
- [ ] Re-run the full Homebrew cask audit with supported developer tools (Xcode 27.0 required on this Mac; 26.6 currently installed). See `homebrew.md` for commands and completed checks.
- [ ] Smoke-test Homebrew installation and upgrade without replacing the existing app installation; public tap/fetch, DMG checksum, signature, and notarization checks already passed.

## Current Sprint
<!-- Active work. Populated by /plan or /execute. Keep focused (3-7 tasks). -->
<!-- When done: /log moves to tasks-archive.md -->

- [ ] [Release blocker; next session] Fix ancestor/obsolete-bookmark deletion-root confusion and add tests against actual production target resolution. Scope and acceptance checks: [active plan](IMPLEMENTATION_PLAN.md). Do not execute fixes in the review/log session.

## Inbox

- [ ] Reproduce and time the suspected offline-peer db/completion overrun. The review proved cancellation scheduling with stubbed delay, not the specific peer/30-second-timeout cause. Measure request cost before changing polling cadence or concurrency.
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
