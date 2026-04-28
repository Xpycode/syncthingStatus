# Example Mapping

Discover requirements through concrete examples. Use for complex features with business logic.

See `59_example-mapping.md` for full methodology.

## Step 1: State the Story (2 min)

Ask:
> "What feature are we mapping? Describe it as: 'User can [action]'"

Write as the **Story** (yellow card).

## Step 2: Identify Rules (5 min)

Ask:
> "What rules or constraints govern this feature?"

For each rule mentioned, create a **Rule** (blue card):
- "What business rules apply?"
- "What validation is needed?"
- "What limits exist?"

## Step 3: Generate Examples (10-15 min)

For each rule, ask:
> "Give me a concrete example of this rule in action"

Then probe for edge cases:
- "What if the input is empty?"
- "What if it's at the boundary?"
- "What if it fails?"

Capture as **Examples** (green cards) under each rule:
```
Rule: [Rule description]
├── Example: [Happy path] → [Outcome]
├── Example: [Edge case] → [Outcome]
└── Example: [Error case] → [Outcome]
```

## Step 4: Capture Questions (ongoing)

When anything is unclear, capture as **Question** (red card):
- Decisions that need to be made
- Ambiguities to resolve
- Things to research

## Step 5: Output

Create or update `specs/[feature-name].md` with:

```markdown
## Example Map

### Story
[User can...]

### Rules & Examples

#### Rule 1: [Description]
- Given [context], when [action], then [outcome]
- Given [edge case], when [action], then [outcome]

#### Rule 2: [Description]
- Given [context], when [action], then [outcome]

### Open Questions
- [ ] [Question 1]
- [ ] [Question 2]
```

## Step 6: Next Steps

Display:
```
Example mapping complete.

Rules discovered: [N]
Examples captured: [N]
Open questions: [N]

Next:
- Resolve open questions before proceeding
- Run /spec to formalize into full specification
- Or run /plan if spec already exists
```
