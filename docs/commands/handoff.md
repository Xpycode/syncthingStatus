# Generate Handoff Document

Create a comprehensive handoff document for continuing work in a future session.

## What to Read

1. `docs/PROJECT_STATE.md` - Current state
2. Today's session log in `docs/sessions/` (if exists)
3. `docs/decisions.md` - Recent decisions
4. Any files modified in this session (from git status)

## Step 1: Gather Information

Ask the user:
1. "What was accomplished this session?" (or read from session log)
2. "What's the next task to work on?"
3. "Any gotchas or context the next session should know?"

## Step 2: Generate Handoff

Create `docs/sessions/handoff-YYYY-MM-DD.md` with:

```markdown
# Handoff: YYYY-MM-DD

## Session Summary
[What was accomplished]

## Current State
- **Phase:** [from PROJECT_STATE.md]
- **Focus:** [from PROJECT_STATE.md]
- **Blockers:** [from PROJECT_STATE.md]

## Files Changed
- [list of modified files from git status]

## Recent Decisions
- [last 2-3 decisions]

## Next Steps
1. [Primary next task]
2. [Secondary tasks]

## Context for Next Session
[Any gotchas, warnings, or important context]

## How to Continue
Start with: "Read docs/sessions/handoff-YYYY-MM-DD.md and continue from where we left off"
```

## Step 3: Confirm

Display: "Handoff saved to docs/sessions/handoff-YYYY-MM-DD.md"

Show the "How to Continue" instruction for easy copy-paste.
