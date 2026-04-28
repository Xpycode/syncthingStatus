# Next Task

Pick the next task from IMPLEMENTATION_PLAN.md with full context.

## Process

### Step 1: Read Current State

1. Read `IMPLEMENTATION_PLAN.md`
2. Read `PROJECT_STATE.md`
3. Check git status for uncommitted work

### Step 2: Find Next Task

Priority order:
1. **Uncommitted work** - Finish what's started
2. **Current wave incomplete** - Next unchecked task in active wave
3. **Wave complete** - Move to next wave
4. **All waves done** - Run verification wave

### Step 3: Present Task

```
## Next: Task [N.M]

**Description:** [Task description]
**Target:** `[file path]`
**Success:** [What done looks like]
**Backpressure:** [Validation command]

**Dependencies:** [List if any, or "None - can start immediately"]

**Context needed:**
- [File to read for context]
- [Relevant spec section]

Ready to start?
```

### Step 4: On Confirmation

1. Update PROJECT_STATE.md focus to this task
2. Mark task as in-progress (if tracking)
3. Begin implementation

### Step 5: On Completion

1. Run backpressure command
2. If passes: commit, mark task [x], run `/next` again
3. If fails: fix, rerun backpressure, repeat

## Blocked Handling

If next task is blocked:

```
## Blocked: Task [N.M]

**Blocker:** [Description of what's blocking]
**Workaround attempts:** [What we tried]

Options:
1. Resolve blocker first
2. Skip to next unblocked task
3. Ask user for guidance

Which approach?
```

## Wave Transitions

When completing a wave:

```
## Wave [N] Complete

Tasks completed: [list]
Commits: [commit hashes]

Wave [N+1] is now unblocked:
- Task [N+1.1]: [description]
- Task [N+1.2]: [description]

Proceed to Wave [N+1]?
```

## Quick Reference

| Command | Result |
|---------|--------|
| `/next` | Show next task |
| `/next skip` | Skip current, show next unblocked |
| `/next wave` | Show wave summary |
| `/next done` | Mark current task complete |

---
*One task at a time. Full context. Clean commits.*
