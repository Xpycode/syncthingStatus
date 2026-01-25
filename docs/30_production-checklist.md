<!--
TRIGGERS: ship, release, production ready, pre-release, before shipping, app store
PHASE: shipping
LOAD: full
-->

# Production Readiness Checklist

*Code quality checks based on 10 code reviews across 6 projects.*

> **Two-part release flow:**
> 1. First run `/minimums` → Feature baselines (updates, logging, UI polish)
> 2. Then run `/review` → Code quality (this file)

---

## Pre-Release Checklist

### Code Quality

- [ ] **No debug print statements** in production code
- [ ] **No `try?` swallowing errors** silently — handle or propagate
- [ ] **No `@unchecked Sendable`** without documented justification
- [ ] **No force unwraps (`!`)** without nil guards
- [ ] **No `inout` parameters in async callbacks** — values will be lost
- [ ] **Files under 500 lines** — split monolithic files
- [ ] **`defer` used for cleanup** — file handles, cursors, security scopes

### Thread Safety

- [ ] **Services are actors** — not classes with locks
- [ ] **ViewModels are `@MainActor`** — UI updates on main thread
- [ ] **No plain Bool/Dictionary** accessed from multiple threads
- [ ] **Cancellation flags use proper synchronization** — not plain Bool
- [ ] **`@Published` updates on main thread** — use `.receive(on: .main)`

### Error Handling

- [ ] **Errors are logged with context** — not just `print(error)`
- [ ] **User-facing errors are shown** — alert, toast, or status
- [ ] **Transient errors filtered** — don't show cancelled operations
- [ ] **Generic error messages for security** — don't expose paths/internals

### Memory Management

- [ ] **Caches have limits** — unbounded = memory leak
- [ ] **Dictionary entries actually removed** — `dict[key] = nil` vs `.removeValue`
- [ ] **Weak self in closures** — prevent retain cycles
- [ ] **File handles closed** — use `defer` or proper cleanup

### Build Configuration

- [ ] **Release build configuration exists** — not just Debug
- [ ] **Optimizations enabled for Release** — check build settings
- [ ] **Debug code conditionally compiled** — `#if DEBUG`
- [ ] **No hardcoded development URLs/keys** — use configuration

### Security

- [ ] **Input validated** — especially user-provided paths/IDs
- [ ] **Secrets in Keychain** — not UserDefaults or code
- [ ] **Path traversal prevented** — validate paths are within bounds
- [ ] **Sensitive data not logged** — tokens, passwords, keys
- [ ] **Security-scoped resources balanced** — start/stop paired

---

## Red Flags (Instant "Not Production Ready")

| Red Flag | Why It's Bad | Fix |
|----------|--------------|-----|
| `try?` everywhere | Errors silently ignored | Use `do/catch` or `throws` |
| `@unchecked Sendable` | Bypasses thread safety checks | Use proper actor isolation |
| Force unwrap `!` | Crash on nil | Guard with `if let` or `guard` |
| 1000+ line file | Unmaintainable | Split into modules |
| Debug prints in code | Information leak, noise | Use logging framework or `#if DEBUG` |
| Missing Release config | Not optimized, debug symbols exposed | Add Release configuration |
| `inout` in async | Changes lost silently | Copy, modify, return |
| Plain Bool across threads | Race condition | Use actor or atomic |

---

## Review Checklist by Category

> **UI/UX Review:** See [33_app-minimums.md](33_app-minimums.md) for UI polish checklist (empty states, loading states, keyboard shortcuts, etc.)

### Data Persistence Review

- [ ] **Save actually persists** — verify with app restart
- [ ] **Corrupt data handled** — graceful fallback
- [ ] **Migration path exists** — for schema changes
- [ ] **Backup/restore works** — if applicable

### Network Review

- [ ] **Timeouts configured** — not default 60 seconds
- [ ] **Offline state handled** — appropriate message
- [ ] **Retry logic reasonable** — exponential backoff
- [ ] **Cancellation supported** — user can abort

