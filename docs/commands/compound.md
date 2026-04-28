# Compound Learning

Extract reusable patterns from the current session. Run after significant work.

## Philosophy
> "Each unit of engineering work should make subsequent units easier—not harder."

## Process

### Step 1: Analyze Recent Work
Review the session log and recent commits:
- What patterns emerged?
- What gotchas did we hit?
- What decisions were made implicitly?

### Step 2: Extract Learnings

For each pattern discovered, categorize:

| Type | Destination | Example |
|------|-------------|---------|
| **Term learned** | `44_my-glossary.md` | "Learned what 'backpressure' means" |
| **Architecture decision** | `decisions.md` | "Chose actors over classes for services" |
| **Code pattern** | `AGENTS.md` | "Always use Result type for errors" |
| **Gotcha** | `AGENTS.md` or relevant `2x_*.md` | "Image coordinates are bottom-left origin" |
| **Workflow improvement** | This Directions repo | "Add validation gate before shipping" |

### Step 3: Update Files

1. **Ask before updating:**
   > "I found these patterns from today's session:
   > - [Pattern 1] -> would go in [destination]
   > - [Pattern 2] -> would go in [destination]
   > Want me to add them?"

2. **Update approved destinations**

3. **Log extraction in session notes:**
   > "Compounded: [brief summary of what was extracted]"

### Step 4: Update PROJECT_STATE.md

Add to "Compound Learnings" section if patterns are still being validated.
Move to permanent homes once stable.

## Triggers

Run `/compound` when:
- End of a work session
- After fixing a tricky bug
- After making an architectural choice
- When you notice yourself repeating something

## Example Output

```
Compound extraction from session 2026-01-26:

1. **Glossary**: "Backpressure" - using tests/builds to validate correctness
   -> Added to 44_my-glossary.md

2. **Decision**: Use IMPLEMENTATION_PLAN.md for persistent task tracking
   -> Added to decisions.md

3. **Pattern**: Always run `swift build` before committing
   -> Added to AGENTS.md backpressure commands

4. **Gotcha**: NSImage coordinates use bottom-left origin
   -> Added to 21_coordinate-systems.md

Session compounded. 4 learnings extracted.
```

---
*The goal: never solve the same problem twice.*
