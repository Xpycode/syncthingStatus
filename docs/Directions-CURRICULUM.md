# Prompt Developer Curriculum

**A progressive path from first app to production workflow.**

---

## How to Use This Curriculum

Each level builds on the previous. Don't skip ahead—the fundamentals compound.

| Level | Focus | Time Investment |
|-------|-------|-----------------|
| Level 1 | First working feature | 2-4 hours |
| Level 2 | Complete feature workflow | 1-2 days |
| Level 3 | Project organization | 1 day |
| Level 4 | Quality and reliability | Ongoing |
| Level 5 | Advanced patterns | As needed |
| Level 6 | Claude Code mastery | 1-2 days |

**Milestone:** Each level ends with a concrete deliverable. Don't move on until you've completed it.

---

## Level 1: Your First Working Feature

### Learning Goals
- Complete the spec → plan → implement → review cycle
- Experience the 30-minute milestone pattern
- See adversarial review catch real issues

### Lesson 1.1: The Spec Interview

**Concept:** Good specs prevent rework.

**Exercise:**
1. Create a new file called `SPEC.md`
2. Write a one-line description: "A button that shows the current time when tapped"
3. Start Claude and paste:
   ```
   Read SPEC.md and interview me about this feature.
   Ask about UI placement, format, edge cases, and implementation.
   Write the complete spec when done.
   ```
4. Answer Claude's questions honestly

**Milestone:** You have a 200-500 word spec for a simple feature.

### Lesson 1.2: Planning in Phases

**Concept:** Big features fail. Small phases succeed.

**Exercise:**
1. Enter Plan mode (Shift+Tab twice, or `/plan`)
2. Tell Claude:
   ```
   Break this into phases. Each phase must be completable
   in under 30 minutes and result in something I can test.
   ```
3. Review the phases. Push back if any seems too big.

**Milestone:** You have 2-4 phases, each clearly testable.

### Lesson 1.3: Implementation with Verification

**Concept:** Watch the AI work. Verify each step.

**Exercise:**
1. Tell Claude: "Implement phase 1 and verify it works"
2. Watch what Claude does:
   - Does it explain its approach?
   - Does it create files in sensible places?
   - Does it actually test at the end?
3. If Claude doesn't verify, prompt: "Run the app and confirm the button appears"

**Milestone:** Phase 1 is complete and verified.

### Lesson 1.4: Adversarial Review

**Concept:** Claude has false confidence. Challenge it.

**Exercise:**
1. After implementation, paste:
   ```
   Do a git diff and pretend you're a senior dev who HATES this.
   What would you criticize? What edge cases am I missing?
   ```
2. Read the feedback. Categorize each issue:
   - Real bug → Fix it
   - Security issue → Fix it
   - Style nitpick → Ignore
3. Tell Claude which issues to fix
4. Run the adversarial review again
5. Repeat until only nitpicks remain

**Milestone:** Feature is reviewed and real issues are fixed.

### Level 1 Complete When:
- [ ] You've written a spec through interview
- [ ] You've planned in phases
- [ ] You've implemented with verification
- [ ] You've done 2-3 adversarial review passes
- [ ] You have working code that does what the spec describes

---

## Level 2: Complete Feature Workflow

### Learning Goals
- Handle multi-phase features
- Use Plan mode effectively
- Commit working code
- Debug when things break

### Lesson 2.1: A Real Feature

**Concept:** Apply the workflow to something useful.

**Exercise:**
Choose one of these (or your own idea):
- A settings screen with 3 toggles that persist
- A list view that loads data from a JSON file
- A timer with start/stop/reset buttons

Complete the full cycle:
1. Spec interview
2. Phase planning (aim for 3-5 phases)
3. Implement phase by phase
4. Review after each phase
5. Commit when each phase works

**Milestone:** A working feature with 3+ commits.

### Lesson 2.2: When Things Break

**Concept:** Debugging is communication.

**Exercise:**
1. When something doesn't work, describe the symptom precisely:
   - Bad: "It's broken"
   - Good: "I tap the button, the label should show the time, but nothing happens"
