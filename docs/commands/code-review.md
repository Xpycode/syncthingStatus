# Code Review

Automated code review before committing or merging.

## When to Use

- Before committing significant changes
- Before merging a feature branch
- When unsure if code meets quality standards
- After fixing a bug (verify no new issues introduced)

## Step 1: Collect Changes

Run `git diff` to see what's changed:

```bash
# Staged changes
git diff --cached

# All uncommitted changes
git diff HEAD

# Changes since branching from main
git diff main...HEAD
```

List all modified files and summarize what changed.

## Step 2: Security Review (Critical)

Check each file for:

- [ ] **No hardcoded secrets** - API keys, passwords, tokens
- [ ] **No sensitive data in logs** - User info, credentials, health data
- [ ] **Input validation** - User input sanitized before use
- [ ] **No SQL injection** - Use parameterized queries
- [ ] **Authentication checks** - Protected routes require auth
- [ ] **Error messages** - Don't expose internal details

**If any security issue found: STOP and fix immediately.**

## Step 3: Code Quality Review

Check for common issues:

| Issue | Check |
|-------|-------|
| **Large files** | Any file > 400 lines? Consider splitting |
| **Long functions** | Any function > 50 lines? Consider extracting |
| **Deep nesting** | More than 3-4 levels deep? Flatten logic |
| **Force unwraps** | `!` without good reason? Use optional binding |
| **Missing error handling** | `try?` silently ignoring errors? Handle them |
| **Debug code** | `print()` statements left in? Remove them |
| **Commented code** | Dead code commented out? Delete it |
| **Magic numbers** | Unexplained values? Use named constants |

## Step 4: SwiftUI Specific (if applicable)

Reference: `20_swiftui-gotchas.md`

- [ ] Views are small and focused (< 100 lines body)
- [ ] State ownership is clear (`@State` vs `@Binding` vs `@ObservedObject`)
- [ ] No heavy computation in view body
- [ ] Previews exist and work
- [ ] Accessibility labels on interactive elements

## Step 5: Generate Report

Summarize findings:

```markdown
## Code Review: YYYY-MM-DD

### Files Reviewed
- `File1.swift` - [brief description of changes]
- `File2.swift` - [brief description of changes]

### Security
✅ No issues found / ⚠️ Issues found (see below)

### Quality Issues
- [ ] `File.swift:42` - [issue description]
- [ ] `File.swift:87` - [issue description]

### Verdict
✅ **Approved** - Ready to commit
⚠️ **Needs Work** - Fix issues above first
🚫 **Blocked** - Security issue must be resolved
```

## Step 6: Decision

Based on findings:

- **No issues**: Proceed with commit
- **Minor issues**: Fix inline, then commit
- **Major issues**: Create tasks to address, commit separately
- **Security issues**: Fix immediately before any commit

## Quick Review (Abbreviated)

For small changes, just run through:

1. `git diff --cached` to see changes
2. Quick security scan (secrets, auth, input validation)
3. Quick quality scan (obvious issues only)
4. Approve or flag issues

---

*Adapted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) code-reviewer agent*
