<!--
TRIGGERS: planning, task tracking, persistent memory, context management, long task, multi-session
PHASE: planning
LOAD: on-request
-->

# Planning Patterns for Complex Tasks

**Using the filesystem as persistent memory.**

*Based on the planning-with-files methodology for AI-assisted development.*

---

## The Problem

AI agents face challenges with complex tasks:

| Challenge | Symptom |
|-----------|---------|
| **Volatile memory** | Forgets context between sessions |
| **Goal drift** | Loses focus after many tool calls |
| **Untracked errors** | Repeats the same mistakes |
| **Context bloat** | Conversation gets too long |

---

## The Solution: Files as Memory

Treat the filesystem as "disk storage" - persistent, reliable, always there.

The Directions system uses:

| File | Purpose | When Updated |
|------|---------|--------------|
| `PROJECT_STATE.md` | Current phase, focus, blockers | Every session |
| `decisions.md` | Why we chose X over Y | When decisions are made |
| `sessions/_index.md` | Session history | Start/end of sessions |
| `sessions/YYYY-MM-DD.md` | Detailed session log | During sessions |

---

## Key Patterns

### Pattern 1: The 2-Action Rule

After every 2 significant actions, update the relevant file.

**Why:** Prevents losing work if context resets.

```
Action 1: Explored codebase structure
Action 2: Found the authentication module
→ UPDATE findings in session log

Action 3: Read auth module code
Action 4: Identified the bug location
→ UPDATE session log with findings
```

### Pattern 2: Pre-Decision Re-Reading

Before making significant decisions, re-read the plan.

**Why:** Prevents drift from original goals.

```
"Before we implement this, let me check PROJECT_STATE.md
to make sure this aligns with our current focus."
```

### Pattern 3: Error Logging

When something fails, log it immediately.

**Why:** Prevents repeating the same mistake.

```markdown
## Errors Encountered

### [Date] - Build failed with SwiftUI preview error
**Attempted:** Running preview with async init
**Error:** "Preview crashed"
**Solution:** Move async work out of init
**Don't repeat:** Never put async calls in SwiftUI init
```

### Pattern 4: Completion Verification

Before declaring "done", verify against the original goal.

**Why:** Prevents premature completion.

```
"Let me check PROJECT_STATE.md - our goal was [X].
Did we actually achieve [X], not just something close to it?"
```

### Pattern 5: Session Handoff

End each session with clear next steps.

**Why:** Future sessions (or future Claude) can pick up immediately.

```markdown
## Next Session Should

1. Start by reading this session's blockers
2. Focus on: [specific task]
3. Don't forget: [important context]
```

---

## Integrating with Directions

The Directions system already has these files. Use them:

### Starting a Session

```
1. Read PROJECT_STATE.md - what phase are we in?
2. Read sessions/_index.md - what happened last time?
3. Read the latest session log - any blockers?
4. Read decisions.md if making architectural choices
```

### During a Session

```
1. Update session log after significant progress
2. Log decisions immediately when made
3. Note any errors or blockers
4. Keep PROJECT_STATE.md current phase accurate
```

### Ending a Session

```
1. Summarize what was accomplished
2. Document any blockers
3. Write clear "Next Session" section
4. Update PROJECT_STATE.md if phase changed
```

---

## When to Use Heavy Planning

Not every task needs full planning rigor.

| Task Type | Planning Level |
|-----------|---------------|
| Quick fix (< 30 min) | Just do it, commit |
| Single feature (< 2 hours) | Light notes in session log |
| Multi-session feature | Full planning discipline |
| Architecture changes | Full planning + decisions.md |
| New project | Full setup of all files |

---

## Claude Instructions for Planning

Add to your prompts or CLAUDE.md:

```markdown
## Planning Discipline

For complex tasks:
1. Check PROJECT_STATE.md before starting
2. Update session log every 2-3 actions
3. Log decisions immediately to decisions.md
4. End sessions with clear handoff notes
5. Verify completion against original goals
```

---

## The Payoff

With disciplined file-based planning:

- ✅ Sessions pick up where they left off
- ✅ Decisions are documented and don't get re-debated
- ✅ Errors don't repeat
- ✅ Complex multi-session tasks complete successfully
- ✅ Future-you understands past-you's reasoning

---

*The filesystem is your persistent memory. Use it.*