2. Ask Claude to add logging:
   ```
   Add diagnostic logging to trace what happens when I tap the button.
   Log the state at each step.
   ```
3. Run the app, capture the logs
4. Share logs with Claude and ask what's wrong

**Milestone:** You've debugged a problem using logs.

### Lesson 2.3: Plan Mode Deep Dive

**Concept:** Plan mode is for exploring before committing.

**Exercise:**
1. Enter Plan mode for a feature
2. Ask Claude to show you 2-3 different approaches
3. Ask about tradeoffs:
   ```
   What are the pros and cons of each approach?
   Which is simpler? Which is more flexible?
   ```
4. Choose an approach and have Claude write the plan
5. Exit Plan mode only when you're confident in the direction

**Milestone:** You've compared approaches before implementing.

### Lesson 2.4: The Commit Workflow

**Concept:** Commits mark working milestones.

**Exercise:**
1. Create `.claude/commands/commit.md`:
   ```markdown
   1. Run git status and git diff
   2. Summarize what changed
   3. Write a clear commit message
   4. Stage and commit
   ```
2. After each working phase, use `/project:commit`
3. Practice the rhythm: implement → review → verify → commit

**Milestone:** You have 3+ commits with clear messages.

### Level 2 Complete When:
- [ ] You've built a multi-phase feature
- [ ] You've debugged using logging
- [ ] You've used Plan mode to compare approaches
- [ ] You've committed after each stable phase
- [ ] Your git log shows clear progress

---

## Level 3: Project Organization

### Learning Goals
- Set up CLAUDE.md effectively
- Create reusable slash commands
- Configure permissions to reduce friction
- Organize project structure

### Lesson 3.1: CLAUDE.md — Teaching AI Your Preferences

**Concept:** Rules compound. Add them as you learn.

**Exercise:**
1. Create `CLAUDE.md` in your project root
2. Start with this minimal template:
   ```markdown
   # [Project Name]

   ## Tech Stack
   - SwiftUI
   - async/await for concurrency
   - JSON for persistence

   ## Rules
   - ViewModels must be @MainActor
   - Use actors for shared state, not classes
   - Always handle errors explicitly (no try?)
   ```
3. Each time Claude makes a mistake, add a rule
4. Each time you re-explain something, add context

**Milestone:** CLAUDE.md has 5+ rules you've learned.

### Lesson 3.2: Slash Commands

**Concept:** Reusable prompts save time and ensure consistency.

**Exercise:**
1. Create `.claude/commands/` directory
2. Create these three commands:

**review.md:**
```markdown
Do a git diff and act like a senior dev who hates this code.
Check for: crashes, security issues, logic errors, threading bugs.
Be specific. Quote the code. Explain why it's wrong.
```

**debug.md:**
```markdown
This isn't working: $ARGUMENTS

Add diagnostic logging to trace what's happening.
Explain what should occur at each step.
```

**explain.md:**
```markdown
Explain this code like I'm a non-coder:
$ARGUMENTS

What does it do? Why is it written this way?
What could go wrong?
```

3. Test each command

**Milestone:** You have 3+ working slash commands.

### Lesson 3.3: Permissions

**Concept:** Pre-approve common commands to reduce friction.

**Exercise:**
1. Create `.claude/settings.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "Bash(git *)",
         "Bash(swift build)",
         "Bash(swift test)",
         "Bash(ls *)",
         "Bash(cat *)"
       ]
     }
   }
   ```
2. Add commands as you use them
3. Notice which prompts you keep approving—add those

**Milestone:** Common operations don't require approval.

### Lesson 3.4: Project Structure

**Concept:** Consistent structure reduces cognitive load.

**Exercise:**
1. Ask Claude to organize your project:
   ```
   Organize this project into:
   - Models/ (data structs)
   - Services/ (business logic actors)
   - ViewModels/ (@MainActor UI state)
   - Views/ (SwiftUI views)
   Move files accordingly.
   ```
2. Verify everything still works after reorganization
3. Add structure notes to CLAUDE.md

**Milestone:** Project has clear folder organization.

