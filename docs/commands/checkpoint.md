# Create Checkpoint

Create a Git checkpoint (tag) for safe rollback.

See `57_checkpoint-discipline.md` for full methodology.

## Step 1: Determine Checkpoint Type

Ask:
> "What kind of checkpoint? (phase/safe/wave/decision)"

| Type | When to Use | Example |
|------|-------------|---------|
| `phase/` | Completing a phase (define→plan→build) | `phase/define-complete` |
| `safe/` | Before risky changes | `safe/before-refactor` |
| `wave/` | After implementation wave | `wave/1-models` |
| `decision/` | Before architecture decision | `decision/before-coredata` |

## Step 2: Get Description

Ask:
> "Brief description for this checkpoint?"

## Step 3: Check State

Run:
```bash
git status
```

If there are uncommitted changes:
> "There are uncommitted changes. Commit first, or checkpoint current HEAD?"

Options:
1. Commit changes, then checkpoint
2. Checkpoint current HEAD (uncommitted changes not included)
3. Cancel

## Step 4: Create Checkpoint

```bash
git tag -a [type]/[description] -m "[Full description of state]"
```

Example:
```bash
git tag -a phase/define-complete -m "Spec approved, acceptance criteria defined, ready for planning"
```

## Step 5: Confirm

Display:
```
Checkpoint created: [type]/[description]

To rollback to this point:
  git checkout -b recovery [type]/[description]

To see changes since checkpoint:
  git diff [type]/[description]

To list all checkpoints:
  git tag -l "[type]/*"
```

## Quick Modes

| Command | Creates |
|---------|---------|
| `/checkpoint phase` | `phase/YYYY-MM-DD` with phase name prompt |
| `/checkpoint safe` | `safe/before-YYYY-MM-DD-HHMM` |
| `/checkpoint wave N` | `wave/N-[description]` |
