# Implementation Plan: Directions v2.0 Plugin

**Created:** 2025-01-11
**Goal:** Convert Directions into a full Claude Code plugin with hooks, new commands, and MCP server

---

## Prerequisites

- [x] Directions repo exists at `/Users/sim/XcodeProjects/0-DIRECTIONS/__DIRECTIONS/`
- [x] Git synced with GitHub
- [x] Basic commands already working in `~/.claude/commands/`

---

## Phase 1: Plugin Structure (Foundation)

**Estimated effort:** Quick setup

### Tasks

- [x] Create `.claude-plugin/plugin.json` manifest
  ```json
  {
    "name": "directions",
    "version": "2.0.0",
    "description": "AI-assisted development with session management and workflow automation"
  }
  ```

- [x] Create `scripts/` directory for hook scripts

- [x] Create `hooks/` directory with empty `hooks.json`

- [x] Create `mcp-server/` directory for future MCP server

- [x] Create `skills/directions-workflow/SKILL.md` with methodology summary

- [x] Test: Verify Claude Code recognizes it as a plugin
  ```bash
  # Symlink to plugins folder
  ln -sf /Users/sim/XcodeProjects/0-DIRECTIONS/__DIRECTIONS ~/.claude/plugins/local/directions
  ```

### Deliverables
- Plugin recognized by Claude Code
- Directory structure ready for components

---

## Phase 2: Core Hooks

**Estimated effort:** Medium - requires Python scripts

### Task 2.1: SessionStart Hook

- [x] Create `scripts/session-start.py`
  - Check if `docs/00_base.md` exists in project
  - If yes: Read PROJECT_STATE.md, get current phase/focus
  - Read latest session from sessions/_index.md
  - Return JSON with system message containing context
  - If no: Return message about non-Directions project

- [x] Add to `hooks/hooks.json`:
  ```json
  {
    "hooks": {
      "SessionStart": [{
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "python3 ${CLAUDE_PLUGIN_ROOT}/scripts/session-start.py",
          "timeout": 10
        }]
      }]
    }
  }
  ```

- [x] Test: Start new Claude session in a Directions project, verify context loads

### Task 2.2: Stop Hook

- [x] Add Stop hook to `hooks/hooks.json`:
  ```json
  "Stop": [{
    "matcher": "*",
    "hooks": [{
      "type": "prompt",
      "prompt": "Before stopping: Was significant work done? Check if today's session log exists in docs/sessions/. If work was done but not logged, remind to run /log first. Approve if logged or trivial session."
    }]
  }]
  ```

- [x] Test: Do some work, try to stop, verify prompt appears

### Deliverables
- Auto-context loading on session start
- Session logging reminder on stop

---

## Phase 3: New Slash Commands

**Estimated effort:** Medium - 6 new markdown files

### Task 3.1: /phase Command

- [x] Create `commands/phase.md`
  - Show current phase from PROJECT_STATE.md
  - List available phases: discovery → planning → implementation → polish → shipping
  - Update PROJECT_STATE.md with new phase + timestamp
  - Suggest relevant docs for new phase

### Task 3.2: /context Command

- [x] Create `commands/context.md`
  - Read PROJECT_STATE.md (phase, focus, blockers)
  - Read last 3 sessions from sessions/_index.md
  - Read last 3 decisions from decisions.md
  - Display concise summary

### Task 3.3: /handoff Command

- [x] Create `commands/handoff.md`
  - Read today's session log
  - Read PROJECT_STATE.md
  - Read recent decisions
  - Generate comprehensive handoff document
  - Save to sessions/handoff-YYYY-MM-DD.md

### Task 3.4: /blockers Command

- [x] Create `commands/blockers.md`
  - Ask what's blocking
  - Ask what was tried
  - Ask what would unblock
  - Add to PROJECT_STATE.md blockers section

### Task 3.5: /review Command

- [x] Create `commands/review.md`
  - Load 30_production-checklist.md
  - Go through each item interactively
  - Log failures
  - Generate review report

### Task 3.6: /new-feature Command

- [x] Create `commands/new-feature.md`
  - Ask feature name (kebab-case)
  - Ask one-sentence description
  - Create docs/features/[name].md with template
  - Add entry to PROJECT_STATE.md

### Deliverables
- 6 new commands available via /command

---

## Phase 4: Advanced Hooks

**Estimated effort:** Medium

### Task 4.1: Doc Suggester Hook

- [x] Create `scripts/doc-suggester.py`
  - Parse user prompt for keywords
  - Map keywords to docs:
    - coordinates/position/image → 21_coordinate-systems.md
    - UI not updating/refresh → 20_swiftui-gotchas.md
    - sandbox/bookmark/entitlements → 22_macos-platform.md
    - debug/bug/broken → 31_debugging.md
    - ship/release/production → 30_production-checklist.md
  - Return system message suggesting doc if match found

- [x] Add UserPromptSubmit hook to hooks.json

- [x] Test: Mention "coordinates" in prompt, verify suggestion appears

### Task 4.2: Decision Reminder Hook

