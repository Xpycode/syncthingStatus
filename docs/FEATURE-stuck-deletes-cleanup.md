# Feature: Stuck-Deletes Cleanup

> **Status:** Design doc, not yet implemented.
> **Target version:** v1.6 (after v1.5.5 ships).
> **Author note:** Drafted from a real diagnostic session against a live Syncthing daemon — the API responses cited in this document are real, not invented.

## Problem

Syncthing has a documented, intentional behavior:

> If a directory is marked deleted on the source peer, but on the receiving peer that directory contains files matching `.stignore` patterns (e.g. `.git`, `.build`, `DerivedData`, `node_modules`), the receiving peer **will not delete the directory**.

The receiver doesn't know whether those ignored files are precious local-only state. So it leaves the directory in place and reports the folder as **out of sync forever**, with no error, no log line, and a misleading UI: the "Out of Sync Items" modal lists directory basenames only, often making the situation look like rename collisions or duplicates when it isn't.

The fix is always the same: manually `rm -rf` the offending directories on the receiver, then trigger a rescan. The Syncthing maintainers have declined to automate this on safety grounds, so it falls to the user.

This is the single most common "WTF is happening with my sync" failure mode for users who reorganize folder trees containing developer artifacts. We are exactly that kind of user, and `syncthingStatus` is exactly the app that should handle it.

## Why this app

`syncthingStatus` already has the entire diagnostic substrate:

- `Client.swift` — REST API client with auth + decode pipeline
- `Models.swift` — `SyncthingFolder`, `SyncthingFolderStatus`, `SyncthingDevice` etc.
- `SyncthingSettings.swift` — settings UI patterns we can reuse
- `Views.swift` — popover and sheet UI patterns
- It runs 24/7 — perfect place to surface "your sync is stuck"

Estimated additional code: ~250 lines Swift across one new client method, one new model struct, one new view, and minor edits to existing files.

## Real-world API evidence

Live diagnostic from M4 Pro daemon (folder `ymufd-rqmj6` / "ProPro", peer M1 Max), 2026-04-29:

```json
GET /rest/db/completion?folder=ymufd-rqmj6&device=PHIOTFR-...
{
  "completion": 95,
  "globalBytes": 12153435780,
  "globalItems": 12196,
  "needBytes": 0,
  "needDeletes": 10,
  "remoteState": "valid",
  "sequence": 33095
}
```

`needDeletes: 10` with `needBytes: 0` is the exact fingerprint of this failure mode: peer needs nothing more from us, only has deletions to apply, isn't applying them.

```json
GET /rest/db/remoteneed?folder=ymufd-rqmj6&device=PHIOTFR-...&perpage=100
{
  "total": 0,                          ← lies; the array is populated
  "files": [
    { "name": "1-macOS/VideoWallpaper",          "deleted": true, "type": "FILE_INFO_TYPE_DIRECTORY" },
    { "name": "1-macOS/VideoWallpaper/.serena",  "deleted": true, "type": "FILE_INFO_TYPE_DIRECTORY" },
    { "name": "1-macOS/VideoWallpaper/01_Project","deleted": true, "type": "FILE_INFO_TYPE_DIRECTORY" },
    ...
  ]
}
```

Notes:
- `total: 0` is wrong in this response shape — count from `files.count` instead.
- All entries had `deleted: true`. Files (non-deleted) can also appear in `remoteneed`, but for our feature we filter to `deleted == true && type ends with DIRECTORY`.
- Names are repo-relative paths (no leading slash). Resolve against the folder's `path` config to get absolute filesystem path.

## User experience

### Detection (passive)

When any configured folder has `needDeletes > 0` for any peer device that is `valid` and `connected`, surface it. Two surfacing options, default to both:

- **Menu bar icon:** new amber state with a small badge (or a dot overlay on the existing icon) — stays out of the way unless something is wrong.
- **Popover:** new row at top of the popover for affected folders, like an inline alert: *"3 stuck deletions on 'ProPro'. Resolve…"*

