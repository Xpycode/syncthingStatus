# AI Code Quality Check

Run automated quality checks designed for AI-assisted development.

## When to Use

- After significant AI-generated implementation
- Before committing large changes
- Weekly codebase health check
- When codebase feels "bloated"

## Step 1: Measure Codebase

Run these commands to get metrics:

```bash
# Lines of code (Swift)
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | xargs wc -l | tail -1

# File count
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" | wc -l

# Largest files
find . -name "*.swift" -not -path "./.build/*" -not -path "./DerivedData/*" -exec wc -l {} + | sort -rn | head -10
```

Report:
- Total LOC: [X]
- File count: [Y]
- Files over 400 lines: [list]

## Step 2: Feature Interaction Check

List the main features in the app. Calculate interaction complexity:

| Features | Formula | Interactions |
|----------|---------|--------------|
| n | 2^n - 1 - n | result |

If > 100 interactions: Review feature boundaries and interfaces.

## Step 3: AI-Typical Issues Scan

For recently changed files, check:

### Happy-Path Bias
- [ ] Every `if` has an `else` (or explicit handling)
- [ ] Network calls have error handling
- [ ] File operations have failure paths
- [ ] User input is validated

### Edge Cases
- [ ] Empty/nil inputs handled
- [ ] Maximum values considered
- [ ] Concurrent access considered
- [ ] Resource exhaustion considered

### Verbosity
- [ ] No duplicate code
- [ ] No unused functions
- [ ] Abstractions used more than once
- [ ] Files under 400 lines

### Confidence Check
- [ ] Tests exist for new code
- [ ] Tests cover error paths
- [ ] Manual testing completed

## Step 4: Consolidation Opportunities

Look for:
- Similar functions that could be merged
- Near-duplicate implementations
- Over-abstracted patterns (used once)
- Dead code paths

List findings with file:line references.

## Step 5: Generate Report

```markdown
## Quality Check: YYYY-MM-DD

### Metrics
- LOC: X (target: Y)
- Files: Z
- Large files: [list]
- Feature interactions: N

### Issues Found
| File | Issue | Severity |
|------|-------|----------|
| ... | ... | ... |

### Consolidation Opportunities
- [ ] ...

### Verdict
✅ Healthy / ⚠️ Needs attention / 🚫 Review required
```

## Step 6: Thresholds

| Metric | Healthy | Attention | Review Required |
|--------|---------|-----------|-----------------|
| Total LOC | < 10k | 10k-30k | > 30k |
| Largest file | < 300 | 300-500 | > 500 |
| Feature interactions | < 50 | 50-100 | > 100 |
| Test coverage | > 60% | 40-60% | < 40% |

## Quick Version

For fast checks, just run:

1. `wc -l` on changed files
2. Count features, calculate interactions
3. Grep for `try?` (swallowed errors) — verify each is intentional
4. Grep for `print(` — **verify context** (OK inside `#if DEBUG` or `#Preview`)
5. Spot check error handling

**Important:** Pattern matching finds candidates. Context determines if they're issues. See `/code-review` for verification steps.

---

*Reference: 35_ai-code-quality.md for full guidelines*
