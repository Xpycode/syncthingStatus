# Disposable cleanup sandbox verification harness

2026-09-05. No repository source edits. This harness compiles current production controller, bookmark store, model/settings dependencies, and confirmation dialog directly. `ProductionCleanupUI.swift` contains verbatim source slices of the production cleanup window/controller, view and candidate row, with only imports added. `production-source-hashes.json` records source and extracted-slice hashes.

Bundle ID: `com.lucesumbrarum.syncthingStatus.sandbox-fixture-20260905`.

Final filesystem entitlements match production: `com.apple.security.app-sandbox=true` and `com.apple.security.files.user-selected.read-write=true`. No app-scope bookmark entitlement, network entitlement, App startup, Sparkle, real daemon access, notifications, Keychain, or login-item actions. The OS creates a distinct harness container; its standard defaults hold only the disposable bookmark. Settings use existing `SettingsFixture` isolated suites and in-memory credential/login seams; settings suites are drained/removed at exit. The harness uses real `FolderAccessBookmarks` and `.live` security scope operations. HTTP uses a session-specific URLProtocol that handles every request locally against an `.invalid` host; successful cases assert zero unexpected requests. Filesystem operations are confined to `fixtures/` under this directory.

Run `python3 extract-ui.py`, then `zsh build.sh`. All GUI launches and AX helpers require execution outside the tool filesystem sandbox in this session; the nonprompting AX/session probe is false inside and true outside. No TCC settings were changed.

Final verification scripts and preserved results:

- `run-controller-checks.py` → `controller-results.txt`: exact/ancestor NSOpenPanel grant through production grantAccess, bookmark persistence across fresh process launches, configured-root-only deletion and sibling sentinels, authoritative changed root with open controller/confirmation, cleared bookmark denied in fresh process.
- `run-dialog-checks.py` → `dialog-results.txt`: actual production native confirmation; AX root/permanent-consequences text, scroll area with all 80 selection names, Cancel, changed published folder root disabling Delete while sheet stays open, confirmed deletion and rescan/reload.
- `run-revocation-checks.py` → `revocation-results.txt`: real filesystem permission revocation via fixture chmod000, then restore; exact bookmark for a different formerly configured root fails closed; both roots' sentinels preserved. This is filesystem permission revocation and bookmark coverage validation, not TCC reset.
- `run-window-checks.py` → `window-results.txt`: actual extracted production window/view; empty Delete disabled, accessible candidate checkbox labels, Select/Deselect All, Cancel, first preflight HTTP503 preserving target and selection, Retry then successful confirmation/deletion, partial invalid-path failure retaining selected failed row, successful rescan/reload wording. Window delegate in harness calls the same controller cancellation method on close; app-level AppDelegate dispatcher wiring is source-reviewed separately.

- `run-production-picker.py` → `production-picker-results.txt`: extracted production window’s blocked access gate → its actual Grant Access NSOpenPanel → Select All → native confirmation → real contained mutation → scan/reload → Close. Final harness bookmark cleared afterward.

`bookmark-results.txt` is earlier boundary-only exploration with the extra app-scope entitlement; final controller results supersede it and run with production-equivalent filesystem entitlements.

AX automation targets only the owned process's windows (never menu actions). Some actions return AX cannot-complete/failure as the control disappears or changes into a sheet; assertions use resulting UI/controller/file state, not AX return codes alone. Harness picker URL acceptance additionally compares the selected URL with the intended fixture scope.

Exploratory findings: stat(root) succeeds before content access (stale errno after a successful stat has no meaning). Fresh sandbox directory listing is denied before resolving the scope. A bookmark may authorize a replacement at the same path when the replacement exists before a fresh controller/review; bookmarks are not persistent inode identity guards across application launches. This does not reproduce the after-review root-change bug. Final obsolete-grant test instead changes configured root outside the saved exact scope, while open-window after-review identity changes are independently exercised.

No live syncthingStatus process was quit, launched or controlled by this harness. Production app launch/build handoff is owned by the parent task.

## Preserved snapshot

This directory preserves the text harness sources, runners, final results and source hashes from the temporary verification directory. Generated binaries, caches, fixture data and verbatim UI slices are omitted. For replay, restore these text files to `/private/tmp/syncthingStatus-sandbox-probe`, create `FixtureAccess.app/Contents/MacOS`, copy `fixture-Info.plist` to the bundle's `Contents/Info.plist`, regenerate the UI slices with `extract-ui.py`, and build. Compile the AX helper Swift sources to the helper executable names referenced in the Python runners. Source hashes tie the recorded results to the implementation reviewed here; later source changes require new evidence.
