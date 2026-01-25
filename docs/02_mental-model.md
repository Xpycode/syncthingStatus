<!--
TRIGGERS: philosophy, mindset, how to think, validate code, spot bugs, red flags, prompt developer
PHASE: any
LOAD: full
-->

# The Prompt Developer's Mental Model

**You are a director, not a coder.**

*How to think about AI-assisted development and validate the output.*

---

## Part 1: The Mental Model

### You Are a Director, Not a Coder

Think of yourself as a film director. You don't operate the camera or edit the footage yourself, but you need to:

- Know what a good shot looks like
- Communicate your vision clearly
- Recognize when something is wrong
- Know when to call "cut" and try again

The same applies to prompt-based development:

| Film Director | Prompt Developer |
|---------------|------------------|
| Knows cinematography principles | Knows software architecture patterns |
| Gives clear shot directions | Writes detailed specs and prompts |
| Reviews dailies for quality | Reviews code output adversarially |
| Uses multiple takes | Uses multiple AI models for validation |

### The Core Insight

> "AI-assisted development requires MORE discipline, not less. The tools amplify both good practices and bad practices."

What this means for you:
- Vague prompts → vague, buggy code
- No verification → bugs ship silently
- Single AI review → critical bugs missed
- Clear specs + multi-model review → working software

---

## Part 4: Understanding Enough to Validate

You don't need to write code, but you need to recognize problems.

### The Top 5 Bug Categories (What to Watch For)

| Category | How to Spot It | What to Tell Claude |
|----------|----------------|---------------------|
| **Coordinate mismatch** | Positions are wrong, crops are off | "Are you mixing points and pixels? Document the coordinate system." |
| **UI doesn't update** | Changes don't appear | "Is @Observable detecting the mutation? Are you mutating nested properties?" |
| **Race condition** | Intermittent bugs, crashes | "Is this thread-safe? Should this be an actor?" |
| **Silent failure** | Features don't work, no error | "Are you swallowing errors with try? Add proper error handling." |
| **Persistence bug** | Data lost on restart | "Is the save actually happening? Add logging to verify." |

### Red Flags in Code Review

When Claude shows you code, watch for:

| Red Flag | Why It's Bad |
|----------|--------------|
| `try?` everywhere | Errors are silently ignored |
| `@unchecked Sendable` | Threading safety bypassed |
| `force unwrap (!)` | Will crash on nil |
| No error handling in async | Failures disappear |
| 500+ line files | Too complex, hard to maintain |
| Multiple TODO files | Confusion, no clear priority |

### Questions to Ask Claude

When reviewing implementation:

1. "What happens if this fails?" (error handling)
2. "Is this thread-safe?" (concurrency)
3. "Will this survive app restart?" (persistence)
4. "What happens with empty input?" (edge cases)
5. "Where is the state stored?" (architecture)

---

*This guide will evolve. When you learn something the hard way, add it.*
