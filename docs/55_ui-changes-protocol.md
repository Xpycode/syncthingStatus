# UI Changes Protocol

Rules for adding, modifying, or removing UI elements in existing apps.

---

## The Problem

LLMs default to eager implementation. When asked to "add a toggle to the sidebar," they:
1. Search for something that sounds right (`Sidebar.swift`)
2. Add code there immediately
3. Wonder why it doesn't appear

The actual sidebar might render from a different view, use a separate component, or pull controls from a state object.

---

## The Rule: Explore → Propose → Confirm → Implement

### Before Implementation

| Step | Action |
|------|--------|
| 1. **Find similar** | Search for a comparable existing control in the app |
| 2. **Trace wiring** | Show where it's defined, how state flows, what triggers updates |
| 3. **Propose location** | State exactly which file, view, and line for the new element |
| 4. **Wait** | Do not implement until placement is confirmed |

### After Implementation

| Step | Action |
|------|--------|
| 5. **Verify** | Confirm the element appears in the running app |
| 6. **Test binding** | Ensure the control triggers its intended action |

---

## Example Workflow

**Request:** "Add an export toggle to the sidebar"

### ✅ Correct Approach

```
1. Find existing sidebar toggles
   → Found: `showPreview` toggle in SidebarView.swift:45
   → Bound to: AppState.showPreview
   → Rendered in: SidebarControlsSection

2. Trace the pattern
   → Toggle defined in SidebarControlsSection.swift
   → State lives in AppState, passed via @EnvironmentObject
   → onChange triggers AppState.togglePreview()

3. Propose
   → "I'll add exportEnabled toggle in SidebarControlsSection.swift:62"
   → "Following same pattern: @EnvironmentObject var appState"
   → "Bound to appState.exportEnabled"

4. Wait for confirmation

5. Implement after approval
```

### ❌ Wrong Approach

```
1. Search for "sidebar"
2. Find Sidebar.swift, looks right
3. Add toggle there immediately
4. Build succeeds
5. Toggle doesn't appear
6. "Let me find where the sidebar is actually rendered..."
```

---

## Applies To

- SwiftUI views and controls
- AppKit/UIKit controls
- Menu bar items
- Toolbar buttons
- Context menus
- Sheets and popovers
- Navigation elements
- Tab bars
- Settings/preferences panes

---

## Quick Prompt Templates

Use these when requesting UI changes:

**Standard:**
> "Before implementing, find an existing [control type] in the app and show me how it's wired up."

**Explicit exploration:**
> "Find where sidebar controls are rendered. Show me the file and pattern. Then propose where to add [new element]."

**With confirmation gate:**
> "Add [element] to [location]. First show me a similar existing element, propose placement, and wait for my OK before coding."

---

## Adding to Project CLAUDE.md

Reference this doc in project instructions:

```markdown
## UI Changes

Follow the protocol in `docs/55_ui-changes-protocol.md`:
- Find similar existing element first
- Trace the wiring pattern
- Propose location and wait for confirmation
- Verify after implementation
```

Or inline the key rule:

```markdown
## UI Changes

When adding UI elements: find a similar existing control first, show me how it's wired, propose placement, and wait for confirmation before implementing.
```

---

## Related

- `/spec` — Creates feature specification with exploration phase
- `/plan` — Implementation planning with task breakdown
- `54_security-rules.md` — Similar "check first" pattern for security
