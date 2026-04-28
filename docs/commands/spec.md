# Create Feature Spec

Create a specification before implementation using the mini-PRD template.

## Step 1: Gather Core Info

Ask:
1. "What's the feature name?" (will become filename)
2. "What problem does this solve?" (one sentence)
3. "Who has this problem?"

## Step 2: Define the Solution

Ask:
1. "Describe the solution in one sentence"
2. "What are the 3-5 key capabilities?"
3. "Walk me through the user flow"

## Step 3: Acceptance Criteria

For each key capability, ask:
> "Given [what state], when [user does what], then [what should happen]?"

Capture as Given/When/Then format (see `56_acceptance-criteria.md`).

## Step 4: Boundaries

Ask:
1. "What's explicitly OUT of scope?"
2. "Any technical constraints?" (dependencies, performance, security)
3. "Open questions we need to resolve?"

## Step 5: Create the Spec

Create `specs/[feature-name].md` using template from `55_spec-template.md`:

```markdown
# [Feature Name] Specification

**Status:** Draft
**Created:** YYYY-MM-DD

## Problem Statement
[From Step 1]

## Proposed Solution
[From Step 2]

## Acceptance Criteria
[From Step 3 - Given/When/Then format]

## Technical Considerations
[From Step 4]

## Out of Scope
[From Step 4]

## Open Questions
[From Step 4]
```

## Step 6: Confirm

Display:
```
Spec created: specs/[feature-name].md

Next steps:
1. Review and refine acceptance criteria
2. Resolve open questions
3. Run /plan to create implementation tasks
```

Update `PROJECT_STATE.md` with spec reference.
