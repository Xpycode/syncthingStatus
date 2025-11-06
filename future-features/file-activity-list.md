## File Activity & Event History Ideas

### Overview
Leverage Syncthing's events API (e.g. `/rest/events?events=ItemFinished,ItemStarted`) to expose recent file activity inside the app. This can evolve from a simple list of the last N items to richer tooling for audits, notifications, and quick actions.

### Potential Features

1. **Recent File List**
   - Show the latest synced files with timestamp, folder, device, direction (download/upload), and size.
   - Allow filtering by folder/device.
   - Offer quick actions (Reveal in Finder, copy path, open with default app).

2. **Per-Folder Activity Panels**
   - Within each folder's detail view, add a collapsible panel with recent file changes.
   - Highlight in-progress transfers, show completion percentage for large batches.

3. **Notification Hooks**
   - Let users subscribe to activity notifications for specific folders or file patterns.
   - Example: alert when a shared "Drop" folder receives new files.

4. **Audit / History Export**
   - Provide a button to copy or export the recent activity log (useful when troubleshooting).
   - Store a limited rolling buffer (e.g., 200 events) in memory with persistence optional.

5. **Search & Filtering**
   - Add a search bar to filter recent events by filename or extension.
   - Quick toggles for event types (Created, Updated, Deleted, Renamed).

6. **Device Activity Health**
   - Summaries per device: last file synced, last event timestamp, outstanding items.
   - Visual cues for devices that haven't synced recently.

7. **Menu Bar Insights**
   - Provide a truncated "Recent Activity" list in the menu bar popover for quick glance.
   - Configurable (show last 3 events, with an option to open full activity window).

### Implementation Notes

- Events endpoint supports incremental polling with `since` to avoid missing entries.
- Need to handle event backlog on first launch (consider limiting initial load).
- Combine event processing with existing Combine publishers for UI updates.
- Consider debouncing UI refresh to avoid overwhelming SwiftUI when many events arrive.
- Permissions: no extra sandbox entitlements required (pure network/API).

