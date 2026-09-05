# Wave 2 production status-row UI fixture

This disposable native harness extracts the current production `FolderStatusRow`, `DeviceStatusRow`, and their direct helper views from `Views.swift`, then compiles them with the real client, models, status policy, presentation, and settings implementation. `production-source-hashes.json` ties each run to the exact production source inspected.

The fixture uses `SettingsFixture` and `HTTPFixture` from the hostless test target. Its unique defaults suite, in-memory credential/login seams, ephemeral URL session, `.invalid` host, URL protocol interception, and captured notification closure isolate it from real preferences, Keychain, login items, notifications, and network. Its unique bundle ID is `com.lucesumbrarum.syncthingStatus.status-ui-fixture-20260906`; it does not launch the production application or reuse its container. The only entitlement is App Sandbox, preserved from the signed bundle in `signed-entitlements.plist`.

Four folder scenarios and five device scenarios load through a real `SyncthingClient.refresh()`: idle/complete, pending deletes, latest status failure, paused, and an offline peer. Separate windows render the production rows in compact and detailed modes. They also wrap the exact production `Sync Completion` Settings section in a small fixture form. The runner preserves AX trees and attempts window screenshots, checks that the expected status terms are present, and confirms zero unexpected HTTP and notification deliveries.

The icon check exercises the exact production resolver and `iconState(for:)` mapping. It verifies unavailable maps to Warning in both styles, while soft warnings and paused states map to Warning in Traffic-Light and Normal in Monochrome. A second real client performs a failed config fetch and verifies the distinct `Configuration unavailable` outcome. The check covers semantic mapping and accessibility text, not the final menu-bar PNG pixels; the fixture does not instantiate a second status item or copy production resources.

Run outside a restricted tool sandbox because native application launch, Accessibility inspection, and `screencapture` require the logged-in GUI session:

```sh
python3 docs/reviews/evidence/2026-09-06/status-ui/run-checks.py
```

Generated bundle, compiler cache, and AX helper stay under `/private/tmp/syncthingStatus-status-ui-probe`. Preserved evidence in this directory consists of extracted source, hashes, AX JSON, screenshots when available, and `results.txt`.

## Final result

Final replay on 2026-09-06 passed. Compact and detailed windows produced 82 and 72 AX nodes respectively; all expected scenario/status text and the production Sync Completion explanation were present. Both screenshots were captured. Unavailable status mapped to Warning in both icon styles; soft warning and paused mapped to Warning in Traffic-Light and Normal in Monochrome. The separate failed-config client resolved to `Configuration unavailable`.

The pending-delete folder rendered `Out of sync` with `4 deletes`. The pending-delete peer rendered `Syncing (100%)` with `4 deletes`, confirming that a 100% byte percentage with deletion work no longer claims `Up to date`. Both runs closed with zero unexpected HTTP requests and zero notification deliveries. Every production hash matched immediately after the replay.
