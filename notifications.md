# Notifications Ideas

## Overview

Feature goal: extend the app’s notification system beyond the current “folder finished syncing” alerts so users stay informed about meaningful state changes (pause/resume, file activity, etc.) without living in the app.

## Events To Cover

1. **Pause/Resume Actions**
   - Trigger when the user pauses or resumes a folder or all devices.
   - Include folder/device name, action taken, and a reminder on how to undo.

2. **Sync Completion (Enhanced)**
   - Current implementation notifies per folder; add batching when multiple folders finish together.
   - Provide the sync duration and remaining files/bytes (if any) in the payload.

3. **File Activity**
   - Surface “N files added/removed/modified” per folder since the last refresh.
   - Cap at a reasonable number and offer a “View details…” action that opens the history view.

4. **Stalled Sync Detection**
   - Alert if a folder/device stays in “syncing” for > configurable minutes without progress.
   - Suggested payload: folder/device name, last activity timestamp, quick link to resume/inspect.

5. **Syncthing Service Events**
   - Restart detected, API unavailable, or authentication errors.
   - Focus on actionable guidance (“Syncthing restarted; refreshing status…”, “API key rejected—check Settings”).

## Implementation Notes

- Reuse `UNUserNotificationCenter` with categorised identifiers so notifications can be batched or replaced.
- Maintain a lightweight in-memory diff between refreshes (e.g. track last-known paused state, per-folder file counts, event timestamps) inside `SyncthingClient`.
- Add toggles in Settings for each notification category to avoid spamming users.
- Consider a “Do Not Disturb” window (e.g. overnight mute) for power users.

## Next Steps (post-restart)

1. Map existing `SyncthingClient` state to the events above; identify gaps in data we need (file deltas, sync start timestamps).
2. Prototype pause/resume notifications first—they rely only on state we already track.
3. Add settings toggles and ensure we request notification permissions up front.
4. Iterate on richer events (file activity, stalled sync) once the data pipeline is reliable.
