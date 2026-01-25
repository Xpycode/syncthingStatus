# Context Management

How to prevent quality degradation during long sessions.

## The Problem: Context Rot

As Claude's context window fills up, quality degrades:
- Earlier instructions get "forgotten"
- Responses become less precise
- Code quality drops
- Repetition increases

This guide combines Directions' project memory with execution patterns from [Get Shit Done](https://github.com/glittercowboy/get-shit-done).

## Core Principles

### 1. File Size Limits

Every file has a purpose and a size constraint:

| File | Purpose | Limit |
|------|---------|-------|
| `PROJECT_STATE.md` | Current position | <80 lines |
| `PLAN.md` | Active execution | Delete when done |
| `RESUME.md` | Session bridge | Delete after use |
| Session logs | Daily record | ~200 lines |
| `decisions.md` | Decision history | Grows (but summarize in PROJECT_STATE) |

**Why?** Small, focused files = fast context loading = better quality.

### 2. Temporary vs Permanent Files

**Permanent (project memory):**
- `PROJECT_STATE.md` - source of truth for position
- `decisions.md` - architectural history
- `sessions/*.md` - daily logs
- `CLAUDE.md` - project instructions

**Temporary (execution artifacts):**
- `PLAN.md` - delete after execution completes
- `RESUME.md` - delete after resuming

Temporary files prevent stale context from accumulating.

### 3. Orchestrator Pattern

The main conversation should never exceed 40% context.

```
Main Context (orchestrator)
├── Reads PROJECT_STATE.md, PLAN.md
├── Spawns subagents for heavy work
├── Collects results
├── Updates state files
└── Never does implementation directly

Subagent (fresh context)
├── Receives only: task description, target files, success criteria
├── No session history
├── Does one atomic task
├── Returns result
└── Context discarded
```

### 4. Wave-Based Execution

Group tasks by dependency, execute in waves:

```
Wave 1: [A] [B] [C]  ← parallel, independent
         ↓ complete
Wave 2: [D] [E]      ← depend on Wave 1
         ↓ complete
Wave 3: [F]          ← verification
```

Each task in a wave runs in a fresh subagent context.

## The Hybrid Workflow

### For Discovery/Planning (Directions-style)
1. `/interview` - gather requirements
2. `/decide` - record decisions
3. `/log` - track sessions
4. `PROJECT_STATE.md` - maintain position

### For Implementation (GSD-style)
1. Create `PLAN.md` with waves and tasks
2. `/execute` - run wave-based execution
3. Subagents do heavy lifting with fresh contexts
4. Atomic commits per task
5. Delete `PLAN.md` when done

### For Session Handoff
1. Create `RESUME.md` with exact next step
2. Update `PROJECT_STATE.md`
3. New session reads `RESUME.md` first
4. Delete `RESUME.md` after resuming

## Practical Commands

### Starting a Session
```
1. Read PROJECT_STATE.md (current position)
2. Check for RESUME.md (if exists, that's your starting point)
3. Read latest session log (recent context)
```

### Ending a Session Mid-Task
```
1. Create RESUME.md with exact next action
2. Update PROJECT_STATE.md status
3. Commit any work in progress
```

### Implementing a Feature
```
1. Create PLAN.md with tasks grouped into waves
2. Run /execute
3. Subagents execute each task with fresh context
4. Each task = one atomic commit
5. Delete PLAN.md when complete
6. Update PROJECT_STATE.md
```

### Context Getting Full
```
1. Create RESUME.md with current state
2. Complete current task if possible
3. Commit work
4. Tell user: "Context is full. Run /execute to continue with fresh agents."
```

## Anti-Patterns

**Don't:**
- Keep PLAN.md or RESUME.md after they're used
- Put implementation details in PROJECT_STATE.md
- Let session logs grow beyond ~200 lines
- Do heavy implementation in the main context
- Accumulate "just in case" context

**Do:**
- Delete temporary files aggressively
- Summarize, don't duplicate
- Spawn subagents for implementation
- Keep orchestrator context light
- Trust the file system as memory

## Quick Reference

```
Context Full?
├── Mid-task → RESUME.md → fresh session
├── Between tasks → commit, update PROJECT_STATE.md
└── During /execute → wave completes, next wave in fresh agent

Starting Session?
├── RESUME.md exists → read it, delete it, continue
├── No RESUME.md → read PROJECT_STATE.md, latest session log
└── /execute in progress → continue from PLAN.md state

Ending Session?
├── Clean stop → update PROJECT_STATE.md, /log
├── Mid-task → create RESUME.md with exact next step
└── Emergency → at minimum update PROJECT_STATE.md
```

## Credits

Context management patterns adapted from [Get Shit Done](https://github.com/glittercowboy/get-shit-done) by glittercowboy. Integrated with Directions' project memory system.