### Performance Review

- [ ] **Large data sets tested** — 1000+, 10000+ items
- [ ] **Memory profiled** — no unbounded growth
- [ ] **Main thread not blocked** — Instruments check
- [ ] **Scrolling smooth** — no frame drops

---

## Pre-Commit Checklist

Quick checks before every commit:

```
[ ] Build succeeds (Release configuration)
[ ] No warnings (or justified suppressions)
[ ] Tests pass (if tests exist)
[ ] Changes actually work (manual verification)
[ ] No debug code left behind
[ ] Commit message is clear
```

---

## Pre-Release Checklist

Before distributing to users:

```
[ ] Full production checklist above
[ ] App Minimums verified (see 33_app-minimums.md)
[ ] Tested on clean install (delete app data)
[ ] Tested app update path (if updating existing app)
[ ] Crash reports reviewed (if available)
[ ] README updated with new features
[ ] CHANGELOG entry added
[ ] Version number incremented
[ ] Code signed and notarized (macOS)
```

---

## Asking Claude to Review

### Production Review Prompt

```
Review this code for production readiness.

Check for:
1. Thread safety issues (shared state, race conditions)
2. Memory leaks (unbounded caches, retain cycles)
3. Error handling (swallowed errors, missing user feedback)
4. Security issues (unsanitized input, exposed secrets)
5. Debug code left behind (print statements, hardcoded values)

For each issue found:
- Quote the specific code
- Explain why it's a problem
- Suggest a fix
- Rate severity: Critical / High / Medium / Low
```

### Security Review Prompt

```
Do a security review of this code.

Check for:
1. Input validation (paths, IDs, user data)
2. Secret handling (are credentials safe?)
3. Path traversal (can users access unintended files?)
4. Information disclosure (what do errors reveal?)
5. Injection vulnerabilities (if applicable)

Assume malicious input. What could go wrong?
```

### Thread Safety Review Prompt

```
Review this code for thread safety.

Check for:
1. Shared mutable state (classes accessed from multiple threads)
2. @Published updates from background threads
3. Actor isolation (is it actually isolated?)
4. Cancellation handling (race conditions in cancellation)
5. Resource cleanup (balanced start/stop, open/close)

What race conditions are possible?
```

---

## Common Issues by Review Count

Based on analysis of code reviews, these issues appear most frequently:

| Issue | Frequency | Projects Affected |
|-------|-----------|-------------------|
| Missing tests | 6/6 reviews | All |
| Large monolithic files | 6/6 reviews | All |
| Thread safety concerns | 5/6 reviews | CropBatch, P2toMXF, VideoScreenSaver, ScheduleParsing, Camera Transcoder |
| Debug prints in code | 4/6 reviews | Multiple |
| Missing error handling | 4/6 reviews | Multiple |
| Unbounded caches | 3/6 reviews | CropBatch, P2toMXF, VideoScreenSaver |

---

## Testing Checklist

### Minimum Viable Testing

- [ ] **Critical paths have tests** — parsers, data transforms
- [ ] **Error paths tested** — invalid input, missing files
- [ ] **Edge cases covered** — empty input, maximum values

### User Workflow Testing

```
For each feature:
1. Start from clean state
2. Perform the user action
3. Verify the result
4. Restart the app
5. Verify persistence
6. Try edge cases (empty, maximum, invalid)
```

---

## Severity Guide

| Severity | Definition | Example |
|----------|------------|---------|
| **Critical** | Will crash or corrupt data | Force unwrap of nil, race condition on save |
| **High** | Significant malfunction | Error swallowed, memory leak |
| **Medium** | Degraded experience | Missing loading state, slow performance |
| **Low** | Minor issue | Style inconsistency, missing accessibility |

**Rule:** Ship with 0 Critical, 0 High. Medium/Low can wait.

---

*Run this checklist before every release. Add items as you discover new issues.*
