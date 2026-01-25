<!--
TRIGGERS: cheatsheet, quick lookup, shortcuts, daily reference, prompts, checklist
PHASE: any
LOAD: full
-->

# Quick Reference Card

*Print this. Keep it visible.*

---

## The Workflow (Every Feature)

```
SPEC → PLAN → IMPLEMENT → REVIEW → VERIFY → COMMIT
```

| Step | Action | Time |
|------|--------|------|
| **Spec** | Interview until clear | 10-30 min |
| **Plan** | Break into 30-min phases | 5-10 min |
| **Implement** | One phase at a time | <30 min each |
| **Review** | Adversarial, 2-3 passes | 5-10 min |
| **Verify** | Test actual user flow | 5 min |
| **Commit** | Clear message, move on | 2 min |

---

## Essential Prompts

### Spec Interview
```
Read SPEC.md and interview me in detail about
technical implementation, UI/UX, concerns, tradeoffs.
Keep asking until complete, then write the spec.
```

### Adversarial Review
```
Do a git diff and pretend you're a senior dev who
HATES this. What would you criticize? What edge cases?
```

### Debugging
```
This isn't working: [symptom]
Add diagnostic logging to trace what's happening.
```

### Architecture Check
```
Is this thread-safe? Should any classes be actors?
```

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Cancel operation | `Ctrl+C` |
| Exit session | `Ctrl+D` |
| Clear screen | `Ctrl+L` |
| Plan mode | `Shift+Tab` (twice) |
| Multiline input | `Option+Enter` (macOS) |
| Command history | `Up/Down` arrows |
| Escape line break | `\` + `Enter` |

---

## Claude Code Commands

| Command | Purpose |
|---------|---------|
| `/clear` | Reset conversation |
| `/continue` or `-c` | Resume last session |
| `/compact` | Compress context |
| `/config` | Settings wizard |
| `/model` | Switch models |
| `/cost` | Token usage |
| `/doctor` | Diagnostics |
| `/plan` | Enter plan mode |

---

## Thinking Keywords

| Keyword | When to Use |
|---------|-------------|
| `think` | Simple questions |
| `think hard` | Architecture decisions |
| `think harder` | Complex debugging |
| `ultrathink` | Security, critical code |

**Example:** `Think hard about the thread safety here.`

---

## Plan Mode

**Enter:** `Shift+Tab` twice (or `/plan`)

**Use for:**
- New features
- Comparing approaches
- Before any significant change

**Always ask:**
- Is each phase <30 min?
- Is each phase testable?
- Does each phase leave code working?

---

## Red Flags in Code

| See This | Ask This |
|----------|----------|
| `try?` | "Are we ignoring errors?" |
| `!` (force unwrap) | "What if this is nil?" |
| `@unchecked Sendable` | "Is this actually safe?" |
| 500+ line file | "Should this be split up?" |
| Class with shared state | "Should this be an actor?" |
| No error handling | "What happens on failure?" |

---

## Top 5 Bug Categories

| Bug | Symptom | Ask |
|-----|---------|-----|
| **Coordinates** | Wrong position/size | "Points or pixels?" |
| **UI not updating** | Changes don't show | "Is @Observable detecting this?" |
| **Race condition** | Intermittent crash | "Is this thread-safe?" |
| **Silent failure** | Feature doesn't work | "Are errors being swallowed?" |
| **Persistence** | Data lost on restart | "Is save actually happening?" |

---

## Project Files

```
project/
├── CLAUDE.md           ← Rules for AI
├── SPEC.md             ← Current feature
├── README.md           ← What it does
└── .claude/
    ├── commands/       ← Slash commands
    └── settings.json   ← Permissions
```

---

## CLAUDE.md Essentials

```markdown
# Project Name

## Tech Stack
- SwiftUI, async/await, JSON persistence

## Rules
- ViewModels: @MainActor
- Shared state: actors (not classes)
- Errors: handle explicitly (no try?)

