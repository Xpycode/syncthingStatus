# Review evidence — 2026-09-05

Host: M1-Max; Xcode 26.6. These are frozen reproductions of the reviewed source, not production code or a regression suite for future fixes. The status harness compiles the repository's Models.swift and uses stub transport/state dependencies; the deletion harnesses extract the path validator and model the source-verified bookmark-root handoff, without exercising the complete sandbox/open-panel flow.

The paired text files preserve the observed outputs. The notification output is a direct comparison of the UI/runtime predicates, not an end-to-end notification test. No live daemon writes or user-data deletions were performed.

The two deletion harnesses create and remove only their fixed fixture directories under `/private/tmp/syncthingStatus-review-evidence`. Inspect those fixture paths before rerunning; use disposable data only. The binaries and module caches are intentionally not versioned.

Run from the project root (outputs remain outside the repository):

```sh
mkdir -p /private/tmp/syncthingStatus-review-evidence
swiftc -module-cache-path /private/tmp/syncthingStatus-review-module-cache docs/reviews/evidence/2026-09-05/AncestorRootHarness.swift -o /private/tmp/syncthingStatus-review-evidence/ancestor-root-harness
/private/tmp/syncthingStatus-review-evidence/ancestor-root-harness
swiftc -module-cache-path /private/tmp/syncthingStatus-review-module-cache docs/reviews/evidence/2026-09-05/StaleRootHarness.swift -o /private/tmp/syncthingStatus-review-evidence/stale-root-harness
/private/tmp/syncthingStatus-review-evidence/stale-root-harness
swiftc -parse-as-library -module-cache-path /private/tmp/syncthingStatus-review-module-cache 01_Project/syncthingStatus/Models.swift docs/reviews/evidence/2026-09-05/status-refresh-harness.swift -o /private/tmp/syncthingStatus-review-evidence/status-refresh-harness
/private/tmp/syncthingStatus-review-evidence/status-refresh-harness
```

A successful reproduction demonstrates the old defect. For the fix, write tests against the actual corrected production methods, covering both rejection and intended-success paths.