### Level 3 Complete When:
- [ ] CLAUDE.md has project-specific rules
- [ ] You have 3+ slash commands
- [ ] Permissions are configured
- [ ] Project has organized folder structure
- [ ] New features go in the right places automatically

---

## Level 4: Quality and Reliability

### Learning Goals
- Multi-model validation
- Documentation that helps future you
- Understanding code enough to validate
- Handling complex debugging

### Lesson 4.1: Multi-Model Review

**Concept:** Different models catch different bugs.

**Exercise:**
1. After Claude reviews code, also ask Gemini:
   - Copy the code diff
   - Ask Gemini to review it adversarially
2. Compare what each found
3. Create a command that consults multiple models:
   ```markdown
   Review this code using multiple perspectives.
   Use the zen tools to get opinions from different models.
   Synthesize the feedback.
   ```

**Milestone:** You've caught a bug one model missed.

### Lesson 4.2: Documentation for Future You

**Concept:** Comments explain WHY, not WHAT.

**Exercise:**
1. When you fix a tricky bug, ask Claude:
   ```
   Add a comment explaining WHY this code is written this way.
   Future me might think it's wrong and "fix" it.
   Reference this bug so the context is preserved.
   ```
2. Create a README with:
   - "Why This Tool Exists" section
   - Screenshot of the main interface
   - Quick start guide
   - Known issues/limitations

**Milestone:** README has screenshots and "why" section.

### Lesson 4.3: Reading Code for Validation

**Concept:** You don't need to write code, but recognize problems.

**Exercise:**
1. Ask Claude to explain code patterns:
   ```
   Explain this code like I'm a non-coder.
   What are the warning signs I should look for?
   What questions should I ask when reviewing similar code?
   ```
2. Learn to spot these red flags:
   - `try?` (errors silently ignored)
   - `!` force unwrap (crash on nil)
   - Large files (>500 lines)
   - No error handling in async code
3. When reviewing, ask about each red flag you spot

**Milestone:** You can identify 3+ code smells.

### Lesson 4.4: Complex Debugging

**Concept:** Hard bugs require systematic investigation.

**Exercise:**
1. For an intermittent bug, create a debugging session:
   ```
   This bug happens sometimes: [describe]

   Let's investigate systematically:
   1. What are the possible causes?
   2. How can we determine which one it is?
   3. Add logging to narrow down.
   ```
2. Use the debug → log → analyze → hypothesis → test cycle
3. Document the root cause when found

**Milestone:** You've solved a bug that took multiple attempts.

### Level 4 Complete When:
- [ ] You've used multi-model review
- [ ] Documentation has "why" context
- [ ] You can spot basic code smells
- [ ] You've systematically debugged a complex issue
- [ ] Your CLAUDE.md has "Critical Rules" section

---

## Level 5: Advanced Patterns

### Learning Goals
- Architecture decisions
- Performance considerations
- Security awareness
- Long-term project health

### Lesson 5.1: Architecture Patterns

**Concept:** Some patterns prevent entire categories of bugs.

**Study these patterns:**

| Pattern | When to Use | Ask Claude |
|---------|-------------|------------|
| Actors | Shared state between parts of app | "Should this be an actor?" |
| ViewModels | UI state and logic | "Is UI logic in the view? Move to ViewModel." |
| JSON Persistence | Saving app state | "Use JSON, not Core Data." |
| Feature Flags | Migrating between approaches | "Add a feature flag for this change." |

**Exercise:** Ask Claude to explain when each pattern applies in your project.

**Milestone:** You understand when to request each pattern.

### Lesson 5.2: Performance Awareness

**Concept:** Some things are slow. Know which.

**Study these performance patterns:**

| Issue | Symptom | Solution |
|-------|---------|----------|
| Main thread blocking | UI freezes | "Move this off main thread" |
| Unbounded growth | Memory increases over time | "Add a limit to this collection" |
| Repeated work | Slow operations | "Cache this result" |
| Large images | Memory pressure | "Thumbnail this image" |

**Exercise:** Ask Claude to audit your project for performance issues:
```
Check this code for performance problems.
What could be slow? What could use too much memory?
```

**Milestone:** You've identified and fixed a performance issue.

