# Discovery Interview (Enhanced)

Multi-phase discovery with triangulation. Creates specs and acceptance criteria.

## Philosophy
> "Scope → Plan → Retrieve → Triangulate → Synthesize"

## Phase 1: Scope (2-3 minutes)

Define what we're learning:

1. **Core question:**
   > "What's the one thing this must do? (One sentence)"

2. **Success criteria:**
   > "How will we know it's working?"

3. **Boundaries:**
   > "What is explicitly NOT in scope?"

**Output:** Clear problem statement with boundaries.

---

## Phase 2: Explore (5-10 minutes)

Parallel investigation of key areas:

### Core Questions (Always Ask)

| # | Question | Informs |
|---|----------|---------|
| 1 | "Who uses it?" | Complexity level |
| 2 | "What platform?" | Tech stack |
| 3 | "Does it persist data?" | Storage architecture |
| 4 | "Does it work with files?" | Security, coordinates |
| 5 | "Does it talk to internet/devices?" | Async, error handling |
| 6 | "What's similar that exists?" | UX expectations |

### Follow-Up Branches (Based on Answers)

**If images/video:**
- Processing needed? (crop, resize, filters)
- -> Flag: Load `21_coordinate-systems.md` during implementation

**If macOS app:**
- Access user files outside sandbox?
- Run at startup?
- -> Flag: Load `22_macos-platform.md`

**If for distribution:**
- App Store or direct?
- -> Flag: Notarization, sandboxing

**If complex UI:**
- Main screen layout?
- Interactions? (lists, drag-drop, panels)
- -> Flag: May need `20_swiftui-gotchas.md`

---

## Phase 3: Triangulate (2-3 minutes)

Cross-reference answers for consistency:

```
1. Do the stated needs match the complexity level?
   - "Just for me" + complex features = scope creep risk

2. Do platform choices support the features?
   - Web app + native file access = architecture mismatch

3. Are there contradictions?
   - "Simple" + "handles all edge cases" = needs clarification
```

**If inconsistencies found:**
> "I noticed [X] and [Y] seem to conflict. Can you clarify?"

---

## Phase 4: Synthesize (3-5 minutes)

Create structured outputs:

### 4.1: Write Spec

Create `specs/[feature-name].md`:

```markdown
# [Feature Name] Spec

## Overview
[One paragraph summary]

## User Stories
- As a [user], I want [action] so that [benefit]

## Acceptance Criteria
- [ ] [Testable criterion]
- [ ] [Testable criterion]

## Technical Considerations
- [Architecture note]
- [Dependency note]

## Edge Cases
- [Edge case and how to handle]

## Out of Scope
- [Explicitly excluded]
```

### 4.2: Update PROJECT_STATE.md

- Set funnel to `define`
- Note spec created
- List flags for relevant docs

### 4.3: Map to Architecture

Use `04_architecture-decisions.md` to translate answers to tech choices.

---

## Phase 5: Validate (1-2 minutes)

Confirm understanding:

> "Here's what I understood:
> - [Summary point 1]
> - [Summary point 2]
> - [Summary point 3]
>
> Acceptance criteria:
> - [Criterion 1]
> - [Criterion 2]
>
> Does this capture it? Anything to add or change?"

**If corrections:**
- Update spec
- Re-triangulate if needed

**If confirmed:**
> "Spec complete. Ready to move to planning? Run `/plan` to create implementation tasks."

---

## Quick Modes

| Mode | When | Duration |
|------|------|----------|
| `/interview` | New project or feature | 15-20 min |
| `/interview quick` | Small feature, clear scope | 5-7 min |
| `/interview deep` | Complex system, many unknowns | 30+ min |

## Interview Tips

- Ask one question at a time
- "I don't know" is a valid answer (note for later exploration)
- Watch for scope creep - revisit boundaries if growing
- Don't solve during discovery - just understand

---
*Good specs prevent 80% of implementation problems.*
