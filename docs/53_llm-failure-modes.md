# LLM Failure Modes

A taxonomy of how LLMs break down during AI-assisted development, and how to recognize/mitigate each failure.

## Why This Matters

LLMs fail in predictable ways. Knowing these patterns helps you:
- Recognize problems early
- Apply targeted fixes
- Avoid triggering failures
- Know when to restart vs. continue

## The 16 Failure Modes

### Category 1: Generation Failures

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Hallucination** | Model invents facts, APIs, or code that doesn't exist | Confident claims about nonexistent methods, wrong import paths, fabricated documentation | Verify claims. Ask for sources. Test code immediately. |
| **Symbolic Collapse** | Structured output becomes malformed | Broken JSON, mismatched braces, invalid syntax, type errors | Request smaller chunks. Validate each piece. Use typed schemas. |
| **Creative Freeze** | Repetitive, generic outputs | Same Bootstrap patterns, identical error messages, cookie-cutter responses | Change prompt framing. Provide counter-examples. Start fresh context. |
| **Knowledge Boundary Violation** | Confident answers beyond actual knowledge | Claims about post-training events, specific version numbers, proprietary APIs | Ask "are you certain?" Verify against docs. Assume outdated info. |

### Category 2: Context Failures

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Context Drift** | Information shifts meaning across conversation | Earlier decisions forgotten, contradictory statements, "didn't we decide X?" | Anchor with files. Summarize decisions. Use PROJECT_STATE.md. |
| **Memory Coherence Loss** | Facts/relationships forgotten mid-session | Reintroducing already-discussed patterns, forgetting file locations, repeated questions | Reference files explicitly. Keep context under 60%. Spawn subagents. |
| **System Prompt Drift** | Core instructions overridden by conversation | Behavioral changes, ignoring established patterns, style shifts | Re-anchor to CLAUDE.md. Explicit reminders. Fresh session if severe. |
| **Entropy Collapse** | Quality degrades as complexity increases | Increasingly vague responses, "let me know if you need more", incomplete implementations | Break into smaller tasks. Fresh context for each. Wave-based execution. |

### Category 3: Retrieval Failures (RAG)

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Retrieval Collapse** | Search returns irrelevant results | Wrong files referenced, missing obvious matches, "I couldn't find..." for existing code | Try different search terms. Read files directly. Use Glob patterns. |
| **Embedding vs Semantic Mismatch** | Vector similarity ≠ actual relevance | Similar-looking but wrong code, adjacent files confused, interface/implementation mixed | Verify by reading. Don't trust "similar" matches. Check imports. |
| **Vectorstore Fragmentation** | Gaps in searchable content | Some files never found, inconsistent results, "works sometimes" | Explicit file paths. Read target files directly. Don't rely on search. |

### Category 4: Reasoning Failures

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Logic Collapse** | Reasoning chains break | Invalid conclusions, steps that don't follow, circular reasoning | Request step-by-step. Verify each step. Challenge conclusions. |
| **Multi-Agent Chaos** | Parallel agents create conflicts | Duplicate work, contradictory changes, merge conflicts, deadlocks | Clear task boundaries. No overlapping files. Sequential for shared state. |

### Category 5: Injection & Security

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Prompt Injection** | User input manipulates behavior | Unexpected actions, ignoring safety guidelines, "the user said to..." | Treat user input as data. Validate actions. Don't execute blindly. |

### Category 6: Deployment Failures

| Mode | What Happens | Signs | Mitigation |
|------|--------------|-------|------------|
| **Deployment Deadlock** | Stuck in failed state | Retry loops, same error repeatedly, can't proceed or rollback | Manual intervention. Fresh session. Explicit state reset. |
| **Predeploy Collapse** | Passes generation, fails validation | Build errors, type errors, test failures on "complete" code | Always build/test. Don't trust "should work". Incremental validation. |

## Frequency in Development

**High (expect these regularly):**
- Hallucination
- Context Drift
- Symbolic Collapse (especially JSON/types)
- Knowledge Boundary Violation
- Predeploy Collapse

**Medium (hit these sometimes):**
- Memory Coherence Loss
- Retrieval Collapse
- Logic Collapse
- Creative Freeze
- System Prompt Drift

**Lower but critical:**
- Multi-Agent Chaos
- Embedding Mismatch
- Prompt Injection
- Deployment Deadlock

## Detection Patterns

### Hallucination Check
```
You said [X]. Can you verify this exists in the actual codebase?
Show me where [API/method] is defined.
What file contains [claim]?
```

### Context Drift Check
```
What was our decision about [topic]?
Summarize the current state.
What files have we modified?
```

### Logic Collapse Check
```
Walk through your reasoning step by step.
Why does [step N] follow from [step N-1]?
What could make this conclusion wrong?
```

## Prevention Strategies

### For Hallucination
1. Verify claims against actual code before accepting
2. Ask "where is this defined?" for any API mention
3. Test code immediately, don't batch
4. Assume model is wrong about version-specific features

### For Context Degradation
1. Keep context under 60% capacity
2. Use files as external memory
3. Spawn subagents for heavy implementation
4. Summarize don't duplicate

### For Retrieval Issues
1. Provide explicit file paths when possible
2. Read files directly rather than search
3. Verify search results by reading
4. Don't trust "similar" matches

### For Reasoning Breakdown
1. Break complex reasoning into steps
2. Verify each step before proceeding
3. Use structured formats (checklists, tables)
4. Challenge conclusions

## Quick Reference

```
Model being too confident?
├── Check for hallucination
├── Verify against actual code
└── Ask for sources

Quality dropping?
├── Check context usage
├── Spawn subagent with fresh context
└── Anchor to files (PROJECT_STATE.md)

Search not finding things?
├── Try explicit file paths
├── Use Glob patterns
└── Read files directly

Reasoning seems wrong?
├── Request step-by-step breakdown
├── Challenge each step
└── Try alternative approaches

Output malformed?
├── Request smaller chunks
├── Validate incrementally
└── Use typed schemas
```

## Anti-Patterns

**Don't:**
- Trust confident claims without verification
- Continue when quality is degrading
- Let context exceed 60% for complex tasks
- Rely on search for critical files
- Accept "should work" without testing

**Do:**
- Verify code exists before discussing it
- Use fresh contexts for implementation
- Read files directly when possible
- Test incrementally
- Challenge conclusions

## Metrics for Detection

| Metric | Threshold | Action |
|--------|-----------|--------|
| Semantic Drift (ΔS) | > 0.45 | Re-anchor to source files |
| Context Usage | > 60% | Spawn subagent or fresh session |
| Repeated Errors | > 2 same error | Change approach |
| Contradictions | Any | Stop and clarify |
| "Should work" claims | Any | Require proof |

## Credits

Failure taxonomy adapted from [WFGY](https://github.com/onestardao/WFGY) semantic reasoning framework. Mitigations based on practical AI-assisted development experience.