## Critical (learned hard way)
- [Add bugs that took hours to find]
```

---

## NOW/NEXT/LATER

```markdown
## NOW (1-5 items max)
- [ ] The thing I'm doing today

## NEXT (after NOW)
- [ ] The thing after that

## LATER (ideas, not promises)
- Maybe someday
```

**Rule:** If NOW has >5 items, you're not prioritizing.

---

## Commit Checklist

Before committing:
- [ ] Adversarial review done (2-3 passes)
- [ ] Real bugs fixed (nitpicks ignored)
- [ ] Actually tested the user flow
- [ ] Build succeeds
- [ ] Clear commit message

---

## When Things Break

1. **Describe precisely** — not "broken," but exact symptom
2. **Add logging** — trace the actual execution
3. **Share logs** — let Claude analyze
4. **Document fix** — add comment if tricky

---

## Multi-Model Validation

**Use when:**
- Critical code (money, data, security)
- Architecture decisions
- Something feels off

**How:**
1. Claude reviews first
2. Copy to Gemini or another model
3. Compare findings
4. Fix what both agree on

---

## Review Focus

**Fix these:**
- Crashes (nil, empty array, missing handling)
- Security (unsanitized input, exposed secrets)
- Logic errors (wrong conditions, off-by-one)
- Threading (shared state, race conditions)

**Ignore these:**
- Style preferences
- Variable naming
- "Could be refactored"
- Over-engineering suggestions

---

## The Golden Rules

1. **Interview before coding** — specs prevent rework
2. **30-minute phases** — always be close to working
3. **Adversarial review** — Claude has false confidence
4. **Verify actual usage** — build success ≠ feature works
5. **Document the WHY** — prevent "fix it back to broken"

---

## Architecture Quick Picks

| Need | Use |
|------|-----|
| Thread-safe shared state | Actor |
| UI state | @MainActor ViewModel |
| Data storage | JSON files |
| Async operations | async/await |
| UI framework | SwiftUI |

---

## Debugging Questions

Ask these in order:
1. What exactly should happen?
2. What exactly does happen?
3. Where in the code does it go wrong?
4. What's the state at that point?
5. Why is the state wrong?

---

## Emergency Fixes

**Build won't succeed:**
```
Show me the exact error. Don't explain, just fix it.
```

**Feature stopped working:**
```
Do a git diff from last working commit.
What changed that could cause this?
```

**AI is confused:**
```
Let's start fresh. Here's what I need: [one sentence]
```

---

## Weekly Maintenance

- [ ] Review NOW list — still accurate?
- [ ] Move completed to DONE with dates
- [ ] Promote from NEXT if ready
- [ ] Remove LATER items you'll never do
- [ ] Update CLAUDE.md with new learnings

---

## Memory Files

| Level | File | Scope |
|-------|------|-------|
| User | `~/.claude/CLAUDE.md` | All projects |
| Project | `./CLAUDE.md` | Team shared |
| Local | `./CLAUDE.local.md` | Personal (not committed) |

---

## Related Guides

| Need | Guide |
|------|-------|
| Full learning | Directions-LEARNING-GUIDE.md |
| Step-by-step | Directions-CURRICULUM.md |
| Claude Code CLI | Directions-CLAUDE-CODE-REFERENCE.md |
| Large project context | Directions-PROGRESSIVE-CONTEXT.md |
| SwiftUI bugs | Directions-SWIFTUI-GOTCHAS.md |
| Coordinates | Directions-COORDINATE-SYSTEMS.md |
| macOS specifics | Directions-MACOS-PLATFORM.md |
| AI context template | Directions-AI-CONTEXT-TEMPLATE.md |
| Pre-release | Directions-PRODUCTION-CHECKLIST.md |
| App minimums | 33_app-minimums.md |
| Doc templates | Directions-DOCUMENTATION-TEMPLATES.md |

---

*When in doubt: Spec → Plan → Small phases → Review → Verify*