### Lesson 5.3: Security Basics

**Concept:** Some bugs are exploitable. Know the patterns.

**Study these security patterns:**

| Issue | Risk | Solution |
|-------|------|----------|
| Unsanitized input | Injection attacks | "Validate and sanitize this input" |
| Secrets in code | Credential leak | "Move to Keychain" |
| Path traversal | File access exploit | "Validate this path is within bounds" |
| Logging secrets | Credential leak | "Never log tokens or passwords" |

**Exercise:** Ask Claude to security review your project:
```
Do a security review. Check for:
- Unsanitized input
- Hardcoded secrets
- Path traversal possibilities
- Sensitive data in logs
```

**Milestone:** You've done a security review.

### Lesson 5.4: Project Health

**Concept:** Long-lived projects need maintenance.

**Weekly habits:**
1. Review NOW/NEXT/LATER lists
2. Move DONE items with dates
3. Remove things you'll never do
4. Update CLAUDE.md with new learnings

**Monthly habits:**
1. Check for abandoned files
2. Review error handling coverage
3. Update documentation with new features
4. Consider if any refactoring is needed

**Exercise:** Create a maintenance command:
```markdown
# .claude/commands/maintenance.md
Do a project health check:
1. Any TODOs in code that should be in the task list?
2. Any dead code that can be removed?
3. Any documentation out of date?
4. Any warnings from the build?
```

**Milestone:** You have a maintenance routine.

### Level 5 Complete When:
- [ ] You understand when to use actors vs classes
- [ ] You've done a performance audit
- [ ] You've done a security review
- [ ] You have a maintenance routine
- [ ] Your project can be handed off to future you

---

## Level 6: Claude Code Mastery

### Learning Goals
- Use Claude Code's advanced features effectively
- Set up MCP integrations
- Create custom hooks for automation
- Optimize workflow with thinking keywords

### Lesson 6.1: Thinking Keywords

**Concept:** Extended reasoning produces better results for complex tasks.

**Exercise:**
1. Take a complex architectural question
2. Ask it with different thinking levels:
   ```
   // Normal
   How should I structure authentication?

   // With thinking
   Think hard about how I should structure authentication.
   Consider security, maintainability, and edge cases.
   ```
3. Compare the depth of responses

**Thinking Levels:**
| Keyword | Use For |
|---------|---------|
| `think` | Quick clarifications |
| `think hard` | Architecture decisions |
| `think harder` | Complex debugging |
| `ultrathink` | Security review, critical code |

**Milestone:** You've used thinking keywords to get deeper analysis.

### Lesson 6.2: Memory Hierarchy

**Concept:** Organize rules at the right level.

**Exercise:**
1. Create user-level memory:
   ```bash
   mkdir -p ~/.claude
   touch ~/.claude/CLAUDE.md
   ```

2. Add personal preferences:
   ```markdown
   # Personal Preferences

   ## Style
   - I prefer concise responses
   - Show code examples, not just explanations

   ## Defaults
   - Use Swift 5.9+ features
   - Prefer SwiftUI over UIKit
   ```

3. Create project-level `CLAUDE.md` (team rules)
4. Create `CLAUDE.local.md` for personal project tweaks

**Memory Hierarchy:**
```
Enterprise → User → Project → Local
(highest priority)    (lowest priority)
```

**Milestone:** You have memory files at user and project level.

### Lesson 6.3: MCP Integration

**Concept:** Model Context Protocol extends Claude's capabilities.

**Exercise:**
1. List current MCP servers:
   ```bash
   claude mcp list
   ```

2. Add a useful server:
   ```bash
   # GitHub integration
   claude mcp add github npx @anthropic-ai/mcp-github

   # Or memory for cross-session storage
   claude mcp add memory npx @anthropic-ai/mcp-memory
   ```

3. Configure in project (`.mcp.json`):
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

4. Test the integration

**Milestone:** You have at least one MCP server configured.

### Lesson 6.4: Custom Hooks

**Concept:** Automate repetitive tasks with hooks.

