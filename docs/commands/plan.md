# Planning Mode

Enter planning mode to create or update IMPLEMENTATION_PLAN.md.

## When to Use

- Starting a new feature
- IMPLEMENTATION_PLAN.md doesn't exist or is stale
- Trajectory has diverged significantly from plan

## Process

### Step 1: Scope (Define the Goal)

Ask the user:
> "What are we building? One sentence is fine."

If they have a spec already, read it. If not, run a quick interview:
- What's the core functionality?
- What are the acceptance criteria?
- What edge cases matter?

### Step 2: Gap Analysis

Compare the goal against existing code:

```
1. Read relevant existing files
2. Identify what exists vs. what's needed
3. List the delta as discrete tasks
```

**Key question:** "Don't assume not implemented" - check before creating new.

### Step 3: Create Task List

Break the delta into atomic tasks:

**Good tasks:**
- Completable in <30 minutes
- One logical change per task
- Has clear "done" criteria
- Has backpressure (test/lint/build that validates)

**Bad tasks:**
- "Build the feature" (too big)
- "Set up architecture" (no validation)
- "Various fixes" (not atomic)

### Step 4: Organize into Waves

Group tasks by dependencies:

| Wave | Criteria |
|------|----------|
| **Wave 1** | No dependencies, can run in parallel |
| **Wave 2** | Depends on Wave 1 completing |
| **Wave N** | Depends on Wave N-1 |
| **Final** | Verification, integration tests |

### Step 5: Write IMPLEMENTATION_PLAN.md

Use the template from `drafts/IMPLEMENTATION_PLAN-template.md`.

Include for each task:
- Description
- Target file(s)
- Success criteria
- Backpressure command

### Step 6: Exit Planning

> "Plan created with [N] tasks across [M] waves.
> Ready to execute? Run `/execute` to start."

Update PROJECT_STATE.md:
- Funnel: `plan` -> validation gate passed
- Ready to move to `build`

## Quick Start

If user just types `/plan`:

1. Check if IMPLEMENTATION_PLAN.md exists
   - **Yes**: "Found existing plan. Review and update, or start fresh?"
   - **No**: "No plan found. What are we building?"

2. Follow the process above

## Regeneration

Plans are disposable. If the current plan is wrong:

> "This plan has diverged from reality. Regenerating costs one planning loop but ensures we're working from accurate state. Regenerate?"

Don't patch broken plans. Regenerate.

---
*80% of time on planning, 20% on execution. This is the 80%.*
