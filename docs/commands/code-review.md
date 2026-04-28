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
| **Debug code** | Unguarded `print()` in production paths? (see below) |
| **Commented code** | Dead code commented out? Delete it |
| **Magic numbers** | Unexplained values? Use named constants |

### Debug Code Verification (Context-Aware)

Don't just grep for `print(` — verify each match with context:

```
For each print() statement found:

✅ OK (not an issue):
  - Inside #if DEBUG ... #endif block
  - Inside #Preview { } block
  - Uses Logger or os_log (proper logging)
  - Part of CLI tool output (intentional)

❌ Issue (needs fixing):
  - Bare print() in production code path
  - print() in View body (not in #Preview)
  - print() in async/network code without DEBUG guard
```

**Quick verification command:**
```bash
# Find print statements NOT inside DEBUG or Preview blocks
# Manual review required - check surrounding context
grep -n "print(" *.swift | while read line; do
  file=$(echo $line | cut -d: -f1)
  linenum=$(echo $line | cut -d: -f2)
  # Check 5 lines before for #if DEBUG or #Preview
  context=$(sed -n "$((linenum-5)),$((linenum))p" "$file" 2>/dev/null)
  if ! echo "$context" | grep -qE "#if DEBUG|#Preview"; then
    echo "$line"
  fi
done
```

**Or use semantic analysis:** For complex codebases, use the `feature-dev:code-reviewer` agent which performs contextual analysis rather than pattern matching.

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

## Deep Review (Agent-Based)

For thorough contextual analysis, use the specialized code-reviewer agent:

```
Ask Claude: "Run a deep code review using the code-reviewer agent"
```

The `feature-dev:code-reviewer` agent provides:

- **Contextual analysis** — understands code structure, not just patterns
- **Confidence filtering** — only reports high-priority issues
- **Project conventions** — checks adherence to your codebase patterns
- **Bug detection** — logic errors, security vulnerabilities, edge cases

**When to use deep review:**
- Before merging feature branches
- After significant refactoring
- When checklist review found suspicious patterns
- For security-sensitive code changes

**Example prompt:**
```
Review the changes in [files/branch] for:
- Security vulnerabilities
- Logic errors and edge cases
- Code quality issues
- Adherence to project patterns

Use confidence-based filtering — only report issues you're confident about.
```

---

*Adapted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) code-reviewer agent*
