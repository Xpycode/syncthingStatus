# Project State

## Identity
- **Project:** syncthingStatus — macOS menu bar app showing Syncthing's sync state.
- **Bundle ID:** `com.lucesumbrarum.syncthingStatus`
- **Stack:** Swift / SwiftUI, Combine, Syncthing REST API v2, Sparkle 2.8.1.
- **Minimum macOS:** 15.5; release supports Intel and Apple Silicon.

## Now
- **Phase:** v1.7 implementation. Current public release remains v1.6.1 (build 163).
<!-- Phase changed: 2026-09-06 -->
- **Focus:** the next planned wave makes sync status trustworthy; implementation is not started. Cleanup safety is verified and archived. [Evidence](reviews/evidence/2026-09-05/cleanup-safety.md).
- **Blockers:** cleanup root/identity blocker cleared. Other v1.7 correctness work remains queued; full Homebrew audit still awaits supported Xcode tools.
- **Next:** Wave 2 (truthful sync status) is next in the plan when implementation resumes. GitHub #2, #5 and #6 remain explicitly deferred; no later wave or release started.
- **Updated:** 2026-09-06.

## Recent
- **2026-09-06:** wrapped cleanup safety: 49 tests, independent review and real sandbox/UI checks passed; five tasks archived, fresh Debug app handed off, GitHub issues recorded for later.
- **2026-09-05:** completed task 1.1: hostless production target, isolated system effects and 15 tests passing three times; independent isolation review passed. Built and launched the fresh sandboxed Debug app. [Evidence](reviews/evidence/2026-09-05/task-1.1-isolation.md).
- **2026-09-05:** expanded the review handoff into seven implementation waves with Sol/Luna source checks and a five-task cleanup sprint; subsequently detailed task 1.1 against production source, covering test membership and isolated system effects. Application source unchanged.
- **2026-09-05:** completed the app/code/usability review; reproduced a cleanup data-loss risk, false healthy status, and dropped refreshes; preserved evidence and queued fixes for next session.
- **2026-09-05:** published the Homebrew tap, added README install/upgrade links, slimmed this digest, and recorded the release checklist plus a website handoff.

## Backlog
- **Review queue:** completed five-task cleanup sprint, 14 backlog items (nine review follow-ups, two Homebrew checks and three deferred GitHub follow-ups), and two observations awaiting reproduction are tracked in [Tasks](TASKS.md). See the [review](reviews/2026-09-05-usability-code-review.md) for evidence and priority.
- **v1.7 priority:** investigate refresh overruns with offline devices. Requests can outlast the 10-second refresh interval and be cancelled by the next cycle; suspect disconnected-device `db/completion` reaching the 30-second resource timeout. About-version flickering is already fixed.
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
- Cleanup safety tasks 1.1–1.5 are complete on `fix/isolated-production-tests`. A1–A3 passed; this is not whole-release approval. Next planned implementation is Wave 2; do not start deferred GitHub fixes without the next requested work.
- Sprint: none active; five cleanup tasks archived. Tracked progress: 5/19 (26%). Deferred: 14 backlog items and two unconfirmed observations. GitHub #2, #5 and #6 are linked in `TASKS.md` and the cleanup evidence.
- Git handoff: `fix/isolated-production-tests` contains cleanup source/tests/evidence and the planning/session documentation. Continue on this branch; no merge or release is part of the handoff.
- Running app handoff: `/private/tmp/syncthingStatus-v17-build/Build/Products/Debug/syncthingStatus.app`; old installed instance quit gracefully and the exact fresh executable was verified on September 5.
- Model fit: deep capability + high reasoning for status validity and upcoming refresh concurrency; bounded independent validation remains useful.
- For every public app release, follow [Release maintenance](homebrew.md#release-maintenance): GitHub DMG first, then Sparkle + cask metadata, website deployment, and live checks. Run `/check ship` before a separately requested release.
