<!--
TRIGGERS: claude command, CLI, MCP, hooks, slash command, permissions, keyboard shortcut
PHASE: any
LOAD: sections
-->

# Claude Code Reference

*Complete reference for Claude Code CLI features, commands, and configuration.*

---

## Quick Start

```bash
# Install
npm install -g @anthropic-ai/claude-code

# Verify
claude --version

# Start
claude
```

---

## Essential Commands

### Session Management

| Command | Description |
|---------|-------------|
| `/clear` | Reset conversation history |
| `/continue` or `-c` | Resume most recent conversation |
| `/resume [sessionId]` | Restore specific session |
| `/compact` | Summarize and compress context |

### Configuration

| Command | Description |
|---------|-------------|
| `/config` | Interactive settings wizard |
| `/model` | Switch between available models |
| `/memory` | Edit CLAUDE.md project guidelines |
| `/cost` | Display token usage and billing |

### Tools & Integration

| Command | Description |
|---------|-------------|
| `/mcp` | Manage Model Context Protocol servers |
| `/agents` | Configure specialized sub-agents |
| `/doctor` | Run system diagnostics |
| `/help` | Access documentation |

### Mode Switching

| Command | Description |
|---------|-------------|
| `/plan` | Enter planning mode |
| `Shift+Tab` (twice) | Toggle plan mode |

---

## Keyboard Shortcuts

| Shortcut | Function |
|----------|----------|
| `Ctrl+C` | Cancel current operation |
| `Ctrl+D` | Exit session |
| `Ctrl+L` | Clear screen (preserves history) |
| `Up/Down` | Browse command history |
| `Option+Enter` (macOS) | Multiline input |
| `Shift+Enter` | Multiline input (after setup) |
| `\` + `Enter` | Escape sequence for line breaks |
| `Esc` | Cancel current input |
| `Tab` | Autocomplete |

---

## Thinking Keywords

Add these to prompts for extended reasoning (higher token cost):

| Keyword | Effect |
|---------|--------|
| `think` | Minimal reasoning boost |
| `think hard` | Medium planning enhancement |
| `think harder` | Deeper analysis |
| `ultrathink` | Maximum reasoning |

**Example:**
```
Think hard about the architecture before implementing this feature.
```

---

## Memory Hierarchy

Claude Code uses four-tier memory (higher tiers override lower):

| Tier | Location | Scope |
|------|----------|-------|
| 1. Enterprise | `/Library/Application Support/ClaudeCode/CLAUDE.md` | Organization-wide |
| 2. User | `~/.claude/CLAUDE.md` | Personal (all projects) |
| 3. Project | `./CLAUDE.md` | Team-shared |
| 4. Local | `./CLAUDE.local.md` | Personal sandbox (not committed) |

**Recommendation:** Use `CLAUDE.md` for team rules, `CLAUDE.local.md` for personal preferences.

### Progressive Context Loading

For large projects (50K+ LOC), use the **router pattern**:
- Main CLAUDE.md as lean index (50-100 lines)
- Domain docs loaded conditionally based on task
- Nested CLAUDE.md files auto-load per directory
- Achieves **95-98% token reduction**

**See:** `Directions-PROGRESSIVE-CONTEXT.md` for complete guide.

---

## Configuration Files

### Global Settings (`~/.claude.json`)

```json
{
  "theme": "dark",
  "autoUpdates": true,
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-filesystem"]
    }
  }
}
```

### Project Settings (`.claude/settings.json`)

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(swift build)",
      "Bash(swift test)",
      "Bash(xcodebuild *)",
      "Bash(ls *)",
      "Read",
      "Edit",
      "Write"
    ]
  }
}
```

### Setting Configuration

```bash
# Set model
claude config set model "claude-sonnet-4-20250514"

# Set global theme
claude config set -g theme dark

# View current config
claude config list
```

---

## Permission System

### Tool Allowlisting

```bash
# Allow specific tools
claude --allowedTools "Edit,Read"

# Allow scoped bash commands
claude --allowedTools "Bash(git:*)"

# Allow pattern-matched commands
claude --allowedTools "Bash(npm:*),Bash(swift:*)"
```

### Dangerous Mode (Testing Only)

```bash
# Bypasses ALL safety checks - use only for testing
claude --dangerously-skip-permissions
```

**Warning:** Never use in production or on untrusted codebases.

---

## MCP (Model Context Protocol)

### Managing Servers

```bash
# List configured servers
claude mcp list

# Add a server
claude mcp add <name> <command>

# Remove a server
claude mcp remove <name>
```

### Recommended Servers

| Server | Purpose |
|--------|---------|
| `filesystem` | Extended file access |
| `github` | Repository management |
| `memory` | Cross-conversation storage |
| `puppeteer` | Browser automation |

### Configuration

Global: `~/.claude.json`
Project: `.mcp.json`

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

---

## Sub-Agents

Configure specialized AI assistants with isolated contexts:

```bash
claude /agents
```

### Example Roles

| Role | Purpose |
|------|---------|
| `planner` | Architecture and planning |
| `codegen` | Code generation |
| `tester` | Test writing |
| `reviewer` | Code review |
| `docs` | Documentation |

