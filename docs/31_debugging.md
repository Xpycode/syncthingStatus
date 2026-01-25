<!--
TRIGGERS: bug, not working, broken, debug, error, fix, troubleshoot, mistake, problem
PHASE: implementation
LOAD: full
-->

# Debugging Guide

**When things go wrong—and how to fix them.**

*Debugging workflow, common mistakes, and when to start fresh.*

---

## Part 6: When Things Go Wrong

### Debugging Workflow

When something doesn't work:

1. **Describe the symptom precisely**
   - Bad: "It's broken"
   - Good: "I tap the save button, nothing happens, no error appears"

2. **Ask Claude to add logging**
   ```
   Add diagnostic logging to trace what happens when I tap save.
   Log the state before and after each step.
   ```

3. **Run and share the logs**
   ```
   Here's what the console shows: [paste logs]
   What's going wrong?
   ```

4. **Document the fix**
   If it was tricky, ask Claude to add a comment explaining WHY.

### The "It Used to Work" Trap

**Danger:** Assuming a previous version was correct.

Often, "it used to work" means "it used to appear to work but was never properly tested."

Instead of reverting blindly:
```
Let's understand why it broke before reverting.
What changed between the working and broken versions?
```

### When to Start Fresh

Sometimes the codebase is too tangled. Signs:

- Every fix causes two new bugs
- Claude keeps contradicting its previous suggestions
- You've lost track of what's supposed to work
- The architecture has grown "organically" into chaos

**Solution:** Start a new project. Copy working patterns from old code. Don't copy the mess.

---

## Part 8: Common Mistakes and How to Avoid Them

### Mistake 1: Skipping the Spec Interview

**Symptom:** Claude builds something, but it's not what you wanted.

**Fix:** Always start with the interview. 10 minutes of questions saves hours of rework.

### Mistake 2: One Giant Feature

**Symptom:** Working for days, nothing works yet.

**Fix:** 30-minute phases. If you can't test it, it's too big.

### Mistake 3: Trusting Single AI Review

**Symptom:** "Claude said it looks good" → bug in production.

**Fix:** Adversarial review. Second model for critical code.

### Mistake 4: No Verification Loop

**Symptom:** "Build succeeded" but feature doesn't work.

**Fix:** Tell Claude how to verify. Watch it actually test.

### Mistake 5: Accumulating TODO Items

**Symptom:** 200-item wishlist, 0% completion.

**Fix:** NOW/NEXT/LATER. Maximum 5 items in NOW.

### Mistake 6: Not Documenting the WHY

**Symptom:** You fix a bug, then "improve" the code later, bug returns.

**Fix:** When you find a tricky bug, ask Claude:
```
Add a comment explaining WHY this code is written this way.
Include a reference to this conversation or a bug file.
```

Example:
```swift
// WARNING: DO NOT CHANGE
// originalSize must use cgImage dimensions (PIXELS), not nsImage.size (POINTS)
// On Retina displays, they differ by 2x
// This caused crop bugs that took 3 sessions to diagnose
// See: CropBatch-BUGFIX-retina-crop-position.md
```

---

*This guide will evolve. When you learn something the hard way, add it.*
