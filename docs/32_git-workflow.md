<!--
TRIGGERS: git, commit, branch, merge, main, version control, undo, reset, tag, release
PHASE: any
LOAD: full
-->

# Git Workflow for Solo Developers

**Simple but disciplined version control.**

*You work alone, but future-you is your teammate.*

---

## The Golden Rule

**Never commit directly to `main`.**

Main should always be deployable. Work on branches, merge when stable.

---

## Branch Strategy

### Creating Branches

```bash
# Feature work
git checkout -b feature/dark-mode
git checkout -b feature/export-pdf

# Bug fixes
git checkout -b fix/crash-on-launch
git checkout -b fix/save-not-working

# Experiments (might throw away)
git checkout -b experiment/new-ui-approach
git checkout -b spike/test-library
```

### Naming Convention

| Prefix | Use For | Example |
|--------|---------|---------|
| `feature/` | New functionality | `feature/settings-screen` |
| `fix/` | Bug fixes | `fix/memory-leak` |
| `experiment/` | Trying something | `experiment/swiftui-charts` |
| `refactor/` | Code cleanup | `refactor/extract-service` |

---

## Commit Messages

### Format

```
[What changed]: [Why it changed]

[Optional: More details]
```

### Good Examples

```bash
git commit -m "Add dark mode toggle: users requested theme options"

git commit -m "Fix crash on empty file: guard against nil array"

git commit -m "Refactor settings: extract to dedicated ViewModel for testability"
```

### Bad Examples

```bash
# Too vague
git commit -m "Fixed bug"
git commit -m "Updates"
git commit -m "WIP"

# No why
git commit -m "Changed color to blue"  # Why blue?
```

### When to Commit

- **Do commit:** Working increments, completed thoughts
- **Don't commit:** Broken code, debug prints left in, "WIP" without context

---

## Merging to Main

### When to Merge

✅ Feature works as intended
✅ No debug prints or commented code
✅ Tested the actual user flow
✅ No known bugs introduced

### How to Merge

```bash
# Switch to main
git checkout main

# Merge your branch
git merge feature/dark-mode

# Delete the branch (it's merged)
git branch -d feature/dark-mode
```

### After Merging

Your main branch now has the new work. The feature branch is deleted (its history is preserved in main).

---

## Tags for Releases

### When to Tag

- App is ready for distribution
- Major milestone reached
- Before significant changes (so you can go back)

### Creating Tags

```bash
# Simple version tag
git tag v1.0

# Version with message
git tag -a v1.1 -m "Added export feature and dark mode"

# Tag a specific commit (retroactively)
git tag -a v0.9 abc1234 -m "Last stable before refactor"
```

### Listing Tags

```bash
git tag           # List all tags
git show v1.0     # Show tag details
```

---

## The "Oh Shit" Commands

### Undo Last Commit (Keep Changes)

```bash
# Uncommit but keep files changed
git reset --soft HEAD~1
```

### Undo Last Commit (Discard Changes)

```bash
# Uncommit AND discard changes (CAREFUL)
git reset --hard HEAD~1
```

### Discard All Uncommitted Changes

```bash
# Throw away everything not committed (CAREFUL)
git checkout .
# Or for newer git:
git restore .
```

### Recover Deleted Branch

```bash
# Find the commit
git reflog

# Recreate branch from that commit
git checkout -b recovered-branch abc1234
```

### Undo a Merge

```bash
# If you haven't committed after merge
git merge --abort

# If you already committed the merge
git revert -m 1 HEAD
```

### See What Changed

```bash
# What files changed
git status

# What lines changed (not staged)
git diff

# What lines changed (staged)
git diff --staged

# History
git log --oneline -10
```

---

## Quick Reference

| Task | Command |
|------|---------|
| New branch | `git checkout -b feature/name` |
| Switch branch | `git checkout branch-name` |
| See branches | `git branch` |
| Stage all | `git add .` |
| Commit | `git commit -m "message"` |
| Merge to main | `git checkout main && git merge branch` |
| Delete branch | `git branch -d branch-name` |
| Tag release | `git tag -a v1.0 -m "message"` |
| Undo last commit | `git reset --soft HEAD~1` |

---

## Claude Integration

Tell Claude about your git workflow:

```
Before implementing, create a feature branch.
After changes are working, commit with a message explaining WHY.
Don't commit to main directly.
```

Add to your CLAUDE.md:
```markdown
## Git Rules
- Never commit directly to main
- Branch names: feature/, fix/, experiment/
- Commit messages: what + why
- Merge only when tested and working
```

---

*Simple discipline now prevents "what happened to my code?" later.*
