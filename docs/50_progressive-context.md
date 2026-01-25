<!--
TRIGGERS: token limit, context too big, CLAUDE.md bloated, large project, 50K lines
PHASE: any
LOAD: on-request
-->

# Progressive Context Loading Guide

*From 150K to 2K tokens: The router pattern for large projects.*

---

## The Problem

As projects grow, monolithic CLAUDE.md files become problematic:

| Issue | Impact |
|-------|--------|
| **Token waste** | 400+ line CLAUDE.md consumes context even when 90%+ is irrelevant |
| **Attention dilution** | Claude tries to follow all rules simultaneously → confusion |
| **Maintenance overhead** | One giant file becomes unwieldy |

**Solution:** Progressive context loading—load only documentation relevant to the current task.

---

## The Router Pattern

Create a **lean main CLAUDE.md** (50-100 lines) that serves as a router, with detailed docs split into topic-specific files loaded only when needed.

### Directory Structure

```
project/
├── CLAUDE.md                    # Main router (lean, always loaded)
├── docs/
│   ├── frontend-guidelines.md   # Loaded only for frontend work
│   ├── backend-api-patterns.md  # Loaded only for backend work
│   ├── testing-standards.md     # Loaded only when writing tests
│   ├── deployment-guide.md      # Loaded only for deployment
│   └── security-guidelines.md   # Loaded only for auth/security
└── src/
    ├── frontend/
    │   └── CLAUDE.md            # Nested context for frontend/
    └── backend/
        └── CLAUDE.md            # Nested context for backend/
```

---

## Basic Router Example

**Main CLAUDE.md:**

```markdown
# Project: My App

## Core Stack
- Frontend: SwiftUI
- Backend: Swift actors
- Persistence: JSON files

## Essential Rules (Always Apply)
- Use async/await, never completion handlers
- ViewModels must be @MainActor
- Services must be actors

## Conditional Documentation
**Read these files ONLY when working on specific tasks:**

### UI Work
- **When:** Modifying Views or ViewModels
- **Read:** @docs/swiftui-patterns.md
- **Contains:** Component patterns, state management

### Data Layer
- **When:** Working on Services or persistence
- **Read:** @docs/data-architecture.md
- **Contains:** Actor patterns, JSON persistence

### Testing
- **When:** Writing or fixing tests
- **Read:** @docs/testing-standards.md
- **Contains:** Test structure, mocking patterns

## How to Use This Documentation
1. Read this main file first
2. Identify which conditional docs apply to your task
3. Read ONLY the relevant conditional docs
4. Do NOT load all docs simultaneously
```

---

## The "Pitch" Pattern

Explain **why** and **when** to read files—dramatically improves Claude's loading decisions:

```markdown
## Extended Documentation (Load Conditionally)

### Coordinate Systems Documentation
**File:** @docs/coordinate-systems.md
**When to read:**
- If working with image cropping or positioning
- When debugging "off by 2x" visual bugs
- If mixing NSImage and CGImage operations
**Why it matters:**
Contains Retina scaling rules and origin system documentation
that prevents the #1 category of image processing bugs.
**DO NOT load immediately—only access for image/video work.**

### Thread Safety Patterns
**File:** @docs/concurrency-patterns.md
**When to read:**
- If creating new Services or Managers
- When debugging race conditions or crashes
- If seeing @MainActor or Sendable errors
**Why it matters:**
Our actor patterns differ from basic examples—specific
isolation rules that must be followed.
**For simple View work, you do NOT need this file.**
```

---

## Nested CLAUDE.md Pattern

Claude Code automatically discovers nested CLAUDE.md files in subdirectories.

**How it works:**
- **Root CLAUDE.md**: Always loaded at session start
- **Subdirectory CLAUDE.md**: Loaded only when Claude reads/edits files in that directory

### Example Structure

**Root CLAUDE.md:**
```markdown
# My App

## Global Standards
- Swift 5.9+
- SwiftUI for all UI
- async/await for concurrency

## Directory-Specific Context
Each module has its own CLAUDE.md with specialized rules.
These load automatically when you work in that directory.
```

**Sources/Views/CLAUDE.md:**
```markdown
# Views Module Context

## Patterns
- All Views are structs
- Use @Observable ViewModels
- Co-locate View and ViewModel

## State Management
- @State for view-local only
- @Environment for shared state
- Never mutate state during body computation
```