**Exercise:**
1. Create a pre-commit format hook (`.claude/settings.json`):
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Write",
           "hooks": [{
             "type": "command",
             "command": "swift-format format --in-place $FILE"
           }]
         }
       ]
     }
   }
   ```

2. Create a notification hook:
   ```json
   {
     "hooks": {
       "Stop": [{
         "type": "command",
         "command": "osascript -e 'display notification \"Claude finished\" with title \"Claude Code\"'"
       }]
     }
   }
   ```

**Hook Events:**
- `PreToolUse` — Before tool runs
- `PostToolUse` — After tool completes
- `UserPromptSubmit` — When you send a message
- `Stop` — When generation stops
- `SessionStart` — When session begins

**Milestone:** You have at least one custom hook working.

### Lesson 6.5: Workflow Automation

**Concept:** Combine features for efficient workflows.

**Exercise:**
1. Create a complete review workflow:

   `.claude/commands/full-review.md`:
   ```markdown
   Think hard about this code review.

   1. Run git diff
   2. Check for thread safety issues
   3. Check for memory leaks
   4. Check for error handling
   5. Check for security issues
   6. Summarize findings by severity

   Be thorough. This is going to production.
   ```

2. Create a session-start checklist:

   `.claude/commands/start.md`:
   ```markdown
   Starting a new session. Please:
   1. Read CLAUDE.md for project rules
   2. Check git status for current state
   3. Read the last entry in SESSION-LOG.md
   4. Summarize: what's the current state and what should we work on?
   ```

3. Test both commands

**Milestone:** You have reusable workflow commands.

### Level 6 Complete When:
- [ ] You use thinking keywords appropriately
- [ ] You have multi-level memory configured
- [ ] You have at least one MCP server
- [ ] You have custom hooks
- [ ] You have workflow automation commands
- [ ] You can explain when to use each feature

---

## Graduation: The Full Workflow

You've completed the curriculum when you can do this smoothly:

### New Feature Workflow
```
1. Write one-line spec
2. Spec interview → full spec
3. Plan mode → phases
4. Implement phase by phase
5. Adversarial review each phase
6. Multi-model review for critical parts
7. Verify with actual usage
8. Commit with clear message
9. Update documentation
```

### Bug Fix Workflow
```
1. Describe symptom precisely
2. Claude investigates (don't guess)
3. Add logging if needed
4. Identify root cause
5. Plan the fix
6. Implement and verify
7. Add "why" comment if tricky
8. Commit
```

### Maintenance Workflow
```
Weekly: Review task lists
Monthly: Health check
Per-feature: Update docs
Per-bug: Add to CLAUDE.md if pattern
```

---

## Continuing Education

### When You Hit a Wall

1. **Same bug keeps coming back** → Add to CLAUDE.md Critical Rules
2. **AI keeps misunderstanding** → Improve your spec or CLAUDE.md
3. **Features take too long** → Break into smaller phases
4. **Quality is inconsistent** → Add more slash commands for consistency
5. **Lost in complexity** → Consider starting fresh with lessons learned

### Resources

**Core Guides:**
- This curriculum → Step-by-step learning
- Directions-LEARNING-GUIDE.md → Comprehensive reference
- Directions-QUICK-REFERENCE.md → Daily checklist

**Claude Code:**
- Directions-CLAUDE-CODE-REFERENCE.md → CLI features, MCP, hooks
- Directions-PROGRESSIVE-CONTEXT.md → Router pattern, 95% token reduction

**Technical References:**
- Directions-SWIFTUI-GOTCHAS.md → Common SwiftUI bugs
- Directions-COORDINATE-SYSTEMS.md → Points vs pixels
- Directions-MACOS-PLATFORM.md → macOS-specific patterns

**Templates:**
- Directions-AI-CONTEXT-TEMPLATE.md → AI context files
- Directions-DOCUMENTATION-TEMPLATES.md → README, CHANGELOG, etc.
- Directions-PRODUCTION-CHECKLIST.md → Pre-release verification

**Your Knowledge Base:**
- Your CLAUDE.md → Project rules you've learned
- Your SESSION-LOG.md → Session history

---

*The goal isn't to know everything. It's to have a reliable process that produces working software.*
