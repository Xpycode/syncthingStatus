<!--
TRIGGERS: workflow, phases, process, how to build, spec interview, planning, implementation, review
PHASE: any
LOAD: full
-->

# The Development Workflow

**The 6-phase process that ships working software.**

*From idea to working app, step by step.*

---

## Part 2: The Workflow That Ships Apps

Based on analysis of successful vs. failed projects, here's what works:

### Phase 1: Specification (Don't Skip This)

**The Problem:** Projects fail when the AI doesn't understand what you want.

**The Solution:** The Spec Interview

```
1. Write a one-line description of what you want
2. Tell Claude: "Interview me in detail about this feature—
   technical implementation, UI/UX, concerns, tradeoffs.
   Keep asking until you fully understand."
3. Answer honestly. Say "I don't know" when unsure.
4. Have Claude write the full spec.
```

**Why it works:**
- Forces you to think through edge cases
- Gives Claude context to make good decisions
- Creates a reference document for later

**Example one-liner:**
> "I want a settings screen that lets users toggle dark mode and change notification preferences."

After the interview, you'll have a 500-2000 word spec covering UI layout, data persistence, edge cases, and implementation approach.

### Phase 2: Planning (The 30-Minute Rule)

**The Problem:** Big features become abandoned features.

**The Solution:** Phase-based milestones

> "Never be more than 30 minutes from working code."

Tell Claude:
```
Break this into small phases. Each phase must:
1. Be completable in under 30 minutes
2. Result in something I can test
3. Not break what already works
```

**What good phases look like:**

| Phase | Deliverable | Can Test? |
|-------|-------------|-----------|
| 1. Basic UI shell | Screen appears, buttons exist | Yes |
| 2. Dark mode toggle | Toggle changes appearance | Yes |
| 3. Persist preference | Survives app restart | Yes |
| 4. Notification settings UI | Checkboxes appear | Yes |
| 5. Save notification prefs | Settings persist | Yes |

**What bad phases look like:**
- "Phase 1: Build the entire feature" (too big)
- "Phase 1: Set up architecture" (can't test)
- "Phase 1-15: Various tasks" (too many)

### Phase 3: Implementation (Auto-Accept Mode)

Once the plan looks good:

```
Switch to auto-accept mode and implement phase 1.
```

**What to watch for:**
- Does Claude explain what it's doing?
- Does it create files in sensible locations?
- Does it verify after making changes?

**If something looks wrong:** Stop. Ask Claude to explain. Don't let confusion compound.

### Phase 4: Adversarial Review (The Critical Step)

**The Problem:** Claude has "false confidence"—it says "Brilliant!" about buggy code.

**The Solution:** Adversarial review with a second pass

```
Do a git diff and pretend you're a senior dev doing a code review
and you HATE this implementation. What would you criticize?
What edge cases am I missing?
```

**How to read the feedback:**

| Type | Example | Action |
|------|---------|--------|
| Real bug | "This will crash if the array is empty" | Fix it |
| Security issue | "User input isn't sanitized" | Fix it |
| Missing error handling | "Network failure isn't handled" | Fix it |
| Style nitpick | "Variable name could be clearer" | Ignore |
| Over-engineering | "Should use a factory pattern" | Ignore |

**The rule:** 2-3 review passes catches real issues. More than that wastes time.

### Phase 5: Multi-Model Validation (For Important Code)

**The Problem:** Different AI models catch different bugs.

**Evidence from the codebase:**
> "Claude missed ID stability bug; Gemini caught it."

**The Solution:** For critical features, get a second opinion.

Options:
- Copy the code to Gemini and ask for review
- Use Claude's `/zen` tools to consult other models
- Ask a different Claude session (fresh context)

**When to do this:**
- Code that handles money or sensitive data
- Core architecture decisions
- Anything that "just feels off"

### Phase 6: Verification (Close the Loop)

**The Problem:** "Build succeeded" doesn't mean "bug fixed."

**The Solution:** Test the actual user workflow

Tell Claude:
```
How can we verify this actually works?
Don't just run the build—test the user flow.
```

For iOS/macOS apps, this means:
- Run in simulator
- Click through the actual UI
- Try edge cases (empty state, error state)
- Restart the app, check persistence

---

## Part 9: Daily Workflows

### Starting a New Feature

```
1. Write one-line description in SPEC.md
2. Run spec interview (10-30 min)
3. Enter Plan mode: Shift+Tab twice
4. Break into 30-minute phases
5. Implement phase by phase
6. Adversarial review after each phase
7. Multi-model review for critical parts
8. Commit when stable
```

### Fixing a Bug

```
1. Describe the exact symptom
2. Ask Claude to find the cause (don't guess)
3. Ask Claude to explain the fix before implementing
4. Implement the fix
5. Verify the bug is gone
6. Add a comment explaining WHY if it was tricky
7. Commit
```

### Weekly Maintenance

```
1. Review your NOW list—is it still accurate?
2. Move completed items to DONE with dates
3. Check if anything in NEXT should move to NOW
4. Remove items from LATER that you'll never do
```

---

## Part 10: The Checklists

### Before Starting Any Feature

- [ ] One-line description written
- [ ] Spec interview completed
- [ ] Plan broken into 30-min phases
- [ ] First phase is clear and testable

### Before Committing Code

- [ ] Adversarial review done (2-3 passes)
- [ ] No real bugs remaining (nitpicks ignored)
- [ ] Feature actually tested, not just built
- [ ] CLAUDE.md updated if new patterns learned

### Production Readiness

- [ ] No debug print statements
- [ ] No `try?` swallowing errors silently
- [ ] No `@unchecked Sendable` without justification
- [ ] No force unwraps without nil checks
- [ ] Files under 500 lines
- [ ] Services are actors (not classes)
- [ ] README has screenshots
- [ ] CHANGELOG updated

---

*This guide will evolve. When you learn something the hard way, add it.*