Suppression rule: don't badge if Syncthing's folder state is `scanning`, `syncing`, or `cleaning` — only when the folder is `idle` and the deletes have persisted for ≥30 seconds. Avoids flapping.

### Resolution flow

User clicks "Resolve" → opens a sheet titled *"Stuck deletions on `<folder label>`"*.

```
┌─────────────────────────────────────────────────────────────────┐
│ Syncthing wants to delete these folders on this Mac, but        │
│ can't because they contain ignored files (.git, .build, etc.).  │
│ This usually happens after you move or rename folders on        │
│ another Mac.                                                    │
│                                                                 │
│  ☑  1-macOS/VideoWallpaper                                      │
│      └ 12 ignored files inside (.git, .build)                   │
│  ☑  1-macOS/syncthingStatus                                     │
│      └ 8 ignored files inside (.git)                            │
│  ☐  1-macOS/old-project                                          │
│      └ 3 ignored files inside (.git)                             │
│                                                                 │
│  Folder root: /Users/sim/ProgrammingProjects                    │
│                                                                 │
│  [ Reveal in Finder ]    [ Cancel ]    [ Delete 2 selected ]    │
└─────────────────────────────────────────────────────────────────┘
```

Safety design:

1. **Default state: nothing selected.** Forces user to tick each box.
2. **"Delete N selected" button is disabled until ≥1 box checked.**
3. **Confirmation sheet** before destruction: *"This will permanently delete 2 folders and everything inside them, including any ignored files. This cannot be undone."*  → Cancel / Delete.
4. **No "Select all" button.** Eyes on each row is the point.
5. **Reveal in Finder** opens the folder's parent in Finder with the candidate selected — lets user inspect before deleting.

### After deletion

1. Each path → `FileManager.default.removeItem(at:)`. Log success/failure per path.
2. After all paths processed, call Syncthing's `POST /rest/db/scan?folder=<id>` to trigger a rescan.
3. Poll `db/completion` for that folder+peer until `needDeletes == 0` (timeout 30 s).
4. Show a result toast/sheet: *"2 folders cleaned. Sync resolved."* or list which ones failed and why.

## Permission model

App is **direct distribution, not sandboxed, not App Store** (per `PROJECT_STATE.md` and current entitlements).

→ **Use Full Disk Access (FDA).** Required because Syncthing folders typically live in `~/Documents`, `~/Desktop`, or external volumes — all of which are TCC-protected on modern macOS even outside the sandbox.

### First-run UX for FDA