**Sources/Services/CLAUDE.md:**
```markdown
# Services Module Context

## Requirements
- ALL services must be actors
- Use async/await exclusively
- Cache results where appropriate

## Error Handling
- Never use try? silently
- Log errors with context
- Propagate to UI layer
```

---

## Explicit Trigger Language

### Weak (Often Ignored)

```markdown
See docs/testing.md for testing information.
```

### Strong (Reliably Followed)

```markdown
**IMPORTANT: Before writing ANY tests, you MUST read @docs/testing-standards.md**

This file contains:
- Required test structure patterns
- Mocking strategies for our architecture
- Coverage requirements that fail CI if not met

DO NOT attempt to write tests without reading this file first.
```

---

## "DO NOT Load" Directives

Explicitly tell Claude **not** to load files immediately:

```markdown
## API Documentation Reference

**File:** @docs/api/openapi-spec.md

**DO NOT load this file at session start.**

**Only read when:**
- Implementing new API endpoints
- User asks about API contract
- Debugging API integration issues

**Why wait:** This file is 15,000 tokens. Loading it for
non-API work wastes context.
```

---

## Custom Loading Commands

Create slash commands to explicitly load context:

**File: `.claude/commands/study.md`**
```markdown
# /study Command

When user types `/project:study authentication`:
1. Read @docs/auth/authentication-flow.md
2. Read @docs/auth/security-patterns.md
3. Summarize key points
4. Say "Auth context loaded. Ready to work."

When user types `/project:study frontend`:
1. Read @docs/swiftui-patterns.md
2. Read Sources/Views/CLAUDE.md
3. Summarize component patterns
4. Say "Frontend context loaded."
```

**Usage:**
```
> /project:study authentication
[Claude loads all auth docs]
> Now implement token refresh logic
[Claude applies loaded context]
```

---

## Token Reduction Results

Real-world data from production implementations:

| Approach | Tokens | Reduction |
|----------|--------|-----------|
| Monolithic CLAUDE.md | 150,000 | Baseline |
| Basic modularization | 45,000 | 70% |
| Conditional router pattern | 8,000 | **95%** |
| Skills-based progressive loading | 2,000 | **98.7%** |

**Benefits:**
- 3-5x faster response times
- Lower costs (fewer input tokens)
- Better focus (Claude sees only relevant rules)

---

## Recommended by Project Size

| Project Size | Approach | Strategy |
|--------------|----------|----------|
| **Small** (<10K LOC) | Single CLAUDE.md | Monolithic (50-150 lines) |
| **Medium** (10-50K LOC) | Router + 3-5 domain docs | Conditional routing |
| **Large** (50-200K LOC) | Nested CLAUDE.md + router | Hierarchical |
| **Very Large** (200K+ LOC) | Claude Skills | Progressive loading |
| **Multi-repo** | Sub-agent orchestration | Specialized agents |

---

## Migration Strategy

### Week 1: Audit and Categorize

```bash
# Categorize every CLAUDE.md section:
# - Core (always needed)
# - Frontend (conditional)
# - Backend (conditional)
# - Testing (conditional)
# - Domain-specific (conditional)
```

### Week 2: Extract Domain Files

```bash
mkdir -p docs/{frontend,backend,testing,deployment,security}

# Move frontend rules to docs/frontend-guidelines.md
# Move backend rules to docs/backend-api-patterns.md
# etc.
```

### Week 3: Create Router CLAUDE.md

```markdown
# New lean CLAUDE.md (50-100 lines max)

## Core Rules (10-20 lines)
[Only universal rules for EVERY task]

## Conditional Documentation (30-60 lines)
[Routing table with "when to read" conditions]
```

### Week 4: Test and Iterate

```bash
# Verify:
# 1. Claude loads correct docs automatically
# 2. Claude doesn't over-load docs
# 3. Use /context to check what's loaded
# 4. Adjust trigger language if needed
```

---

## Common Pitfalls

### Pitfall 1: Claude Ignores Conditionals

**Problem:** Claude loads all @-referenced files immediately.

**Solutions:**
1. Use stronger negative language:
   ```markdown
   **DO NOT load @docs/api-spec.md at startup.**
   ```

