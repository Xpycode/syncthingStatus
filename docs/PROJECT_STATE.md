# Project State

## Identity
- **Project:** syncthingStatus — macOS menu bar app showing Syncthing's sync state.
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`
- **Stack:** Swift / SwiftUI, Combine, Syncthing REST API v2, Sparkle 2.8.1.
- **Minimum macOS:** 15.5; release supports Intel and Apple Silicon.

## Now
- **Phase:** v1.7 implementation. Current public release remains v1.6.1 (build 163).
<!-- Phase changed: 2026-09-06 -->
- **Focus:** finish Wave 4's isolated notification, cleanup-window, picker and TCC UI acceptance without touching production user state.
- **Execution:** Wave 4 is [partially accepted](reviews/evidence/2026-09-11/wave-4.md): 4.2/A7 passed; 4.1, 4.3–4.5 and A6/A8/A9 await isolated UI/TCC acceptance. Commits `5633ec3` + `f7bc4dc`, 114 tests, independent review, Debug build/launch, disposable daemon and controlled responder pass.
- **Blockers:** production startup shares fixed defaults, Keychain and TCC identities, so the remaining whole-app matrix needs a unique injected fixture or disposable macOS account/VM. Full Homebrew audit still awaits supported Xcode tools.
- **Next:** build/run the unique-bundle injected UI fixture (or use a disposable account/VM) for the remaining cases in [Wave 4 evidence](reviews/evidence/2026-09-11/wave-4.md).
- **Updated:** 2026-09-11.

## Recent
- **2026-09-11:** partially accepted Wave 4: 4.2/A7 passed with a disposable daemon; 114 tests, controlled pagination, independent review and a fresh Debug launch pass, while isolated UI/TCC cases remain.
- **2026-09-11:** closed Wave 3 after a fresh build, another clean 85-test run, independent review and 25 stable About/version samples across live refreshes; also explained healthy device-local file-count differences, recorded a UI clarification, and tightened Wave 4 after readiness review. The unchanged 85-test baseline passed again before Wave 4 execution.
- **2026-09-06:** implemented refresh ownership and bounded workers; 85 tests ×3 and independent review passed. Fresh sandboxed app launched; three Refresh clicks and About version checked. Stopped during repeated About observation; changes remain uncommitted.
- **2026-09-06:** completed truthful sync status (2.1–2.3/A4): 70 tests, independent review and native row/Settings checks and icon mapping passed; final sandboxed Debug app built and launched. Pending/unknown status cannot emit completion, and failed configuration invalidates cached metrics/history.
- **2026-09-06:** wrapped cleanup safety: 49 tests, independent review and real sandbox/UI checks passed; five tasks archived, fresh Debug app handed off, GitHub issues recorded for later.

## Backlog
- **Review queue:** eight archived tasks, three active Wave 4 acceptance tasks, nine deferred backlog items and two Inbox observations are tracked in [Tasks](TASKS.md). Overall progress: 8/20 (40%).
- **v1.7 priority:** Wave 4 implementation is complete but its live gate remains. Offline-peer overrun was measured at 16.7808 s; the separate 30 s resource-timeout hypothesis remains unconfirmed. Timer/manual refreshes now coalesce and slow entries use bounded workers.
- **GitHub issues:** #2 genuine monochrome icons, #5 long-path layout reproduction/fix and #6 Homebrew response are explicitly deferred until after cleanup safety; linked tasks are recorded in `TASKS.md` (user decision 2026-09-05).
- **v1.7 polish:** Feedback / Donate / Help, window frame autosave, CHANGELOG, split the large Views and Client files, refresh About credits on reconnect.
- **Remote HTTPS:** consider opt-in certificate pinning if more NAS / remote-host reports arrive; self-signed certificate auto-trust is restricted to loopback.
- **User follow-up:** reply to the HTTPS reporter with v1.6.1 and the one-time manual-download instruction.
- **Signing-key housekeeping:** label the Group B Sparkle entry in Strongbox; optional named Keychain import. Custody details remain in the historical snapshot.
- **Cookbook candidates:** real-home tilde expansion with `stat(2)` / errno probing; `SMAppService.mainApp` for Launch at Login.
- **Optional user cleanup:** revoke the obsolete Full Disk Access grant for this app; retain the daemon's grant.
- **Website handoff:** add the Homebrew option to the app page; instructions left in `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com/docs/HANDOFF-syncthingstatus-homebrew.md` and linked from that project's task list. Website edit/deploy pending.

## Infrastructure
- **Release:** GitHub `Xpycode/syncthingStatus`; v1.6.1 DMG notarized and stapled. Appcast and website were verified live at release.
- **Homebrew:** `Casks/syncthingstatus.rb` is live in this repository's custom tap; fresh public tap and fetch verified 2026-09-05. Install commands and validation limits: [Homebrew distribution](homebrew.md).
- **Upgrade caveat:** versions ≤1.6.0 cannot install their own updates; users need one manual DMG installation. Sparkle installation was verified end-to-end from v1.6.1.
- **Live feed:** root `appcast.xml` on `main` is production. Publish the DMG before exposing an appcast item; keep drafts outside the live feed.
- **Filesystem access:** App Sandbox stays enabled; security-scoped bookmarks keyed `FolderAccessBookmark.<folderID>` replace Full Disk Access.
- **Diagnostics:** OSLog subsystem `com.lucesumbrarum.syncthingStatus`, exported through `OSLogStore`.
- **Cross-Mac:** Syncthing's ProPro folder ignores `.git` and `.stversions`; GitHub carries Git history. On 2026-09-05 all apparent local edits matched upstream exactly; local history was aligned without changing working files.
- **Release tools:** `tools/notarize.sh`, `tools/make-dmg.sh`; debug install: `tools/install-debug-build.sh`.

## Detail (read only if needed)
- [Decisions](decisions.md) — durable choices, including summaries preserved during migration.
- [Sessions](sessions/_index.md) — complete work and validation history.
- [Tasks](TASKS.md) — completed cleanup sprint, review follow-ups, deferred GitHub issues, Homebrew checks, and reproduction inbox.
- [Active review-fix plan](IMPLEMENTATION_PLAN.md) — 27 tasks across seven waves; scope, acceptance criteria, dependencies and production/manual verification gates.
- [App and code review](reviews/2026-09-05-usability-code-review.md) — ranked findings and preserved reproduction evidence.
- [Stuck-delete implementation plan](IMPLEMENTATION-PLAN-stuck-deletes.md) and [feature design](FEATURE-stuck-deletes-cleanup.md).
- [Pre-migration state](archive/project-state-2026-08-10.md) — historical phase tables, verification details, resolved incidents, and signing-key housekeeping references; contains superseded status.
- [Homebrew distribution](homebrew.md) — cask validation, publication, and release maintenance.

## Resume
- Execution incomplete: Waves 1–3/A1–A5 and Wave 4 task 4.2/A7 passed. Tasks 4.1, 4.3–4.5 and A6/A8/A9 remain unchecked for their isolated live UI/TCC matrix.
- Next pickup: build/run a unique-bundle injected component fixture, or use a disposable macOS account/VM, for notification relaunch, picker/TCC, cleanup-window and combined reconnect cases in [Wave 4 evidence](reviews/evidence/2026-09-11/wave-4.md).
- Git: `fix/isolated-production-tests`; five local commits ahead of its remote after the Wave 4 source and documentation checkpoints. Push, merge and release remain unauthorized.
- Tasks: eight archived, three active acceptance tasks, nine deferred backlog items and two Inbox observations; 8/20 (40%). GitHub #2/#5/#6 remain deferred individually.
- App handoff: `/private/tmp/syncthingStatus-v17-build/Build/Products/Debug/syncthingStatus.app`; exact final executable verified at launch (PID 27785). The intentional fresh testing build remains running under the standing user preference.
- Validation: 114/114 tests, ad-hoc Debug build, independent review, disposable pause daemon, controlled pagination responder and `git diff --check` passed. Fixture listeners were stopped; no real user state was mutated by fixtures.
- Model fit: deep capability + high reasoning — next action designs and executes an isolated macOS UI/TCC fixture. Current setting is not reliably exposed.
- Public release stays v1.6.1 (163). Follow [Release maintenance](homebrew.md#release-maintenance) and run `/check ship` before a separately requested release.