Sub-agents have scoped tool access for safety.

---

## Hooks System

Execute custom scripts on Claude Code events:

### Configuration (`.claude/settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "./scripts/pre-edit-hook.sh"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [{
          "type": "command",
          "command": "./scripts/format-code.sh"
        }]
      }
    ]
  }
}
```

### Available Events

| Event | When Triggered |
|-------|----------------|
| `PreToolUse` | Before a tool executes |
| `PostToolUse` | After a tool completes |
| `UserPromptSubmit` | When user sends a message |
| `Stop` | When generation stops |
| `SessionStart` | When session begins |

### Hook Environment

- Hooks receive JSON via stdin with event details
- `CLAUDE_PROJECT_DIR` environment variable available

---

## Output Modes

### Interactive (Default)

```bash
claude
```

Full terminal interface with streaming.

### Print Mode (Non-Interactive)

```bash
claude -p "What does this code do?"
```

Single response, then exits.

### Piped Input

```bash
cat file.txt | claude -p "Summarize this"
git diff | claude -p "Review these changes"
```

### JSON Output

```bash
claude -p "query" --output-format stream-json
```

Structured output for scripting.

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API authentication |
| `ANTHROPIC_MODEL` | Override default model |
| `BASH_DEFAULT_TIMEOUT_MS` | Command timeout |
| `MAX_THINKING_TOKENS` | Extended reasoning limit |
| `DISABLE_TELEMETRY` | Opt out of analytics |
| `HTTP_PROXY` / `HTTPS_PROXY` | Proxy configuration |
| `CLAUDE_PROJECT_DIR` | Project directory (in hooks) |

### Setting API Key

```bash
# macOS/Linux (persistent)
echo 'export ANTHROPIC_API_KEY="sk-your-key"' >> ~/.zshrc
source ~/.zshrc

# Windows PowerShell
$env:ANTHROPIC_API_KEY = "sk-your-key"

# Windows CMD
set ANTHROPIC_API_KEY=sk-your-key
```

---

## GitHub Actions Integration

### PR Auto-Review

```yaml
name: Claude Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          mode: review
```

### Available Modes

| Mode | Purpose |
|------|---------|
| `review` | PR code review with inline comments |
| `security` | Security vulnerability scanning |
| `triage` | Issue labeling and severity |

---

## Slash Commands

### Built-in Commands

Create `.claude/commands/` directory for custom commands.

**Example: `.claude/commands/review.md`**
```markdown
Do a git diff and act like a senior dev reviewing this code.

Check for:
1. Crashes and nil handling
2. Security issues
3. Logic errors
4. Threading bugs

Be specific. Quote the code. Explain why it's wrong.
```

**Usage:**
```
/project:review
```

### Command Arguments

Use `$ARGUMENTS` placeholder:

```markdown
# .claude/commands/debug.md
This isn't working: $ARGUMENTS

Add diagnostic logging to trace what's happening.
```

**Usage:**
```
/project:debug the save button doesn't work
```

---

## Troubleshooting

### Command Not Found

Check PATH includes npm global bin:
```bash
# macOS/Linux
echo $PATH
npm config get prefix

# Add to PATH if needed
export PATH="$(npm config get prefix)/bin:$PATH"
```

### Verify Installation

```bash
claude --version
claude doctor
which claude  # macOS/Linux
where claude  # Windows
```

### Node.js Version

Requires Node.js 18+ (20+ recommended):
```bash
node --version
```

### Clean Reinstall

```bash
# Uninstall
npm uninstall -g @anthropic-ai/claude-code

# Remove config (optional)
rm -rf ~/.claude

# Reinstall
npm install -g @anthropic-ai/claude-code
```

### MCP Issues

```bash
# Check MCP status
claude mcp list

# Test specific server
claude mcp test <server-name>

# View MCP logs
claude --debug
```

---

## Security Best Practices

1. **API Keys:** Store in environment variables, never in code
2. **Permissions:** Start restrictive, expand as needed
3. **Hooks:** Review scripts before enabling
4. **Config Files:** Protect with `chmod 600 ~/.claude.json`
5. **MCP Servers:** Use trusted sources only
6. **.gitignore:** Add `CLAUDE.local.md` and sensitive configs

---

## System Requirements

| Requirement | Specification |
|-------------|---------------|
| OS | macOS 10.15+, Ubuntu 20.04+, Windows 10/11, WSL |
| RAM | 4GB minimum, 8GB+ recommended |
| Node.js | 18+ (20+ recommended) |
| Network | Internet connection for API |

---

## Quick Reference Card

```
Start:          claude
Exit:           Ctrl+D
Cancel:         Ctrl+C
Clear:          /clear or Ctrl+L
Resume:         claude -c
Plan mode:      Shift+Tab (twice) or /plan
Config:         /config
Help:           /help

Thinking:       think / think hard / think harder / ultrathink
Multi-line:     Option+Enter (macOS) or \+Enter
```

---

*Based on the [zebbern/claude-code-guide](https://github.com/zebbern/claude-code-guide) and official documentation.*
