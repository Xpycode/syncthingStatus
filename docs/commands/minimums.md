# App Minimums Check

Quick baseline features checklist before shipping.

## Step 1: Load Checklist

Read `docs/33_app-minimums.md` and display the Quick Reference section.

## Step 2: Interactive Check

Go through each category from the doc:
- **Deployment** (auto-update, version visibility, signing, icons)
- **Infrastructure** (logging, preferences, error handling, progress)
- **UI Polish** (empty states, loading states, error states, shortcuts, About)
- **Platform-Specific** (menu bar, window state, review prompts, etc.)

For each category, ask: "**[Category]** - all good, or missing something?"

## Step 3: Note Gaps

If anything is missing, ask:
- "Want to add this to the current session's tasks?"
- "Should I create a TODO for this?"

## Step 4: Summary

Display what's complete vs what needs work.

If everything is checked:
> "All minimums covered. Ready for /review to check code quality."