- [x] Add PostToolUse hook for git commits:
  ```json
  "PostToolUse": [{
    "matcher": "Bash",
    "hooks": [{
      "type": "prompt",
      "prompt": "If this Bash command was a git commit with architectural changes (new patterns, tech choices, structural changes), suggest running /decide. Otherwise continue silently."
    }]
  }]
  ```

### Deliverables
- Automatic doc suggestions based on conversation
- Decision logging reminders after commits

---

## Phase 5: MCP Server ⏸️ DEFERRED

**Status:** Deferred - slash commands and hooks provide sufficient functionality
**Estimated effort:** Larger - requires MCP protocol implementation

### Task 5.1: Basic Server Setup

- [ ] Create `mcp-server/requirements.txt`
  ```
  mcp
  ```

- [ ] Create `mcp-server/server.py` skeleton
  - Import MCP server framework
  - Define server class
  - Register tools and resources

- [ ] Create `.mcp.json` at plugin root:
  ```json
  {
    "directions": {
      "command": "python3",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp-server/server.py"],
      "env": {
        "DIRECTIONS_ROOT": "${CLAUDE_PROJECT_DIR}/docs"
      }
    }
  }
  ```

### Task 5.2: Implement Core Tools

- [ ] `get_project_state` - Read and return PROJECT_STATE.md
- [ ] `update_phase` - Update phase in PROJECT_STATE.md
- [ ] `log_decision` - Append to decisions.md
- [ ] `get_session_history` - List recent sessions
- [ ] `get_blockers` - Return blockers from PROJECT_STATE.md
- [ ] `add_blocker` - Add blocker to PROJECT_STATE.md
- [ ] `resolve_blocker` - Mark blocker resolved

### Task 5.3: Implement Resources

- [ ] `directions://state` - Live PROJECT_STATE.md
- [ ] `directions://decisions` - Live decisions.md
- [ ] `directions://sessions` - Session index

### Task 5.4: Test MCP Integration

- [ ] Run `/mcp` to verify tools appear
- [ ] Test each tool individually
- [ ] Verify resources are accessible

### Deliverables
- Working MCP server with 7 tools and 3 resources
- Programmatic access to project state

---

## Phase 6: Polish & Documentation

**Estimated effort:** Quick

### Tasks

- [x] Update `README.md`
  - Add plugin installation instructions
  - Document all commands (old + new)
  - Explain hooks behavior
  - ~~Document MCP tools~~ (deferred)

- [x] Update `CLAUDE-GLOBAL-TEMPLATE.md`
  - Add new commands to table
  - Update installation to use plugin method

- [x] Create `install-directions.sh`
  ```bash
  #!/bin/bash
  DIRECTIONS_REPO="${1:-$(pwd)}"
  PLUGIN_DIR="$HOME/.claude/plugins/local/directions"
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  ln -sf "$DIRECTIONS_REPO" "$PLUGIN_DIR"
  echo "Directions plugin installed. Restart Claude Code."
  ```

- [x] Update `/update-directions` command
  - Pull git changes
  - Remind to restart Claude for hook changes

- [x] Commit and push all changes

### Deliverables
- Complete documentation
- Easy installation script
- Updated commands

---

## Verification Checklist

After all phases complete:

- [ ] Start new Claude session → context auto-loads
- [ ] Run /phase → phase changes and persists
- [ ] Run /context → shows accurate summary
- [ ] Run /handoff → creates handoff doc
- [ ] Run /blockers → logs blocker to PROJECT_STATE
- [ ] Run /review → runs through checklist
- [ ] Run /new-feature → scaffolds feature docs
- [ ] Say "image position" → doc suggested
- [ ] Do work, try to stop → prompted about logging
- [ ] Make commit → reminded about decisions (if architectural)
- [ ] Run /mcp → Directions tools appear
- [ ] Test MCP tool calls → work correctly

---

## Order of Implementation

**Session 1:** Phase 1 + Phase 2 (plugin structure + core hooks)
**Session 2:** Phase 3 (new commands)
**Session 3:** Phase 4 + Phase 6 (advanced hooks + polish)
**Session 4:** Phase 5 (MCP server) - optional, can defer

---

## Notes for Next Session

Start with:
```
Read docs/sessions/implementation-plan-directions-v2.md
Begin with Phase 1: Plugin Structure
```

The most impactful pieces are:
1. **SessionStart hook** - immediate value, auto-context
2. **/context command** - quick status check
3. **Stop hook** - prevents forgetting to log

MCP server is nice-to-have and can be done last or deferred.

---

## Files Summary

**Create:**
```
.claude-plugin/plugin.json
hooks/hooks.json
scripts/session-start.py
scripts/doc-suggester.py
mcp-server/server.py
mcp-server/requirements.txt
.mcp.json
commands/phase.md
commands/context.md
commands/handoff.md
commands/blockers.md
commands/review.md
commands/new-feature.md
skills/directions-workflow/SKILL.md
install-directions.sh
```

**Modify:**
```
README.md
CLAUDE-GLOBAL-TEMPLATE.md
commands/update-directions.md
```
