# Project State

## Identity
- **Project:** syncthingStatus — macOS menu bar app showing Syncthing's sync state.
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`
- **Stack:** Swift / SwiftUI, Combine, Syncthing REST API v2, Sparkle 2.8.1.
- **Minimum macOS:** 15.5; release supports Intel and Apple Silicon.

## Now
- **Phase:** v1.7 implementation. Current public release is v1.6.2 (build 165).
<!-- Phase changed: 2026-09-06 -->
- **Focus:** finish Wave 4's notification-scope relaunch, cleanup-window pagination and notification-TCC UI matrix with the isolated fixture.
- **Execution:** Wave 4 is [partially accepted](reviews/evidence/2026-09-11/wave-4.md): 4.2/A7 passed. A unique sandboxed bundle, isolated defaults/credentials, loopback Syncthing responder and AX driver now exist; clean recovery, picker cancel/regrant, loopback connection and Connection-first Settings passed live. Tasks 4.1, 4.3–4.5 and A6/A8/A9 remain open.
- **Blockers:** the fixture's notification disclosure/scope interaction and remaining relaunch, cleanup-window pagination/retry/cancel and TCC denied/granted cases were not completed before the user stopped execution.
- **Next:** restart the loopback responder and unique-bundle fixture, then complete notification scope/relaunch, cleanup-window pagination/retry/cancel and TCC denied/granted/combined flows in [Wave 4 evidence](reviews/evidence/2026-09-11/wave-4.md).
- **Updated:** 2026-09-17.

- **Hotfix release:** v1.6.2 (165) published and live-verified on GitHub, Sparkle, Homebrew and homepage. Cleanup disabled by user decision; installed 1.6.1 is running for updater acceptance.

## Recent
- **2026-09-17:** full Homebrew audit passed with Xcode 27.2; published v1.6.2 (165) with the accepted long-name layout fix and cleanup disabled; all channels verified, README/changelog updated. Installed 1.6.1 retained for user updater testing.
- **2026-09-11:** checkpointed the isolated Wave 4 UI harness after live clean recovery, picker cancel/regrant, loopback connection and Connection-first Settings checks; remaining scope/relaunch, cleanup-window and TCC cases stay open.
- **2026-09-11:** partially accepted Wave 4: 4.2/A7 passed with a disposable daemon; 114 tests, controlled pagination, independent review and a fresh Debug launch pass, while isolated UI/TCC cases remain.
- **2026-09-11:** closed Wave 3 after a fresh build, another clean 85-test run, independent review and 25 stable About/version samples across live refreshes; also explained healthy device-local file-count differences, recorded a UI clarification, and tightened Wave 4 after readiness review. The unchanged 85-test baseline passed again before Wave 4 execution.
- **2026-09-06:** implemented refresh ownership and bounded workers; 85 tests ×3 and independent review passed. Fresh sandboxed app launched; three Refresh clicks and About version checked. Stopped during repeated About observation; changes remain uncommitted.

## Backlog
- **Review queue:** ten archived tasks, three active Wave 4 acceptance tasks, seven deferred backlog items and two Inbox observations are tracked in [Tasks](TASKS.md). Overall progress: 10/20 (50%).
- **v1.7 priority:** Wave 4 implementation is complete but its live gate remains. Offline-peer overrun was measured at 16.7808 s; the separate 30 s resource-timeout hypothesis remains unconfirmed. Timer/manual refreshes now coalesce and slow entries use bounded workers.
- **GitHub issues:** #2 genuine monochrome icons and #6 Homebrew response are explicitly deferred until after cleanup safety; linked tasks are recorded in `TASKS.md` (user decision 2026-09-05).
- **v1.7 polish:** Feedback / Donate / Help, window frame autosave, split the large Views and Client files, refresh About credits on reconnect.
- **Remote HTTPS:** consider opt-in certificate pinning if more NAS / remote-host reports arrive; self-signed certificate auto-trust is restricted to loopback.
- **User follow-up:** reply to the HTTPS reporter with v1.6.1 and the one-time manual-download instruction.
- **Signing-key housekeeping:** label the Group B Sparkle entry in Strongbox; optional named Keychain import. Custody details remain in the historical snapshot.
- **Cookbook candidates:** real-home tilde expansion with `stat(2)` / errno probing; `SMAppService.mainApp` for Launch at Login.
- **Optional user cleanup:** revoke the obsolete Full Disk Access grant for this app; retain the daemon's grant.
- **Website:** Homebrew instructions are live; v1.6.2 page/catalogue/sitemap/download deployed and verified 2026-09-17; counters and feedback preserved.

## Infrastructure
- **Release:** GitHub `Xpycode/syncthingStatus`; v1.6.2 (165) Universal DMG notarized/stapled. GitHub, updater, Homebrew fetch and homepage download hashes verified live 2026-09-17. Cleanup is temporarily disabled.
- **Homebrew:** `Casks/syncthingstatus.rb` is live in this repository's custom tap; v1.6.2 public fetch and full strict online audit passed 2026-09-17 with Xcode 27.2. Install commands and validation limits: [Homebrew distribution](homebrew.md).
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
- Next pickup: restart `tools/wave4-fixture-server.py`, build/launch via `tools/build-wave4-acceptance-fixture.sh`, then complete notification disclosure/scope relaunch, cleanup-window pagination/retry/cancel and TCC denied/granted/combined cases. The fixture defaults currently point to the disposable loopback configuration.
- Git: `fix/isolated-production-tests`; this incomplete fixture checkpoint is committed and pushed. Merge and release remain unauthorized.
- Tasks: ten archived, three active acceptance tasks, seven deferred backlog items and two Inbox observations; 10/20 (50%). GitHub #2/#6 remain deferred; #5 shipped in 1.6.2.
- App handoff: only `/Applications/syncthingStatus.app` v1.6.1 is running, retained at user request to test the live updater to 1.6.2 (165).
- Validation: 114/114 tests, normal unsigned Debug compile, isolated fixture build/signing/entitlements, tool syntax/compile checks, live clean-recovery/picker/connection/Settings checks and `git diff --check` passed. No production defaults, Keychain credentials, bookmarks or daemon state were mutated.
- Model fit: deep capability + high reasoning — next action completes several stateful macOS UI/TCC flows. Current setting is not reliably exposed.
- Public release is v1.6.2 (165); cleanup disabled. User update acceptance from installed 1.6.1 remains; v1.7 work is separate.
