# Plan — GitHub #2 and #6 follow-ups

**Status:** Planned, not started · **Created:** 2026-09-27

> Supplement to the active [v1.7 implementation plan](IMPLEMENTATION_PLAN.md). Planning does not authorize execution, a release, or an issue reply. The current Wave 4 acceptance sprint stays active; these tasks remain in Backlog until selected for execution.

## Goal and scope

Deliver genuine appearance-aware monochrome menu bar icons for [#2](https://github.com/Xpycode/syncthingStatus/issues/2), and finish the published custom Homebrew tap's isolated installation proof and reporter follow-up for [#6](https://github.com/Xpycode/syncthingStatus/issues/6). The user chose the custom tap as #6's scope. An official `homebrew/cask` submission is outside this plan.

## Specs and current baseline

- [#2 monochrome icon spec](../specs/github-2-monochrome-menu-bar-icons.md): Settings already persists `IconColorMode`; the current renderer always loads colored PNGs and sets `NSImage.isTemplate = false`. `StatusIconStateResolver` currently collapses some attention states to the normal image in Monochrome. Active transfer states currently use a static `SYNCING` image; unused frame arrays must not be mistaken for live animation.
- [#6 Homebrew spec](../specs/github-6-homebrew-installation.md): the v1.6.2 cask, README commands, public fetch, checksum and strict online audit already exist and passed. A full isolated install/upgrade and reporter reply remain. A custom tap is not the official catalogue.
- The public v1.6.2 branch and the active v1.7 branch have diverged. The v1.6.2 layout fix and cleanup-disable release decision must be reconciled before any later combined release; neither icon work nor Homebrew validation may silently overwrite them.

## Execution schedule and ownership

- **Selection gate:** #6 can be selected after the active cleanup-safety work, without waiting for #2 or Wave 5. #2 source changes wait until Wave 4's acceptance and any overlapping Wave 5 Settings/App edits are stable. Asset design and read-only exploration may be done earlier. This plan is queued; `/execute` must name this plan or its task IDs to select it while the active plan remains incomplete.
- Wave labels organize dependency-ready tasks; a blocked task does not stop another task whose named prerequisites are met. Tasks that touch the shared task/state records are in separate waves and are applied serially.
- **Shared ownership:** one coordinator owns git, `docs/TASKS.md`, `docs/PROJECT_STATE.md`, this plan, Xcode project membership, builds, Homebrew state and issue replies. No two tasks edit `App.swift`, `Views.swift`, `SyncthingStatusIcon.swift` or the same Homebrew tap at once. On this host, execute ready work serially; independent tasks can be scheduled separately without a subagent.
- **External gates:** native light/dark/highlight icon acceptance requires a runnable macOS menu bar session; Homebrew install/upgrade requires a disposable VM or equivalently isolated Homebrew prefix and app destination. `--appdir` alone does not isolate Homebrew's Caskroom or protect an installed cask. If that fixture is unavailable, keep GH6.2–GH6.5 open; it does not block GH2 work.

## Tasks

### Wave A — establish contracts and safe fixtures

- [ ] **GH2.1 — Record the icon state/appearance matrix.** Depends on: none. External gates: none. Owns: icon acceptance notes in this plan or `docs/reviews/evidence/`; read-only inspection of `SyncStatusPolicy.swift`, `SyncthingStatusIcon.swift`, `App.swift`, Settings. Interface: state → monochrome glyph/color glyph/tooltip mapping for GH2.2–GH2.4; retain the existing default and persisted preference. Success: enumerate connecting, in-sync, active sync, attention/unavailable, error, fallbacks and selected/highlighted appearances; identify the live static path versus unused animation. Backpressure: inspect all renderer call sites and compare the matrix with every #2 acceptance criterion; no behavior claimed tested yet.
- [ ] **GH6.1 — Prepare a genuinely isolated cask test.** Depends on: none. External gates: access to a disposable macOS VM or proven separate Homebrew prefix and app destination. Owns: disposable test script/evidence under `docs/reviews/evidence/` or `/private/tmp`, not the public cask. Interface: fixture location and teardown commands for GH6.2–GH6.3. Success: prove the fixture cannot modify the user's `/Applications/syncthingStatus.app`, Caskroom record, settings, credentials, bookmarks or daemon; record baseline versions and exact Homebrew commands. Backpressure: inspect `brew --prefix`, installed casks, `brew help install`/`upgrade`, and destination before any installation; stop if isolation cannot be proved.

### Wave B — independent asset and distribution proof

- [ ] **GH2.2 — Create and verify monochrome template artwork.** Depends on: GH2.1. External gates: none. Owns: new files in `01_Project/syncthingStatus/menuBarStatusIcons/` and an asset-inspection check under `tools/`; coordinator owns any `project.pbxproj` membership. Interface: named black/transparent images for every live semantic state with stable size/alpha, consumed by GH2.3. Success: artwork has no fixed hue, fits the existing square status item and differentiates idle, syncing, attention and error without color. Backpressure: run the asset-inspection check over every new PNG and inspect the rendered glyph sheet at menu bar size; build after target membership changes.
- [ ] **GH6.2 — Verify isolated install from the published custom tap.** Depends on: GH6.1. External gates: proven disposable fixture and public v1.6.2 DMG/tap availability. Owns: Homebrew fixture/evidence only. Interface: installed v1.6.2 test app for GH6.3. Success: documented tap and install commands succeed; test app has expected bundle ID/version/architectures, valid signature and notarization; user's installed app and Homebrew state are unchanged. Backpressure: `brew fetch --cask`, isolated `brew install --cask`, `plutil`/`codesign --verify --deep --strict`/`xcrun stapler validate`, before/after identity and path checks. A fetch or audit alone does not pass this task.

### Wave C — independent implementation and upgrade

- [ ] **GH2.3 — Wire style-specific icon rendering.** Depends on: GH2.2 and accepted Wave 4 source. External gates: none. Owns: `SyncthingStatusIcon.swift`, `SyncStatusPolicy.swift`, icon-related `App.swift` call sites, focused `SyncStatusTests.swift`; coordinator serializes shared App/project edits with active-plan tasks. Interface: render a semantic state and selected style together, never reuse cached colored images as templates. Success: Monochrome uses appearance-aware template artwork for every live state and fallback; Traffic-Light retains colored behavior; switching style updates immediately; tooltip/accessibility text stays truthful. Backpressure: focused status tests, full hostless test suite and fresh Debug build from the active plan. Do not add tests that merely assert asset filenames.
- [ ] **GH6.3 — Verify isolated upgrade and migration limits.** Depends on: GH6.1–GH6.2. External gates: published v1.6.1/v1.6.2 assets and a fixture where a v1.6.1 cask can be advanced to v1.6.2. Owns: disposable tap/test evidence only. Interface: verified upgrade result and limitations for GH6.4. Success: an isolated v1.6.1 test installation upgrades to v1.6.2 with `--greedy`; no claim about the real installed app. Verify the manual-install `--adopt` guidance only in the disposable fixture or label it unverified. Backpressure: before/after bundle versions, checksum/signature and app-path checks; record command output and any skip/limitation explicitly.

### Wave D — Settings and documentation

- [ ] **GH2.4 — Make the existing Settings description accurate.** Depends on: GH2.3 and completion of overlapping Wave 5 Settings edit (5.2), if selected. External gates: none. Owns: only the Status Icon portion of `Views.swift` and relevant `SyncthingSettings.swift` text/defaults if necessary. Interface: existing stored values `.monochrome`/`.traffic` remain compatible. Success: description says Monochrome adapts to menu bar appearance and Traffic-Light keeps color; no new control is added. Backpressure: focused Settings persistence test, fresh Debug build, visual check of existing Settings layout. If a new control becomes necessary, run the UI placement protocol before changing scope.
- [ ] **GH6.4 — Publish accurate custom-tap instructions.** Depends on: GH6.2–GH6.3. External gates: none beyond those test results. Owns: Homebrew section in `README.md`, `docs/homebrew.md`, relevant evidence; no cask version change unless a real public release requires it. Interface: exact tested commands and honest `--adopt`/upgrade limits for GH6.5. Success: a user can follow the README from a clean Homebrew setup; the custom-tap requirement and official-catalogue distinction are explicit. Backpressure: copy commands into a fresh isolated shell/fixture, validate Markdown links and `git diff --check`.

### Wave E — Homebrew issue resolution

- [ ] **GH6.5 — Reply to and resolve GitHub #6.** Depends on: GH6.4. External gates: published custom tap still serves the tested release. Owns: the GitHub issue reply and task/spec/state evidence; coordinator performs the external write. Success: reply includes the exact custom-tap install/upgrade commands, links README/release, states that the one-command official catalogue form is unavailable, and closes #6 when the documented custom-tap scope has passed. Backpressure: re-read the open issue and live README/cask immediately before posting; verify the comment and closed state afterward.

### Wave F — native icon acceptance

- [ ] **GH2.5 — Accept the icon behavior in a fresh app.** Depends on: GH2.3–GH2.4; independent of GH6.5. External gates: runnable macOS menu bar session and isolated preferences. Owns: screenshots/AX observations and task/spec/state evidence. Success: light, dark, highlighted and normal menu bar appearances; all live states, immediate style change, relaunch persistence, accessible names and missing-asset fallback pass. Reconcile with selected Wave 6 icon cleanup (6.4) so it cannot remove live artwork or duplicate renderer edits. Backpressure: full tests/build plus recorded native matrix; failed or unavailable visual cases remain open.

### Wave G — shipped icon follow-up

- [ ] **GH2.6 — Reply to and resolve GitHub #2.** Depends on: GH2.5. External gates: the accepted icon implementation has been integrated with the v1.6.2 release changes, passed the active plan's release gate and shipped in a public app release. Owns: GitHub issue reply and task/spec/state evidence; coordinator performs the external write. Success: reply names the release, explains where Monochrome is selected, links the download and closes #2 after verifying the public artifact contains the icon change. Backpressure: inspect the release tag/artifact and GitHub issue state before and after the reply. Planning this task does not authorize publication.

## Integration and acceptance

- [ ] Before a later app release, reconcile the v1.6.2 release branch with the active v1.7 source and re-run affected layout, cleanup-safety, status-icon, updater and distribution checks. This is a release gate, not a prerequisite for GH6's current v1.6.2 custom-tap reply.
- [ ] Map GH2.5 evidence to every #2 spec criterion and GH6.2–GH6.5 evidence to every remaining #6 criterion. Keep issue closure and shipping claims separate: an implemented icon on an unshipped branch does not resolve the reporter's request.

## Execution log

| Task | Evidence | Commit / issue action | Remaining gate |
|---|---|---|---|
| Planning only (2026-09-27) | Specs and current code/distribution records inspected; no app or Homebrew test run | None | Select tasks for execution; Wave 4 remains active |