2. Separate references from instructions:
   ```markdown
   ## Available Documentation (Not Loaded Yet)
   - docs/api-spec.md (API contracts)

   ## When to Load These Files
   [Separate section with conditions]
   ```

### Pitfall 2: Nested CLAUDE.md Not Loading

**Problem:** Subdirectory CLAUDE.md doesn't load.

**Cause:** Claude only loads nested CLAUDE.md when it **actually reads/writes files** in that directory.

**Solution:**
```markdown
## Directory-Specific Context
When working in a subdirectory, ALWAYS read that directory's
CLAUDE.md first:
- Working in Sources/Views/? → Read Sources/Views/CLAUDE.md
- Working in Sources/Services/? → Read Sources/Services/CLAUDE.md
```

### Pitfall 3: Context Still Too Large

**Solutions:**
1. Use `/compact` to compress context
2. Start fresh sessions for different domains
3. Create specialized sub-agents with isolated context

---

## Advanced: Sub-Agent Orchestration

For very large projects, use orchestration with specialized Claude instances:

**Root CLAUDE.md (orchestrator):**
```markdown
# Orchestrator Agent

## Your Role
You are a coordinator, NOT an implementer.
You DO NOT modify code files directly.

## How to Accomplish Tasks
1. Identify which module is affected
2. Spawn a headless Claude instance in that subdirectory:
   ```bash
   cd src/frontend && claude --headless "implement feature"
   ```
3. The subdirectory Claude loads its own specialized CLAUDE.md
4. Monitor progress and coordinate between modules
5. Report back to user with summary
```

**Benefits:**
- Each domain Claude has focused context
- Root orchestrator maintains coordination
- Total context never exceeds single-domain scope

---

## Verification Commands

| Command | Purpose |
|---------|---------|
| `/context` | View currently loaded context |
| `/memory` | View all CLAUDE.md files discovered |
| `/compact` | Compress current context |
| `claude doctor` | Health check for configuration |

---

## Router Template

Copy this as a starting point:

```markdown
# [Project Name]

## Core Stack
- [Language/Framework]
- [Key libraries]

## Essential Rules (Always Apply)
- [Rule 1 - applies to everything]
- [Rule 2 - applies to everything]
- [Rule 3 - applies to everything]

## Conditional Documentation

### [Domain 1] Work
- **When:** [Trigger conditions]
- **Read:** @docs/[domain1]-guidelines.md
- **Contains:** [What's in the file]
- **DO NOT load unless working on [domain1]**

### [Domain 2] Work
- **When:** [Trigger conditions]
- **Read:** @docs/[domain2]-patterns.md
- **Contains:** [What's in the file]
- **DO NOT load unless working on [domain2]**

### [Domain 3] Work
- **When:** [Trigger conditions]
- **Read:** @docs/[domain3]-standards.md
- **Contains:** [What's in the file]
- **DO NOT load unless working on [domain3]**

## How to Use This Documentation
1. Read this main file first (you're doing it now)
2. Based on your current task, identify which conditional docs apply
3. Read ONLY the relevant conditional docs before starting work
4. Do NOT load all docs simultaneously—focus on what's needed
```

---

## Key Principles

1. **Main CLAUDE.md as index** (50-100 lines, always loaded)
2. **Domain-specific docs** split into separate files
3. **Explicit "when to read" conditions** using natural language
4. **"Pitch" pattern** explaining why and when docs matter
5. **Nested CLAUDE.md** for directory-specific context
6. **Progressive loading** only what's needed for current task

This achieves **95-98% token reduction** while maintaining comprehensive project knowledge.

---

## Sources

- [Progressive Context Loading Guide](https://www.remio.ai/post/mastering-claude-skills-progressive-context-loading-for-efficient-ai-workflows)
- [From 150K to 2K Tokens](https://williamzujkowski.github.io/posts/from-150k-to-2k-tokens-how-progressive-context-loading-revolutionizes-llm-development-workflows/)
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [How I Use Every Claude Code Feature](https://blog.sshh.io/p/how-i-use-every-claude-code-feature)

---

*For small-medium projects, the router pattern is ideal. For very large projects (200K+ LOC), consider Claude Skills for automatic progressive loading.*
