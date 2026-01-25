# Show Project Context

Display a concise summary of the current project state.

## What to Read

1. `docs/PROJECT_STATE.md` - Current phase, focus, blockers
2. `docs/sessions/_index.md` - Last 3 sessions (or latest 3 session files)
3. `docs/decisions.md` - Last 3 decisions

## Output Format

```
## Project Context

**Phase:** [current phase]
**Focus:** [current focus]

### Blockers
- [blocker 1]
- [blocker 2]
(or "None" if no blockers)

### Recent Sessions
- YYYY-MM-DD: [brief summary]
- YYYY-MM-DD: [brief summary]
- YYYY-MM-DD: [brief summary]

### Recent Decisions
- YYYY-MM-DD: [decision title]
- YYYY-MM-DD: [decision title]
- YYYY-MM-DD: [decision title]
```

## Notes

- Keep summaries brief (one line each)
- If files don't exist, note "Not found" for that section
- This is a read-only command - it doesn't modify anything
