# Production Review Checklist

Run through the production checklist interactively.

## Step 1: Load Checklists

Read both source documents:
- `docs/30_production-checklist.md` - Code quality and release prep
- `docs/33_app-minimums.md` - Baseline features (updates, logging, UI polish)

Display the checklist sections from these files.

## Step 2: Interactive Review

Go through each section, asking:

"**[Section Name]** - Ready to review this section?"

For each item:
- Ask "✓ [Item]?"
- User confirms or flags issue
- If issue flagged, note it

## Step 3: Generate Report

Create a summary:

```markdown
## Production Review: YYYY-MM-DD

### Passed
- [x] Item 1
- [x] Item 2

### Issues Found
- [ ] Item 3 - [note about issue]
- [ ] Item 4 - [note about issue]

### Summary
X of Y items passed. [Ready to ship / Issues need addressing]
```

## Step 4: Save or Display

Ask: "Save this report to docs/sessions/review-YYYY-MM-DD.md?"

If yes, save it. Either way, display the summary.
