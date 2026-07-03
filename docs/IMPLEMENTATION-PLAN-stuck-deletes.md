# Implementation Plan: Stuck-Deletes — Popover Out-of-Sync Fix + Cleanup Feature

> **Companion to:** `FEATURE-stuck-deletes-cleanup.md` (the design doc).
> **Status:** Plan, not yet implementation. Awaiting user approval before any code changes.
> **Drafted:** 2026-04-29.

---

## TL;DR — what changed about the design

The feature doc framed this as one feature ("Stuck-Deletes Cleanup") targeting v1.6. Investigation revealed it's **two features stacked**, with a much smaller pre-fix that the user has already noticed:

1. **Pre-fix (small, ship first):** The popover does not show the out-of-sync state that the WebUI shows. Cause: `SyncthingFolderStatus` (`Models.swift:62`) doesn't decode `needDeletes`. Two new decoded fields (`needDeletes`, `needTotalItems`), one resolver clause, two label sites in `FolderStatusRow`. ~30 LOC. Fixes the user's headline complaint without any cleanup machinery.
2. **Cleanup feature (medium, ship second):** The full sheet-with-checkboxes destructive cleanup. ~250 LOC as the doc estimated, but the API choice changes from `db/remoteneed` to `db/need` (see §"API choice").

Doing them as one PR conflates a low-risk visibility fix with a high-risk file-deleting feature. Splitting them lets the pre-fix ship as a v1.5.6 patch and the cleanup take its time at v1.6.

---

## The popover gap, explained

### What the WebUI is doing that we aren't

Syncthing's `GET /rest/db/status?folder=X` returns 30 fields. The relevant ones for "out of sync" are:

| Field            | What it means                                        |
| ---------------- | ---------------------------------------------------- |
| `needFiles`      | Files this peer needs to download                    |
| `needBytes`      | Bytes implied by `needFiles`                         |
| `needDeletes`    | Items this peer needs to **delete** to be in sync    |
| `needDirectories`| Directories needed (subset of `needFiles`+`needDeletes`)|
| `needTotalItems` | Sum of all `need*` counters                          |
| `state`          | `idle / scanning / syncing / cleaning / …`           |
| `stateChanged`   | (v2) replaces `lastScan` — already handled defensively|

The WebUI shows "Out of Sync" whenever `needTotalItems > 0`. **Our model decodes only `needFiles` and `needBytes`**, so a folder with `needFiles: 0, needBytes: 0, needDeletes: 10` reads as "Up to date" everywhere in the app. That is the user's exact symptom.

### Why this also breaks the existing icon resolver

`StatusIconStateResolver.resolveState` (`App.swift:90-96`) only declares `.outOfSync` when `needBytes > syncRemainingBytesThreshold`. Stuck-deletes have zero bytes, so the icon stays green. Same root cause; same fix.

### Why we don't see this on every poll

Stuck-deletes only happen when the receiver has files matching `.stignore` patterns inside a directory the sender deleted. For most users, that's rare. For developers (the actual user base), it happens any time you reorganise folders containing `.git`, `.build`, `node_modules`, etc. — which is exactly what the design doc identifies.

---

## API choice: `db/need`, not `db/remoteneed`

The design doc cites `GET /rest/db/remoteneed?folder=X&device=Y` because the live diagnostic was run on the **sender** (M4) inspecting the **receiver** (M1). For an app running on the receiver, the equivalent — and simpler — call is `GET /rest/db/need?folder=X`, which returns what the local node itself needs to do.

Differences that matter:

