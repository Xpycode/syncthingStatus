# Reflect

Analyze recent work and suggest improvements. Uses reflexion patterns.

## When to Use

- After completing a feature
- When something feels off
- Before a major commit
- Periodic quality check

## Process

### Step 1: Gather Evidence

Collect recent work:
```
1. git diff (uncommitted changes)
2. git log --oneline -10 (recent commits)
3. Current session log
4. IMPLEMENTATION_PLAN.md progress
```

### Step 2: Multi-Perspective Review

Analyze from multiple angles:

| Perspective | Questions |
|-------------|-----------|
| **Bug Hunter** | What could crash? What's unhandled? |
| **Security** | Input validation? Auth checks? Secrets exposed? |
| **Quality** | Code duplication? Files too long? Naming clear? |
| **Test Coverage** | What's untested? What edge cases missing? |
| **Architecture** | Does this fit the patterns? Technical debt? |

### Step 3: Categorize Findings

| Severity | Action | Examples |
|----------|--------|----------|
| **Critical** | Fix before commit | Crash bugs, security holes, data loss |
| **Important** | Fix soon | Missing error handling, untested paths |
| **Minor** | Note for later | Style inconsistencies, minor refactors |
| **Nitpick** | Ignore | Preferences, over-engineering suggestions |

### Step 4: Present Findings

```
## Reflection Results

### Critical (must fix)
- [ ] [Issue]: [Description] in `file:line`

### Important (fix soon)
- [ ] [Issue]: [Description]

### Minor (note for later)
- [Issue]: [Description]

### Positive Observations
- [Good pattern noticed]
- [Clean implementation]

**Recommendation:** [Fix critical issues before committing / Good to commit / etc.]
```

### Step 5: Act on Findings

For critical/important issues:
1. Fix the issue
2. Re-run backpressure
3. Run `/reflect` again to verify

## Reflexion Modes

### Quick (`/reflect quick`)
- Bug hunter perspective only
- 2-minute review
- Good for small changes

### Standard (`/reflect`)
- All perspectives
- 5-minute review
- Good for features

### Deep (`/reflect deep`)
- All perspectives + second pass
- Cross-reference with specs
- Check against acceptance criteria
- 10-minute review
- Good before shipping

## Integration with Compound

After `/reflect`, findings can feed into `/compound`:

> "Found patterns during reflection:
> - [Pattern that should be documented]
> Run `/compound` to extract learnings?"

---
*The goal: catch issues before they ship, learn from every session.*
