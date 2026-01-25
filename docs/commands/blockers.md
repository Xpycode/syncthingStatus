# Log a Blocker

Record what's blocking progress in PROJECT_STATE.md.

## Step 1: Gather Information

Ask the user:
1. "What's blocking you?" (brief description)
2. "What have you tried so far?"
3. "What would unblock this?" (if known)

## Step 2: Update PROJECT_STATE.md

Find or create the `## Blockers` section in `docs/PROJECT_STATE.md`.

Add the blocker in this format:

```markdown
## Blockers

### [Brief title] (YYYY-MM-DD)
**What:** [description]
**Tried:** [what was attempted]
**Unblock:** [what would resolve it]
```

## Step 3: Suggest Next Steps

Based on the blocker type, suggest:

| Blocker Type | Suggestion |
|--------------|------------|
| Technical/bug | "Try /decide to document the problem, or check 31_debugging.md" |
| Design decision | "Run /decide to work through the options" |
| External dependency | "Document in decisions.md and move to another task" |
| Knowledge gap | "Check relevant docs or ask for clarification" |

## Step 4: Confirm

Display: "Blocker logged. Consider addressing it now or switching focus."

## Resolving Blockers

When a blocker is resolved, update it:

```markdown
### [Brief title] (YYYY-MM-DD) ✅ RESOLVED
**What:** [description]
**Tried:** [what was attempted]
**Resolution:** [how it was resolved]
```
