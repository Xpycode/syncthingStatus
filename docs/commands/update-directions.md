# Update Directions

Pull latest Directions from GitHub and sync to both global config and current project.

## Step 1: Find Directions Master

Check these locations in order:
1. The path in `~/.claude/CLAUDE.md` under "Local master:"
2. Default: `/Users/sim/XcodeProjects/0-DIRECTIONS/__DIRECTIONS`

## Step 2: Pull Latest

```bash
cd <directions-master> && git pull origin main
```

If there are local changes, warn the user before pulling.

## Step 3: Sync to Global (~/.claude/)

```bash
# Ensure directories exist
mkdir -p ~/.claude/commands

# Copy command definitions
cp <directions-master>/commands/*.md ~/.claude/commands/

# Copy global template (don't overwrite if customized - warn instead)
# Compare and show diff if different
diff -q <directions-master>/CLAUDE-GLOBAL-TEMPLATE.md ~/.claude/CLAUDE.md
```

If CLAUDE.md differs significantly, ask:
> "Your ~/.claude/CLAUDE.md has customizations. Want me to:
> 1. Show the diff
> 2. Overwrite with new template
> 3. Keep yours (just update commands)"

## Step 4: Sync to Current Project

If current project has Directions (`docs/00_base.md` exists):

```bash
PROJECT_DOCS="./docs"

# Sync commands
cp <directions-master>/commands/*.md $PROJECT_DOCS/commands/

# Sync new reference docs (don't overwrite existing)
for file in <directions-master>/[0-9]*.md; do
  basename=$(basename "$file")
  if [ ! -f "$PROJECT_DOCS/$basename" ]; then
    cp "$file" "$PROJECT_DOCS/"
    echo "Added: $basename"
  fi
done

# Sync templates (these are meant to be created fresh, but ensure they exist)
cp <directions-master>/PLAN.md $PROJECT_DOCS/ 2>/dev/null || true
cp <directions-master>/RESUME.md $PROJECT_DOCS/ 2>/dev/null || true

# Update skill definitions
cp -r <directions-master>/skills/* $PROJECT_DOCS/skills/ 2>/dev/null || true
```

**Do NOT overwrite:**
- `PROJECT_STATE.md` (project-specific state)
- `decisions.md` (project history)
- `sessions/*` (session logs)
- `CLAUDE.md` in project root (project-specific instructions)

## Step 5: Summary

Show what changed:

```bash
# Recent commits from master
git -C <directions-master> log --oneline -5

# List new/updated files
echo "Updated commands:"
ls -la $PROJECT_DOCS/commands/

echo "New reference docs added:"
# (list any new files copied)
```

## Step 6: Verify

Quick check that sync worked:
- `commands/execute.md` exists in project
- `52_context-management.md` exists in project (if new)
- Skills folder is current

## Step 7: Remind About Restart

If hooks or scripts changed, remind the user:

> "Hooks or scripts were updated. Restart Claude Code for changes to take effect."

Check if these files changed in the pull:
- `hooks/hooks.json`
- `scripts/*.py`
- `.claude-plugin/plugin.json`

---

## Quick Reference

**What gets synced:**

| Source | Global (~/.claude/) | Project (./docs/) |
|--------|---------------------|-------------------|
| commands/*.md | ✓ | ✓ |
| [0-9]*.md reference docs | ✗ | ✓ (new only) |
| PLAN.md, RESUME.md | ✗ | ✓ |
| skills/* | ✗ | ✓ |
| PROJECT_STATE.md | ✗ | ✗ (never) |
| decisions.md | ✗ | ✗ (never) |
| sessions/* | ✗ | ✗ (never) |
