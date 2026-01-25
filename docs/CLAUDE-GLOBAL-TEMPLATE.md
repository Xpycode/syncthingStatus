# Global Claude Instructions (Template)

**Copy this to `~/.claude/CLAUDE.md` and customize paths.**

---

## Session Start: Auto-Detect and Resume

At the start of every session, **automatically run Project Detection (below)** to determine project state.

After detection:
- If Directions exists → show current status and ask what to work on
- If no Directions → offer to set it up, then show commands menu

**Available commands:**

| Command | What it does |
|---------|--------------|
| `/setup` | Re-run project detection, set up or migrate Directions |
| `/status` | Check current phase, focus, blockers, last session |
| `/log` | Create or update today's session log |
| `/decide` | Record an architectural/design decision |
| `/interview` | Run the full discovery interview |
| `/learned` | Add a term to your personal glossary |
| `/reorg` | Reorganize folder structure (numbered folders) |
| `/directions` | Show all available commands |
| `/phase` | Change project phase |
| `/context` | Show project context summary |
| `/handoff` | Generate handoff document for future sessions |
| `/blockers` | Log and track blockers |
| `/review` | Interactive production checklist |
| `/new-feature` | Scaffold docs for new feature |
| `/update-directions` | Pull latest Directions from GitHub |

---

## Project Detection (Run automatically on session start)

Check the project state and act accordingly:

### Step 1: Check for Directions

```
Does docs/00_base.md exist?
```

**YES → Directions is set up.** Follow "Existing Projects with Directions" below.

**NO → Continue to Step 2.**

---

### Step 2: Check for Existing /docs Folder

```
Does a /docs folder exist (but without 00_base.md)?
```

**YES → Has docs but not Directions structure.**

Offer options:
> "Found a `/docs` folder but it's not the Directions system. How should I handle this?
> 1. **Rename to /old-docs** - Move existing docs aside, set up Directions in /docs
> 2. **Merge** - Add Directions files into existing /docs structure
> 3. **Separate** - Keep /docs as-is, put Directions in /directions
> 4. **Ignore** - Don't set up Directions, just work with what's here"

If they choose 1, 2, or 3:
- Set up Directions in chosen location
- Read existing docs to extract: project purpose, decisions made, architecture hints
- Run gap interview for missing info
- Populate PROJECT_STATE.md, decisions.md from what was found

**NO → Continue to Step 3.**

---

### Step 3: Check for Scattered Markdown Files

```
Are there .md files in the project (not in /docs)?
```

**YES → Has scattered docs, no structure.**

Offer options:
> "Found markdown files but no organized docs structure. Options:
> 1. **Migrate** - Move existing MDs to /old-docs, set up Directions in /docs, extract useful info
> 2. **Fresh start** - Ignore existing MDs, set up Directions clean
> 3. **Ignore** - Don't set up Directions"

If they choose 1:
- Create `/old-docs` folder
- Move all `.md` files (except README.md) to `/old-docs`
- Set up Directions in `/docs`
- Read `/old-docs`, extract info → populate `/docs`
- Run gap interview

**NO → Continue to Step 4.**

---

### Step 4: New Empty Project

No docs, no MDs, minimal files.

> "This looks like a new project. What are you building? (One sentence is fine - I'll ask follow-up questions.)"

Then:
> "Want me to set up the Directions documentation system?"

If yes, set up Directions by **executing this command** (do not create files manually):

```bash
# Primary: Copy from local master (includes all reference guides)
mkdir -p docs && cp -r /path/to/LLM-Directions/* ./docs/

# Fallback if local not available: Clone from GitHub
# git clone https://github.com/Xpycode/LLM-Directions.git docs
```

**Important:** Always copy ALL files from the source. Do not manually create a subset of files.

Then read `docs/00_base.md` and run the full discovery interview.

After the interview, create a `CLAUDE.md` in the project root with:
- Project name and description
- Tech stack decided
- Key architecture decisions
- Pointer to `docs/00_base.md`

---

## Existing Projects with Directions

If `docs/00_base.md` exists:

1. Read it (refresh on the system)
2. Check `docs/PROJECT_STATE.md` for current phase/focus
3. Check `docs/sessions/_index.md` for what happened last time
4. Read the latest session log if continuing work
5. Continue from where we left off

---

## Migration: Reading Existing Docs

When migrating from existing docs, look for:

| Look For | Extract To |
|----------|------------|
| Project description, goals | PROJECT_STATE.md |
| Technical decisions, "we chose X" | decisions.md |
| Architecture notes, patterns | CLAUDE.md tech stack section |
| TODOs, plans, phases | PROJECT_STATE.md current focus |
| Bug notes, issues found | Session log or debugging notes |
| API docs, specs | Keep in /old-docs for reference |

After extraction, run a **gap interview**:
> "I've read your existing docs. Here's what I found: [summary].
> I still need to understand: [list gaps].
> Can we fill these in?"

---

## General Preferences

### Git Discipline
- Never commit directly to main
- Create feature branches: `feature/`, `fix/`, `experiment/`
- Commit messages: what + why
- Remind me about branching before implementation

### Communication Style
- Be direct, skip unnecessary preamble
- Ask clarifying questions when unsure
- Offer relevant docs from Directions when keywords match triggers
- Remind me about terminology references when I'm searching for words

### Quality
- Test the actual user flow, not just "build succeeded"
- Log decisions to `docs/decisions.md` when architectural choices are made
- Update session logs after significant progress

---

## Directions Location

Customize these paths for your setup:

- **GitHub:** https://github.com/Xpycode/LLM-Directions
- **Local master:** /path/to/your/LLM-Directions

---

*Copy to ~/.claude/CLAUDE.md and customize paths.*
