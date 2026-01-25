# Wave-Based Execution

Run implementation tasks with fresh context per wave, preventing quality degradation.

## Step 1: Find or Create Plan

Check for `PLAN.md` in project root. If missing, ask the user what to implement and create one:

```markdown
# Execution Plan

## Goal
[One sentence describing the goal]

## Tasks

### Wave 1 (parallel - no dependencies)
- [ ] **Task 1.1**: [description] -> `target-file`
- [ ] **Task 1.2**: [description] -> `target-file`

### Wave 2 (depends on Wave 1)
- [ ] **Task 2.1**: [description] -> `target-file`

### Wave 3 (verification)
- [ ] **Task 3.1**: Run tests, verify integration
```

**Grouping rules:**
- Same wave = can run in parallel (no dependencies between them)
- Next wave = depends on previous wave completing
- Keep each task atomic (one logical change)

## Step 2: Execute Waves

For each wave, spawn parallel developer subagents using the Task tool:

```
Task(subagent_type="developer", prompt="...")
```

**Each subagent prompt MUST include:**
- Specific task description from PLAN.md
- Target files to create/modify
- Success criteria (what "done" looks like)
- Project context from PROJECT_STATE.md if exists
- DO NOT include conversation history - fresh context only

**After each wave completes:**
1. Review results from all subagents
2. Make atomic commits: `feat(wave-N): task description`
3. Update PLAN.md checkboxes to [x]
4. Update PROJECT_STATE.md if it exists

**If blocked:**
- Create RESUME.md checkpoint
- Ask user for decision
- Spawn debugger agent if needed

## Step 3: Verify

After all waves complete:
1. Run build/tests if applicable
2. Check integration points
3. Update PROJECT_STATE.md with completion status
4. Delete PLAN.md (it's done)

## Key Principles

1. **Orchestrator stays light** - Never exceed 40% context. Delegate heavy work.
2. **Fresh context per task** - Each subagent starts clean with only task-specific info.
3. **Atomic commits** - One task = one commit. Easy to revert.
4. **State lives in files** - PLAN.md and PROJECT_STATE.md are source of truth.

## Quick Start

If user just typed `/execute` with no prior PLAN.md:
> "No PLAN.md found. What would you like to implement? I'll create an execution plan with parallel waves."
