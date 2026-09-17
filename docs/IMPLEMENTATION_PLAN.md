# Active plan — review fixes

Status: queued for the next session by the user on 2026-09-05. No application fixes have started. Evidence and the remaining ranked queue live in the [review](reviews/2026-09-05-usability-code-review.md) and [Tasks](TASKS.md).

## First: cleanup target identity

The access picker accepts the configured folder or an ancestor. The probe returns the saved bookmark URL as the deletion root. A relative candidate can therefore delete a sibling of the configured folder, or data under an old root after a configured path change. This is the active release blocker.

1. Start a local fix branch from current main. Inspect `Client.swift:1886` (`grantAccess`), `1969` (`probeFolderAccess`), `2069` (`performDeletion`), and `2184` (`validatePath`), plus bookmark persistence and the cleanup confirmation view.
2. Preserve the distinction between the URL granting filesystem access and the current configured Syncthing folder root. Revalidate the folder ID/path and access relationship before destructive work, including already-open cleanup windows. Resolve candidate paths only beneath the configured root; reject unrelated or obsolete grants.
3. Add focused tests against the actual production implementation. The frozen review harnesses explain the defect but cannot verify a fix to code they copied.
4. Independently review the destructive path, then build and inspect the access/confirmation flow with disposable fixtures. Follow the standing fresh-build launch preference. Keep App Sandbox enabled.

Acceptance checks:

- [ ] Exact-root grant removes only the selected fixture candidate.
- [ ] Ancestor grant targets `Sync/Project/candidate` and preserves `Sync/candidate`.
- [ ] A changed configured path with an old bookmark cannot delete under the old root.
- [ ] An already-open cleanup window cannot act on obsolete folder identity/path data.
- [ ] Absolute paths, traversal, and symlink escapes remain rejected; folder root itself cannot be deleted.
- [ ] Missing/revoked access remains actionable and causes no deletion; already-gone items retain intended idempotence.
- [ ] Permanent-delete confirmation names the affected root and selected items sufficiently to review the action.

## Then

Address shared status semantics and refresh ownership, then notification selection and direct connection recovery. Continue through the confirmed backlog in priority order; reproduce Inbox observations before treating them as defects. Tests should exercise actual production behavior and failure paths. Do not combine the safety fix with a broad UI/framework rewrite.

Run `/check ship` before a new public release. A successful review-time Debug build is not release approval. No release was requested during this handoff.

Model fit: deep capability + high reasoning for destructive-path identity and concurrency, with bounded independent validation delegated to smaller agents.