| Concern             | `db/remoteneed`                         | `db/need` (chosen)                |
| ------------------- | --------------------------------------- | --------------------------------- |
| Vantage point       | What we think peer Y needs              | What we ourselves need            |
| Required params     | `folder`, `device`                      | `folder` only                     |
| Response shape      | `{files: [...], page, perpage}`         | `{progress, queued, rest, page, perpage}` |
| Cleanup actionable? | No (we'd be inspecting the wrong host)  | Yes (paths are local to this Mac) |
| Fan-out             | One call per (folder, peer) pair        | One call per folder               |
| Pagination quirk    | `total` field unreliable per design doc | `total` removed in v0.14.43       |
| Cost warning        | "Use sparingly" (docs)                  | "Use sparingly" (docs)            |

**Both are expensive** — neither should be on the poll loop. `db/need` is only invoked when the user opens the cleanup sheet.

### Detection vs. listing — separate calls

- **Detection (every poll):** `db/status?folder=X` is already polled. Adding `needDeletes` to the decoded model gives us detection for free.
- **Listing (on-demand):** `db/need?folder=X` is called once per sheet-open. Filter to `deleted == true && type` ending in `DIRECTORY` (the design doc's filter is correct; only the endpoint changes).

Field caveats for `db/need`:
- The official endpoint docs **don't list** `deleted` or `type` in the response shape, but the actual Go source emits them and the doc author saw them in live diagnostics. We rely on observed behaviour and decode defensively.
- Response is split into three buckets: `progress` (downloading now), `queued` (next), `rest` (after that). Stuck deletes show up in `rest`. We must merge all three.
- `total` was removed in v0.14.43 — count from `files.count` (or in this case `progress + queued + rest`).

### What about `db/completion` (the doc's primary fingerprint)?

`db/completion?folder=X&device=Y` returns `{completion, globalBytes, needBytes, needDeletes, ...}` for one (folder, peer) pair. The model `SyncthingDeviceCompletion` already exists (`Models.swift:105-109`) but, again, doesn't decode `needDeletes`.

This is useful as a **secondary** detection path: it lets us tell the user "peer M1 has stuck deletes, but you'd need to clean up on M1 to fix it." Out of scope for v1 of the cleanup; in scope for the model fix because the field is free to decode.

---

## Open questions — answered

### 1. Reuse the v1.5.5 amber traffic-light state, or add a new icon variant?

**Reuse the existing `.warning` state.** Stuck-deletes is exactly what amber is for: not broken, but needs attention. In `monochrome` mode this falls back to `.normal` via `staticIconFallbacks` (`SyncthingStatusIcon.swift:42`); to give monochrome users any signal, the resolver should still drive `.outOfSync` (red) when `needDeletes > 0` AND some user-tunable threshold (e.g. `>= 1` directory). Or — simplest and most consistent — just route stuck-deletes to `.outOfSync` in both modes and rely on the popover's alert row + tooltip for the "actionable" framing. The doc's own reasoning ("loud when something is genuinely wrong") supports this.

**Decision:** route stuck-deletes through the existing `.outOfSync` rule (red in mono, red in traffic — Rule 6 in the resolver already handles both). No new icon state. Tooltip becomes "Out of sync (N pending deletes)" when that's the cause.

### 2. Existing poll cadence

`refreshInterval` (default 10 s, `Constants.swift:18`) drives a single `Timer` in `AppDelegate.startMonitoring` (`App.swift:357`) → `syncthingClient.refresh()` → `performRefresh()` (`Client.swift:1070`). Inside `performRefresh`, after `fetchStatus` and `fetchConfig`, three calls run in parallel via `async let`: `fetchVersion`, `fetchConnections`, `fetchFolderStatus`.

**Detection piggybacks on `fetchFolderStatus`** — already once per folder, already once per poll. No new timer, no new requests. The `db/status` payload already contains `needDeletes`; we're just decoding more of it.

### 3. Existing sheet style

There is **no in-app sheet pattern** currently. The settings UI is presented via the SwiftUI `Settings { … }` scene (`App.swift:696`); the main window is a separate `MainWindowController` opened by `openMainWindow()` (`App.swift:463`). Sheets attached to NSPopover have well-known z-order and dismissal bugs.

**Recommendation:** present the cleanup UI as a **dedicated NSWindow**, similar to `MainWindowController`. Pattern:
1. User clicks "Resolve" in the popover.
2. We call `closePopover()`, then construct a new `StuckDeletesWindowController` with the affected folder bound.
3. The window is non-modal but `becomesKey` and `orderFront`. App switches to `.regular` activation policy while the window is up (mirrors `presentSettings` at `App.swift:475`).
4. On window close, revert to `.accessory` if no other windows remain (mirrors `revertToAccessoryIfAppropriate` at `App.swift:530`).

This avoids the popover-sheet pitfalls and matches the pattern the codebase already established for settings.

### 4. Settings storage

`SyncthingSettings` is an `ObservableObject` with `@Published` properties backed by `UserDefaults` (debounced auto-save, `SyncthingSettings.swift:128`). Add:

```swift
@Published var stuckDeletesAlertsEnabled: Bool   // default true
```

Plus a Keys constant and a hookup in `setupAutoSave`. ~5 lines. Keychain is for the API key only; not needed here.

### 5. Logging

Match the existing `OSLog` convention. `Client.swift:6` already declares `Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "FolderStatus")`. Add a parallel `category: "StuckDeletes"` logger, used by the new controller for: detection events, sheet open/close, FDA-permission outcomes, deletion success/failure per path, rescan triggers.

---

## Phase 0 (Pre-fix) — Surface stuck-deletes in the popover

**Goal:** popover and icon agree with the WebUI on what's out-of-sync. No cleanup, no sheet, no FDA. Ships standalone as v1.5.6.

### Changes

**`Models.swift`** (~5 lines)

```swift
struct SyncthingFolderStatus: Codable, Equatable {
    // existing fields…
    let needFiles: Int
    let needBytes: Int64
    let needDeletes: Int          // NEW
    let needTotalItems: Int       // NEW (defensive — preferred when present)
    // …
}

// init(from:) — defensive decode, default 0
needDeletes    = (try? c.decode(Int.self, forKey: .needDeletes))    ?? 0
needTotalItems = (try? c.decode(Int.self, forKey: .needTotalItems)) ?? 0
```

Update memberwise init signature, demo-data builders (`Client.swift:1462-1476`), and the `Equatable` conformance (synthesised — fine).

Optionally also extend `SyncthingDeviceCompletion` (`Models.swift:105`) with `needDeletes: Int` for the secondary detection path. Free to add now since it's just decoding.

**`Helpers.swift`** (~5 lines)

```swift
extension SyncthingFolderStatus {
    /// Treats any pending work — adds, deletes, directory changes — as "needs sync".
    /// Falls back to summing the legacy fields if `needTotalItems` is 0 (older daemons
    /// or partial decoder paths).
    var hasPendingWork: Bool {
        needTotalItems > 0 || needFiles > 0 || needDeletes > 0 || needBytes > 0
    }
}
```

**`App.swift` — `StatusIconStateResolver`** (~6 lines)

Rule 6 (line 84-96) currently says:

```swift
let trulyOutOfSync = client.folderStatuses.values.contains { status in
    status.state == "idle"
        && status.needBytes > settings.syncRemainingBytesThreshold
}
```

Extend so a non-zero `needDeletes` qualifies even when bytes are zero:

```swift
let trulyOutOfSync = client.folderStatuses.values.contains { status in
    guard status.state == "idle" else { return false }
    if status.needBytes > settings.syncRemainingBytesThreshold { return true }
    if status.needDeletes > 0 { return true }
    return false
}
```

This preserves the threshold semantics for byte-pending desyncs (the existing rule from the 2026-04-28 decision) while catching delete-only desyncs cleanly.

**`Views.swift` — `FolderStatusRow.compactView`** (`Views.swift:1259-1263`)

```swift
// before:
if status.needFiles > 0 {
    Text("\(status.needFiles) items, \(formatBytes(status.needBytes))")…
} else {
    Text("Up to date")…
}
// after:
if status.hasPendingWork {
    Text(pendingSummary(status))
        .font(.caption2).foregroundColor(.orange)
} else {
    Text("Up to date")…
}

private func pendingSummary(_ s: SyncthingFolderStatus) -> String {
    var parts: [String] = []
    if s.needFiles > 0 { parts.append("\(s.needFiles) files") }
    if s.needDeletes > 0 { parts.append("\(s.needDeletes) deletes") }
    if s.needBytes > 0 { parts.append(formatBytes(s.needBytes)) }
    return parts.joined(separator: ", ")
}
```

Mirror change in `folderStatusLabel` (`Views.swift:1356-1366`) for the detailed view.

**Test plan for Phase 0**

- Reproduce the M4↔M1 stuck-delete scenario from the feature doc.
- Confirm:
  - WebUI shows folder "Out of Sync, N items".
  - Our popover row shows "N deletes" instead of "Up to date".
  - Menu-bar icon goes red (or amber in traffic mode if you decide to soften).
  - Resolver tooltip reads "Out of sync".
- Regression: a normal sync-pending folder still shows "X files, Y MB" — same as before.

---

## Phase 1 — Detection plumbing for the cleanup feature

**Goal:** add a debounced, per-folder "stuck-deletes detected" signal that the popover and the future cleanup sheet can both subscribe to.

### Changes

**`Client.swift` — new published property**

```swift
@Published var stuckDeleteCounts: [String: Int] = [:]   // folderID -> needDeletes (only when stuck)
private var firstSeenStuckAt: [String: Date] = [:]      // for the 30-second debounce
```

Updated by a private helper called from `fetchFolderStatus` *after* status updates. The fingerprint (per the design doc + research):

```swift
private func updateStuckDeletesSignal() {
    let now = Date()
    var newCounts: [String: Int] = [:]

    for folder in folders where !folder.paused {
        guard let s = folderStatuses[folder.id] else { continue }

        let isStuckPattern =
            s.state == "idle" &&
            s.needDeletes > 0 &&
            s.needFiles == 0 &&
            s.needBytes == 0
        // (state == idle AND deletes pending AND nothing else pending)

        if isStuckPattern {
            // 30-second debounce
            let firstSeen = firstSeenStuckAt[folder.id] ?? now
            if firstSeenStuckAt[folder.id] == nil { firstSeenStuckAt[folder.id] = now }
            if now.timeIntervalSince(firstSeen) >= 30 {
                newCounts[folder.id] = s.needDeletes
            }
        } else {
            firstSeenStuckAt.removeValue(forKey: folder.id)
        }
    }
    stuckDeleteCounts = newCounts
}
```

Notes:
- Debounce avoids flapping when Syncthing transitions through `cleaning` and `idle` quickly during a normal sync.
- Folder-state filter excludes `scanning`, `syncing`, `cleaning`, etc. — we only badge once Syncthing is at rest and still has unflushed deletes.
- `paused` folders are excluded by design.
- `receive-only` folders are *not yet* excluded here — they need the folder's `type` field, which currently isn't on `SyncthingFolder`. See "Risks" below.

**Settings respect**

```swift
guard settings.stuckDeletesAlertsEnabled else {
    stuckDeleteCounts = [:]
    return
}
```

placed at the top of `updateStuckDeletesSignal`.

---

## Phase 2 — Popover alert row

**Goal:** when `stuckDeleteCounts` is non-empty, show a top-of-popover row that the user can click to open the cleanup window. Stays out of the way otherwise.

### Changes

**`Views.swift` — new component** (above `FolderSyncStatusView`, ~50 lines)

```swift
struct StuckDeletesAlertRow: View {
    @ObservedObject var syncthingClient: SyncthingClient
    let onResolve: (SyncthingFolder) -> Void  // routed via AppDelegate to open the window

    var body: some View {
        let affected = syncthingClient.folders.filter {
            (syncthingClient.stuckDeleteCounts[$0.id] ?? 0) > 0
        }
        if !affected.isEmpty {
            VStack(spacing: AppConstants.UI.spacingS) {
                ForEach(affected) { folder in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(folder.label.isEmpty ? folder.id : folder.label)")
                                .fontWeight(.medium)
                            Text("\(syncthingClient.stuckDeleteCounts[folder.id] ?? 0) stuck deletions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Resolve…") { onResolve(folder) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(AppConstants.UI.paddingS)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}
```

**`Views.swift` — `ContentView`** (line 53, inside the `statusContent` VStack)

```swift
let statusContent = VStack(spacing: AppConstants.UI.spacingXL) {
    StuckDeletesAlertRow(syncthingClient: syncthingClient,
                         onResolve: { folder in
                             appDelegate.openStuckDeletesWindow(for: folder)
                         })
    if let status = syncthingClient.systemStatus { … }
    // …
}
```

**`AppDelegate`** gets a new `openStuckDeletesWindow(for: SyncthingFolder)` that mirrors `openMainWindow` but constructs `StuckDeletesWindowController` with the bound folder.

**Critical: existing `ContentHeightKey` / popover-sizing behaviour must not regress.** The comment block at `Views.swift:14-24` is explicit that adding conditionals to the preference reduce will break popover sizing. The new alert row is a sibling view inside the same `statusContent` VStack — it inherits the existing height-measurement path. Verify by toggling the row in/out and watching that the popover resizes smoothly.

---

## Phase 3 — Cleanup window UI

**Goal:** dedicated window (not a popover sheet) with checkboxes-default-off and explicit confirm step. Style matches the codebase's `GroupBox`-driven look.

### New file: `01_Project/syncthingStatus/StuckDeletes/StuckDeletesView.swift` (~120 lines)

Sketch:

```swift
struct StuckDeletesView: View {
    @ObservedObject var controller: StuckDeletesController
    let folder: SyncthingFolder
    @State private var selection = Set<String>()       // RemoteNeedItem.id
    @State private var confirming = false
    @State private var working = false
    @State private var result: StuckDeletesController.Outcome?

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.spacingL) {
            header
            explanation
            list
            footer
        }
        .padding(AppConstants.UI.paddingM)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 380, idealHeight: 480)
        .task { await controller.loadCandidates(for: folder) }
        .confirmationDialog(
            "Permanently delete \(selection.count) folder\(selection.count == 1 ? "" : "s")?",
            isPresented: $confirming
        ) {
            Button("Delete", role: .destructive) { Task { await runDeletion() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the folders and their contents — including any ignored files (.git, .build, etc.). This cannot be undone.")
        }
    }

    // list uses Toggle bindings into `selection`; "Delete N selected" disabled
    // until !selection.isEmpty && !working.
}
```

Safety mirrors the design doc:
- No "Select all" button.
- Default selection empty.
- Per-row subtitle: "N ignored files inside (.git, .build, …)" — computed lazily by `FileManager.enumerator` on a background actor when the row appears (inexpensive for tens of dirs; bounded by `fileLimit` to avoid pathological deep trees).
- Per-row "Reveal in Finder" button.
- Confirm dialog before destruction.
- After deletion, results panel listing per-path success/failure.

### New file: `StuckDeletesController.swift` (~140 lines)

```swift
@MainActor
final class StuckDeletesController: ObservableObject {
    @Published var candidates: [RemoteNeedItem] = []
    @Published var loading = false
    @Published var lastError: String?

    private let client: SyncthingClient
    private let log = Logger(subsystem: "com.lucesumbrarum.syncthingStatus",
                             category: "StuckDeletes")

    func loadCandidates(for folder: SyncthingFolder) async {
        // GET /rest/db/need?folder=X&perpage=1000
        // Merge progress + queued + rest, filter (deleted == true && type ends with DIRECTORY)
    }

    func performDeletion(folder: SyncthingFolder, selected: [RemoteNeedItem]) async -> Outcome {
        // 1. Validate paths (reject "..", absolute, null bytes)
        // 2. Pre-check FDA via contentsOfDirectory probe
        // 3. For each path: removeItem (or unlink-only if symlink)
        // 4. Trigger /rest/db/scan?folder=X
        // 5. Poll /rest/db/status until needDeletes drops to 0 or 30s timeout
    }

    struct Outcome { let succeeded: [String], failed: [(String, String)] }
}
```

### New file: `RemoteNeedItem.swift` (~30 lines)

```swift
struct RemoteNeedItem: Decodable, Identifiable, Equatable {
    let name: String
    let deleted: Bool
    let type: String
    var id: String { name }
    var isDirectory: Bool { type.hasSuffix("DIRECTORY") }
}

struct DbNeedResponse: Decodable {
    let progress: [RemoteNeedItem]
    let queued: [RemoteNeedItem]
    let rest: [RemoteNeedItem]
    var allItems: [RemoteNeedItem] { progress + queued + rest }
}
```

Defensive decode: if Syncthing changes field names again, missing fields default to safe values (`deleted = false`, `type = ""`). Items with empty `type` get filtered out — cannot be misidentified as deletable directories.

### `Client.swift` additions (~25 lines)

```swift
func fetchDbNeed(folder: String) async throws -> DbNeedResponse {
    return try await makeRequest(
        path: "db/need",
        queryItems: [URLQueryItem(name: "folder", value: folder),
                     URLQueryItem(name: "perpage", value: "1000")],
        responseType: DbNeedResponse.self
    )
}

func rescan(folder: String) async throws {
    try await postRequest(
        path: "db/scan",
        queryItems: [URLQueryItem(name: "folder", value: folder)]
    )
}
```

Both use the existing query-item infrastructure (`Client.swift:388, 434`).

---

## Phase 4 — Permissions

App is unsandboxed (`syncthingStatus.entitlements` is `<dict/>`). On macOS 15+ this still requires Full Disk Access for `~/Documents`, `~/Desktop`, `~/Downloads`, and arbitrary external volumes (TCC-protected, not sandbox-protected).

### Pre-flight check (before showing the destructive button)

```swift
func canAccess(_ folder: SyncthingFolder) -> Bool {
    do { _ = try FileManager.default.contentsOfDirectory(atPath: folder.path); return true }
    catch let e as NSError where e.code == NSFileReadNoPermissionError { return false }
    catch { return false }
}
```

Run on first sheet-open; if false, render the permission gate inline (instead of the candidates list), with a button:

```swift
NSWorkspace.shared.open(URL(string:
  "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
)!)
```

Plus a "I've granted access — try again" button that re-runs the probe. Note: the FDA grant only affects newly-launched processes, so a second alert may be needed: *"Quit and relaunch syncthingStatus to apply the new permission."*

### Defence-in-depth path validation

Before calling `removeItem(at:)`:

1. Reject `name` if it contains `..`, has a leading `/`, contains null bytes, or after normalisation escapes the folder root.
2. Resolve to absolute path: `URL(fileURLWithPath: folder.path).appendingPathComponent(item.name, isDirectory: true)`.
3. `realpath`-equivalent: `URL(fileURLWithPath: …).resolvingSymlinksInPath()` and verify the result is still under `folder.path`.
4. Symlink check: `attributesOfItem(atPath:)[.type] == .typeSymbolicLink` → unlink only, don't recurse.

Log every rejection at `.error` level with the original path. A hostile/corrupted Syncthing index should never be able to make us delete `/`.

---

## Phase 5 — Settings + observability

### `Constants.swift`

Extend `enum Sync` with:
```swift
static let stuckDeletesDebounceSeconds: TimeInterval = 30.0
static let stuckDeletesScanWaitSeconds: TimeInterval = 30.0   // post-deletion poll timeout
```

### `SyncthingSettings.swift`

Single new toggle `stuckDeletesAlertsEnabled` (default true). Hooked into the existing `setupAutoSave` / `persistAllDefaults` / `resetToDefaults`. UserDefaults key follows the `SyncthingSettings.…` prefix.

### `SettingsView.swift`

Add a row under "Notifications" (around `SyncthingSettings.swift` settings UI in `Views.swift:1438+`):

```
Toggle("Detect stuck deletions", isOn: $settings.stuckDeletesAlertsEnabled)
Text("Show an alert when Syncthing is unable to delete folders that contain ignored files.")
    .font(.caption).foregroundColor(.secondary)
```

### Logging

`Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "StuckDeletes")`. Emit:

- `info`: detection enter/exit per folder (with `needDeletes` count).
- `info`: sheet open with folder ID, candidate count.
- `error`: API failure, FDA failure, path validation rejection (with sanitized path).
- `notice`: deletion success per path; `error` per failure.
- `info`: rescan triggered, completion, or 30-s timeout reached.

---

## Risks and known unknowns

1. **`db/need` field names not in official docs.** We rely on observed `deleted` and `type`. Mitigation: defensive decode, plus a fallback "if no items decode as directories, show a 'no candidates found' state with a link to the WebUI" so a future field rename degrades to a no-op rather than a wrong-cleanup risk.

2. **`receive-only` folder type isn't in our `SyncthingFolder` model.** The design doc says we should suppress the cleanup for `receiveonly` folders. Need to add `type: String` to `SyncthingFolder` (free decode from `system/config`) and check `folder.type == "receiveencrypted"` / `"receiveonly"`. ~3 LOC. Skipping this would risk offering destructive cleanup on a folder where Syncthing's own Override/Revert is the right answer.

3. **Path normalisation on macOS HFS+/APFS unicode.** Syncthing returns NFC-normalised filenames; macOS filesystems use NFD. `FileManager.removeItem(at:)` handles this transparently in modern macOS, but `Set<String>` / equality checks need care. Use `URL` comparisons (already correct after normalisation) rather than string equality.

4. **The 30-second debounce can hide a fast-cycling stuck-delete.** If Syncthing churns through `cleaning → idle → cleaning` repeatedly because of *another* problem (not stuck deletes), we'll never badge. That's preferable to the false-positive case, but worth documenting.

5. **Popover sizing regressions.** The `ContentHeightKey` reducer at `Views.swift:18-24` is explicitly fragile per the in-file comment. Inserting a conditionally-visible alert row above `SystemStatusView` is the safest addition (sibling, not parent), but verify by toggling demo-mode states.

6. **Concurrent deletion races.** If Syncthing receives a delete completion notification between our `db/status` read and our `removeItem` call, our deletion might race against Syncthing's own cleanup. Outcome is benign (one of them succeeds, the other gets `ENOENT`), but log clearly.

7. **macOS 15.5 deployment target.** All APIs used (NSWindow, FileManager, async/await, URL bookmarks) are available pre-15. No new platform requirements.

---

## Recommended order of work

1. **Phase 0 (pre-fix)** — single PR, ~30 LOC. Fixes the user's actual headline complaint. Ship as v1.5.6 or roll into v1.6.
2. **Phase 1 (detection plumbing)** — ~40 LOC. No user-visible change yet (can be guarded by feature flag).
3. **Phase 2 (alert row)** — ~50 LOC. User-visible "Resolve…" button is wired but the button just logs.
4. **Phase 3 (window + sheet UI)** — ~250 LOC. Read-only listing first, no destructive actions yet.
5. **Phase 4 (permissions + deletion)** — ~80 LOC. Add the actual `removeItem` + rescan after manual end-to-end test on the real failure scenario.
6. **Phase 5 (settings toggle, logging polish)** — ~30 LOC.
7. **Phase 6 (testing checklist from feature doc)** — full reproduce-and-verify pass, then ship.

Total: ~480 LOC, of which ~30 are shippable in isolation. Estimate is ~2× the design doc's 250 LOC because we're including the model fix (was implicit), the receive-only filter (was missed), and the FDA gating logic (was sketched).

---

## What I'm not planning to do

- **Auto-delete.** Per the feature doc's explicit non-goal. No setting, no opt-in.
- **Bulk-process across folders.** One window per folder; users with multiple affected folders see multiple alert rows.
- **File-level (non-directory) stuck deletes.** Filter is `isDirectory == true` for v1; file-level usually indicates a different problem (locked file, permission denied) and merits a separate diagnostic.
- **Syncthing-side `Override`/`Revert` integration.** Out of scope — different problem class (receive-only folders), different fix.
- **Scheduled/background deletion.** All deletions are user-initiated in the foreground.

---

*Plan drafted 2026-04-29. Update as implementation reveals constraints.*