1. On first attempt to delete, catch `NSFileWriteNoPermissionError` / `EPERM`.
2. Show alert with two buttons: *"Open System Settings"* (opens Privacy & Security → Full Disk Access at the right pane) and *"Cancel"*.
3. Add `syncthingStatus.app` to the FDA list manually — macOS requires user action; we cannot grant ourselves access.
4. After granting, user must quit + relaunch (FDA grant doesn't apply to running processes).

Implement using:
```swift
// Detect missing FDA proactively before showing the cleanup sheet:
let testURL = URL(fileURLWithPath: folderPath)
do {
    _ = try FileManager.default.contentsOfDirectory(atPath: testURL.path)
} catch let error as NSError where error.code == NSFileReadNoPermissionError {
    showFDAAlert()
    return
}
```

Open the FDA settings pane:
```swift
NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
```

### Privacy/security entitlements to verify

Check `01_Project/syncthingStatus/syncthingStatus.entitlements`:
- `com.apple.security.app-sandbox` should be **false** (you're unsandboxed already)
- No additional entitlements needed for FDA — it's a TCC permission, not an entitlement
- Notarization: deletion does not change notarization requirements

## Architecture

### New files

```
01_Project/syncthingStatus/StuckDeletes/
  ├ StuckDeletesController.swift   ~120 lines  — detection, polling, deletion orchestration
  ├ StuckDeletesView.swift          ~100 lines  — sheet UI (list + confirm)
  └ RemoteNeedItem.swift            ~30 lines   — model for /db/remoteneed response
```

(Group as a subfolder under the existing source root. Match the existing flat-ish layout if preferred — there isn't a precedent for subfolders yet, so this is a soft suggestion.)

### Edits to existing files

- **`Client.swift`** — add two methods:
  ```swift
  func remoteNeed(folder: String, device: String) async throws -> [RemoteNeedItem]
  func rescan(folder: String) async throws
  ```
  Endpoints: `GET /rest/db/remoteneed?folder=X&device=Y&perpage=1000`, `POST /rest/db/scan?folder=X`.

- **`Models.swift`** — add `RemoteNeedItem` (or put it in its own file as listed above; either is fine, follow whatever the rest of the codebase does):
  ```swift
  struct RemoteNeedItem: Decodable, Identifiable {
      let name: String           // repo-relative path
      let deleted: Bool
      let type: String           // "FILE_INFO_TYPE_DIRECTORY" or "FILE_INFO_TYPE_FILE"
      var id: String { name }
      var isDirectory: Bool { type.hasSuffix("DIRECTORY") }
  }
  ```

- **`SyncthingStatusIcon.swift`** — new state for "stuck deletes detected"; either reuse the amber traffic-light state introduced in v1.5.5, or add a small badge dot. Decide based on visual budget — probably reuse amber + tooltip "Stuck deletions need attention".

- **`Views.swift`** — popover gets a new top section `StuckDeletesAlertRow` (only shown when count > 0); button opens the sheet hosted by `StuckDeletesView`.

- **`Constants.swift`** — add settings keys for opt-out (`hideStuckDeletesAlerts: Bool`, default `false`).

- **`SyncthingSettings.swift`** — add a single toggle "Detect stuck deletions" (default on). Power-user setting; no need to expose threshold tuning.

### Detection wiring

In whatever periodic poll loop the app already has (look at how `SyncthingFolderStatus` is currently fetched — there's an existing timer / Combine pipeline in the controller layer):

1. After fetching each folder's status, if `state == "idle"` AND `globalBytes > 0`, also fetch `db/completion` for each connected peer.
2. If any peer has `needDeletes > 0` AND `needBytes == 0`, mark the folder as "stuck-deletes affected" with the count.
3. Apply the 30-second debounce before badging — store first-detected timestamp, only flip the flag after sustained.

## Edge cases / non-goals

- **Multiple peers, multiple folders.** The sheet is per-folder. If two folders are affected, two separate menu entries / sheet invocations. Don't try to bulk-process across folders.
- **`needDeletes` includes file deletions, not just directory deletions.** Per Syncthing semantics, file-level stuck deletes are very rare (usually permission/lock issues, not ignore-pattern issues). We **only show directory entries** in this feature for now. Filter `isDirectory == true` in the sheet. File-level can be a v2.
- **Peer is "this Mac" too.** When fetching `db/completion`, skip self (compare device ID against `system/status`'s `myID`). The feature is about cleaning up *this* peer's stale state — but the API treats every peer symmetrically, so we have to filter.
- **Folder type is `receiveonly` on this peer.** Out of scope — different problem with a different fix (Override/Revert buttons in the web UI). Don't show our cleanup sheet for receive-only folders; defer to web UI.
- **Folder is paused.** Don't badge. User probably paused it on purpose.
- **Path sanitization.** Each `RemoteNeedItem.name` must be normalized before joining to folder root. Reject paths containing `..`, leading `/`, or null bytes. Defense in depth — Syncthing daemon shouldn't emit those, but a hostile / corrupted index shouldn't be able to make us delete `/`.
- **Symlinks.** If the candidate path is a symlink (`FileManager.default.attributesOfItem(atPath:)[.type] as? FileAttributeType == .typeSymbolicLink`), unlink the symlink itself, do *not* recurse. Otherwise `removeItem` on a symlink to `/` would be catastrophic.
- **Don't auto-delete.** Ever. No setting for it. The whole point of the feature is presenting a confirmable list — the moment we auto-delete, we're worse than the current Syncthing behavior.

## Implementation order (suggested)

1. **Model + Client** — add `RemoteNeedItem`, `remoteNeed(folder:device:)`, `rescan(folder:)`. Unit test against the JSON in this doc.
2. **Detection** — extend the periodic poll to compute a `stuckDeletesByFolder: [FolderID: Int]` dictionary. Verify it lights up with the live data we have right now.
3. **Sheet UI** — `StuckDeletesView` with the list, checkboxes, confirm flow. Use existing sheet style from settings.
4. **Wire up popover row + menu icon state** — visible entry point.
5. **Deletion logic** — `FileManager.removeItem` + rescan + result toast. FDA-error handling.
6. **Settings toggle** — opt-out for users who don't want this surfaced.
7. **Polish** — Reveal in Finder, ignored-file-count subtitles (use `FileManager.enumerator` + check against parsed `.stignore`; cheap).

## Testing checklist

Live test: reproduce the M4↔M1 scenario.
- [ ] Move a folder containing `.git` from `~/ProgrammingProjects/foo` to `~/ProgrammingProjects/_archive/foo` on M4.
- [ ] Wait for M1 to receive the move; observe `needDeletes > 0` on M4's view of M1.
- [ ] App on M1 detects within one poll cycle.
- [ ] Menu bar icon goes amber. Tooltip explains.
- [ ] Popover shows the stuck-folder row.
- [ ] Sheet opens, lists `foo` correctly with the relative path.
- [ ] Confirmation flow requires explicit checkbox + button click.
- [ ] After deletion, rescan triggers, `needDeletes` drops to 0, icon returns to normal within ~5 s.

Manual unhappy-path tests:
- [ ] FDA missing → alert shown, link to System Settings opens correct pane.
- [ ] User denies FDA → cleanup sheet remains usable for *viewing* but Delete button shows "Grant Full Disk Access first".
- [ ] Path contains `..` → rejected, logged, not deleted.
- [ ] Path is a symlink → unlinked only, not recursed.
- [ ] Folder is `receiveonly` on this peer → cleanup not offered.
- [ ] Folder is paused → no badge.
- [ ] Two folders simultaneously affected → both surfaced independently, separate sheets.

## Open questions for the implementing session

1. **Existing icon-state machine** — is the v1.5.5 traffic-light amber state suitable to reuse for "stuck deletes," or should we add a distinct icon variant? Check `SyncthingStatusIcon.swift`.
2. **Existing poll cadence** — what's the current interval for `db/status` polling? `db/completion` should piggyback rather than create a second timer.
3. **Existing sheet style** — does `Views.swift` already have a sheet modifier pattern (e.g. for the existing settings flow) we should match?
4. **Settings storage** — where do current settings live? `@AppStorage`, custom `UserDefaults` keys, or a settings store object?
5. **Logging** — `OSLog` subsystem `com.lucesumbrarum.syncthingStatus`, category `StuckDeletes`. Match the convention used by the v1.5.5 `FolderStatus` category.

## Reference

- Syncthing REST API: `https://docs.syncthing.net/dev/rest.html`
- Specifically: `db/completion`, `db/remoteneed`, `db/scan`, `system/config`, `system/status`
- Existing decisions: `decisions.md` (esp. 2026-04-28 entries on folder-state whitelisting and defensive decoding — the same patterns apply here)
- Real diagnostic transcript that prompted this feature: see chat session of 2026-04-29 with Claude in `~/CLAUDE-sessions/`

---

*Draft 2026-04-29. Update freely as implementation reveals constraints.*
