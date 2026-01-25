# Scaffold New Feature

Create documentation structure for a new feature.

## Step 1: Gather Information

Ask the user:
1. "Feature name?" (will be converted to kebab-case for filename)
2. "One-sentence description?"
3. "Is this a major feature or a minor enhancement?"

## Step 2: Create Feature Doc

Create `docs/features/[feature-name].md`:

```markdown
# Feature: [Feature Name]

**Status:** Planning
**Created:** YYYY-MM-DD

## Summary
[One-sentence description]

## Requirements
- [ ] [Requirement 1]
- [ ] [Requirement 2]
- [ ] [Requirement 3]

## Design Notes
[To be filled in during planning]

## Implementation Notes
[To be filled in during implementation]

## Testing Checklist
- [ ] Core functionality works
- [ ] Edge cases handled
- [ ] Error states tested

## Related
- Decisions: [link to relevant decisions]
- Sessions: [link to relevant sessions]
```

## Step 3: Update PROJECT_STATE.md

If this is a major feature, add it to the focus or a features section in PROJECT_STATE.md:

```markdown
## Features in Progress
- [feature-name]: [status]
```

## Step 4: Create features/ Directory

If `docs/features/` doesn't exist, create it.

## Step 5: Confirm

Display:
```
Feature scaffolded: docs/features/[feature-name].md

Next steps:
1. Fill in the requirements
2. Run /decide for any architectural choices
3. Check 33_app-minimums.md for baseline features to include
4. Update the feature doc as you implement
```
