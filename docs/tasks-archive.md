# Completed Tasks

Total archived: 10
Last updated: 2026-09-17

## Completed

- **Homebrew audit** Full strict online audit of the published v1.6.2 cask passed with Xcode 27.2; toolchain blocker resolved. (2026-09-17)

- **GitHub #5** Long-name dropdown layout reproduced, fixed and user-accepted; shipped in v1.6.2 (165) with cleanup disabled. (2026-09-17)

- **4.2** Verify targeted pause/resume against a disposable Syncthing daemon: final-source production harness, connection-transition regressions, independent review, and unrelated-state preservation passed. (2026-09-11) — [Evidence](reviews/evidence/2026-09-11/wave-4.md).

- **3.1–3.4** Make refresh ownership and progress predictable: one coalescing scheduler, generation-isolated publication, bounded folder/device workers, 85 tests ×4 total closing runs, two independent reviews, native Refresh smoke and 25 stable About/version samples across live refresh boundaries. (2026-09-11) — [Evidence](reviews/evidence/2026-09-06/refresh.md).

- **2.1–2.3** Make sync status trustworthy: validity-aware policy shared by rows, icons and completion consumers; 70 tests, independent review and native status UI checks passed. (2026-09-06) — [Evidence](reviews/evidence/2026-09-06/sync-status.md).

- **1.2** Reproduce cleanup root and stale-identity failures through production controller regression tests. (2026-09-06)
- **1.3** Separate security-scoped access from the current configured deletion root; reject obsolete windows and confirmations. (2026-09-06)
- **1.4** Show the reviewed root and selected names in cleanup confirmation; preserve failed selections and actionable access recovery. (2026-09-06)
- **1.5** Pass independent destructive-path review and real sandbox fixture checks before clearing the cleanup release blocker. (2026-09-06)

- **1.1** Establish isolated hostless tests against production code, with test-only filesystem/defaults/credentials/transport dependencies. (2026-09-05) — 15 tests passed three consecutive runs; fresh sandboxed Debug build and launch verified.
