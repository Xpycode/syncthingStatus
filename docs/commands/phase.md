# Change Project Phase

Update the current project phase in PROJECT_STATE.md.

## Step 1: Show Current Phase

Read `docs/PROJECT_STATE.md` and display the current phase.

## Step 2: Show Available Phases

Present the phase options:

```
Project Phases:
1. discovery    - Understanding the problem, gathering requirements
2. planning     - Designing the solution, making architecture decisions
3. implementation - Building the core functionality
4. polish       - Refinement, edge cases, UX improvements
5. shipping     - Final testing, documentation, release prep
```

Ask: "Which phase is the project moving to?"

## Step 3: Update PROJECT_STATE.md

Update the **Phase:** line in `docs/PROJECT_STATE.md` with the new phase.

Add a timestamp comment: `<!-- Phase changed: YYYY-MM-DD -->`

## Step 3b: Review Readiness

When changing phase, prompt to review the Readiness section:

```
Current Readiness:
| Dimension    | Status |
|--------------|--------|
| Features     | [?]    |
| UI/Polish    | [?]    |
| Testing      | [?]    |
| Docs         | [?]    |
| Distribution | [?]    |

Update any dimensions? (y/n)
```

**For transitions to polish/shipping:** Require at least Features to be ✅ or 🔶.

## Step 4: Suggest Relevant Docs

Based on the new phase, suggest relevant documentation:

| Phase | Suggested Docs |
|-------|---------------|
| discovery | 10_new-project.md, 11_ai-context-template.md |
| planning | 04_architecture-decisions.md, 51_planning-patterns.md |
| implementation | 20_swiftui-gotchas.md, 21_coordinate-systems.md, 31_debugging.md |
| polish | 30_production-checklist.md, 33_app-minimums.md, 40_typography.md |
| shipping | 30_production-checklist.md, 33_app-minimums.md, 32_git-workflow.md |

**For polish/shipping phases**, also remind:
> "Have you run `/minimums` to check baseline features?"

## Step 5: Confirm

Display: "Phase updated to **[new phase]**. Suggested reading: [docs]"
