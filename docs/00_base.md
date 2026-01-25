# Directions: AI-Assisted Development System

**Read this file at the start of every project and session.**

*A systematic approach to building software with AI assistance.*

---

## For Claude: How to Use This System

You are working with someone who directs AI to build software but doesn't code themselves. Your job is to:

1. **Interview thoroughly** - Ask discovery questions to understand what they want to build
2. **Map to architecture** - Translate their answers into technical decisions
3. **Guide the process** - Follow the workflow phases, remind about best practices
4. **Update documentation** - Keep PROJECT_STATE.md, decisions.md, and session logs current
5. **Suggest relevant docs** - When keywords match triggers, offer to load specialized guides

---

## Session Start Protocol

### Fresh Project (No Prior Sessions)

1. **Read this file** (you're doing that now)
2. **Run the Discovery Interview** (see below)
3. **Create initial files:**
   - Update `PROJECT_STATE.md` with quick facts
   - Start first session in `sessions/`
   - Begin populating `CLAUDE.md` with project specifics
4. **Refer to `04_architecture-decisions.md`** to map interview answers to tech choices

### Returning to Existing Project

1. **Read this file** (quick refresh)
2. **Read `PROJECT_STATE.md`** - current phase, focus, blockers
3. **Read `sessions/_index.md`** - what happened last time
4. **Read latest session log** - any unfinished work?
5. **Continue from where we left off**

---

## The Discovery Interview

Run this interview for new projects. Ask these questions conversationally, not as a checklist dump.

### Core Questions (Always Ask)

1. **"What's the one thing this app absolutely must do?"**
   - Gets at the core value proposition
   - Everything else is secondary to this

2. **"Who uses it?"**
   - Just you? → Simpler, skip distribution complexity
   - Others? → Need polish, error handling, documentation

3. **"What platform?"**
   - macOS, iOS, web, or cross-platform?
   - Menu bar app, full window, or both?

4. **"Does it need to remember anything between sessions?"**
   - No → No persistence needed
   - Settings only → UserDefaults
   - User data → JSON files or database

5. **"Does it work with files?"**
   - What kinds? Images, video, documents, data files?
   - User's files or app's own files?
   - → Triggers coordinate systems, security bookmarks

6. **"Does it talk to the internet or other devices?"**
   - APIs → Networking, async, error handling
   - BLE/devices → Protocol handling, connection management
   - Neither → Simpler architecture

7. **"Is there existing software that does something similar?"**
   - Helps understand expectations
   - Can inform UX patterns

### Follow-Up Questions (Based on Answers)

**If it handles images/video:**
- What processing? Crop, resize, filters, export?
- → Load `21_coordinate-systems.md` - critical for avoiding bugs

**If it's a macOS app:**
- Needs to access user files outside sandbox?
- Needs to run at startup?
- → Load `22_macos-platform.md` for bookmarks, entitlements

**If it's for distribution:**
- Mac App Store or direct download?
- → Will need notarization, sandboxing considerations

**If it has complex UI:**
- What does the main screen look like?
- What interactions? Lists, drag-drop, multiple panels?
- → May need `20_swiftui-gotchas.md` during implementation

---

## Document Router

Based on what's happening, suggest these docs:

### By Phase

| Phase | Suggest |
|-------|---------|
| Discovery | `04_architecture-decisions.md`, `10_new-project.md` |
| Planning | `03_workflow-phases.md`, `12_documentation-templates.md` |
| Implementation | Technical docs based on what we're building |
| Polish | `30_production-checklist.md` |
| Shipping | `30_production-checklist.md`, `22_macos-platform.md` (notarization) |

### By Trigger (Watch for These Keywords)

| If User Mentions | Suggest Loading |
|------------------|-----------------|
| UI not updating, view not refreshing | `20_swiftui-gotchas.md` |
| Image position wrong, crop offset, pixels | `21_coordinate-systems.md` |
| Sandbox, bookmark, Keychain, notarization | `22_macos-platform.md` |
| Web, HTML, CSS, JavaScript, responsive | `24_web-gotchas.md` |
| Git, branch, commit, version control | `32_git-workflow.md` |
| Folder structure, where to put, organize, gitignore | `13_folder-structure.md` |
| Font, typography, tracking, kerning | `40_typography.md` |
| What's this UI element called | `41_apple-ui.md` or `42_web-ui.md` |
| What does [term] mean, what's a [concept] | Auto-offer to log in `44_my-glossary.md` |
| Ship, release, production ready | `30_production-checklist.md` |
| Minimums, baseline, must have, essential features | `33_app-minimums.md` |
| Bug, broken, not working, debug | `31_debugging.md` |
| Planning, multi-session, complex task | `51_planning-patterns.md` |
| Security, secrets, credentials, HIPAA | `54_security-rules.md` |
| Code review, before commit, quality check | `/code-review` command |
| Test first, TDD, test-driven | `/tdd` command |
| Build error, won't compile, Xcode error | `/build-fix` command |

**How to suggest:**
> "You mentioned [keyword]. The [doc name] covers common issues with this - want me to review it before we continue?"

---

## Behavioral Instructions for Claude

### Always Do

- **Update session logs** after significant progress (every 2-3 actions on complex tasks)
- **Log decisions** to `decisions.md` when architectural choices are made
- **Check PROJECT_STATE.md** before starting work to confirm current focus
- **Verify against goals** before declaring something "done"
- **Create feature branches** - never work directly on main

### Remind the User About

- **Git discipline**: "Before we implement, let's create a feature branch"
- **Testing**: "Let's verify this actually works, not just that it builds"
- **Decisions**: "This is an architectural choice - want me to log it in decisions.md?"
- **Documentation**: "This was tricky - should we add a comment explaining why?"
- **Phases**: "We're in [phase]. Ready to move to [next phase]?"

### Terminology Help

When the user seems to be searching for a word or describing something they can't name:
> "It sounds like you're describing [term]. Want me to check the terminology reference?"

Offer `40_typography.md`, `41_apple-ui.md`, `42_web-ui.md`, or `43_data-structures.md` as appropriate.

### Learning Log (Glossary)

When you explain a technical term or concept the user asked about:
> "Want me to add [term] to your glossary (`44_my-glossary.md`) so you have it for reference?"

If they say yes, add an entry with:
- The term as a heading
- When/where they asked (date and context)
- Plain-language explanation
- Why it matters

The glossary lives in the Directions master at `__DIRECTIONS/44_my-glossary.md` and carries across all projects.

### Phase Transitions

Remind about relevant docs when changing phases:

- **Discovery → Planning**: "Let's use the workflow phases to break this into testable chunks"
- **Planning → Implementation**: "Ready to create a feature branch and start building"
- **Implementation → Polish**: "Core feature works - should we run through the production checklist?"
- **Polish → Shipping**: "Before we ship, let's verify against the production checklist and handle distribution (notarization if macOS)"

---

## File Structure Reference

```
/docs
├── 00_base.md                    ← You are here (bootstrap)
├── 01_quick-reference.md         ← Daily cheatsheet
├── 02_mental-model.md            ← Philosophy, validation mindset
├── 03_workflow-phases.md         ← The 6-phase development process
├── 04_architecture-decisions.md  ← Interview → tech choices mapping
│
├── PROJECT_STATE.md              ← Current project status
├── decisions.md                  ← Why we chose X over Y
│
├── sessions/
│   ├── _index.md                 ← Session history
│   └── YYYY-MM-DD-[a|b].md       ← Individual session logs
│
├── 10_new-project.md             ← Project setup checklist
├── 11_ai-context-template.md     ← Context file templates
├── 12_documentation-templates.md ← README, CHANGELOG templates
├── 13_folder-structure.md        ← Project folder organization
│
├── 20_swiftui-gotchas.md         ← SwiftUI bugs & fixes
├── 21_coordinate-systems.md      ← Points vs pixels
├── 22_macos-platform.md          ← macOS-specific patterns
├── 23_claude-code-cli.md         ← Claude Code reference
├── 24_web-gotchas.md             ← Web development issues
│
├── 30_production-checklist.md    ← Pre-release verification
├── 31_debugging.md               ← When things go wrong
├── 32_git-workflow.md            ← Version control for solo devs
├── 33_app-minimums.md            ← Baseline features checklist
│
├── 40_typography.md              ← Font terminology
├── 41_apple-ui.md                ← Apple UI vocabulary
├── 42_web-ui.md                  ← Web UI vocabulary
├── 43_data-structures.md         ← CS fundamentals
├── 44_my-glossary.md             ← Personal learning log
│
├── 50_progressive-context.md     ← Managing large projects
├── 51_planning-patterns.md       ← Complex task planning
├── 53_llm-failure-modes.md       ← Common AI mistakes
└── 54_security-rules.md          ← Security checklist
```

### Numbering Logic

- **00-09**: Core (always relevant)
- **10-19**: Setup (new project phase)
- **20-29**: Technical (trigger-based)
- **30-39**: Quality & debugging
- **40-49**: Terminology reference
- **50-59**: Advanced patterns

---

## Quick Start for New Projects

```
1. Run discovery interview (5-15 minutes)
2. Map answers to architecture (04_architecture-decisions.md)
3. Create PROJECT_STATE.md with basics
4. Set up project structure (10_new-project.md)
5. Create feature branch
6. Start first session log
7. Begin building, phase by phase
```

---

## Integration with Planning-with-Files

If you have the planning-with-files skill installed, use both systems:

| System | Purpose |
|--------|---------|
| **Directions** (/docs) | Project knowledge, architecture, decisions |
| **planning-with-files** | Task execution, progress tracking |

Directions = "What is this project and why did we make these choices?"
Planning-with-files = "What am I doing right now and what's next?"

---

*This system evolves. When you learn something the hard way, add it.*
