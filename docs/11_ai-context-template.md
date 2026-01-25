<!--
TRIGGERS: AI-CONTEXT, context file, session context, project context template
PHASE: discovery
LOAD: sections
-->

# AI Context Template

*Template for AI-CONTEXT.md files that reduce re-explanation overhead by 80%+.*

---

## How to Use This Template

1. Copy the template below into your project as `AI-CONTEXT.md`
2. Fill in the sections relevant to your project
3. Reference it at the start of every AI session
4. Update it as your project evolves

---

## Template

```markdown
# [Project Name] - AI Context

> Last Updated: [YYYY-MM-DD]
> Current Phase: [Foundation / Core Features / Polish / Maintenance]

---

## Quick Facts

| Aspect | Value |
|--------|-------|
| **Type** | [macOS app / iOS app / CLI tool / Package] |
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Min Deployment** | macOS 14.0 / iOS 17.0 |
| **Architecture** | MVVM with Actors |
| **Persistence** | JSON files / UserDefaults |

---

## Project Purpose

[One paragraph describing what this app does and why it exists.]

---

## Files to Read First

**Priority 1 (Always read):**
1. `CLAUDE.md` — Project rules and patterns
2. `README.md` — What the project does

**Priority 2 (Read for context):**
3. `Sources/Models/` — Data structures
4. `Sources/ViewModels/` — State management

**Priority 3 (Reference as needed):**
5. `Sources/Services/` — Business logic
6. `Sources/Views/` — UI components

---

## Current Priorities

### NOW (This Session)
- [ ] [Specific task 1]
- [ ] [Specific task 2]

### NEXT (After NOW completes)
- [ ] [Future task 1]

### BLOCKED
- [None / Description of blocker]

---

## Directory Structure

```
ProjectName/
├── Sources/
│   ├── Models/          # Pure data structs (Codable)
│   ├── Services/        # Business logic (actors)
│   ├── ViewModels/      # UI state (@MainActor)
│   └── Views/           # SwiftUI components
├── Resources/           # Assets, configs
├── Tests/               # Unit tests
├── CLAUDE.md            # AI rules
└── AI-CONTEXT.md        # This file
```

---

## Critical Rules

### Threading
- ViewModels MUST be `@MainActor`
- Services MUST be `actor` (not class)
- Never use plain `Bool` or `Dictionary` for shared state
- Use `async/await`, not completion handlers

### State Management
- Use `@Observable` for view models
- Reassign parent property when mutating nested structs
- Use `@State` only for view-local state

### Persistence
- Save to JSON in `~/Library/Application Support/[AppName]/`
- Use `@AppStorage` only for simple preferences
- Don't use Core Data unless specifically required

### Error Handling
- Never use `try?` to swallow errors silently
- Log errors with context: `print("Operation failed: \(error), context: \(context)")`
- Show user-facing errors via alert or toast

---

## Known Issues / Gotchas

### [Issue Name]
**Symptom:** [What happens]
**Cause:** [Why it happens]
**Fix:** [How to handle it]

### Coordinate Systems
**Symptom:** Crops/positions off by 2x on Retina
**Cause:** Mixing NSImage.size (points) with CGImage dimensions (pixels)
**Fix:** Always use CGImage dimensions for pixel operations

---

## Reference Code

### Pattern: Actor-Based Service
```swift
actor DataService {
    private var cache: [String: Data] = [:]

    func getData(for key: String) async throws -> Data {
        if let cached = cache[key] {
            return cached
        }
        let data = try await fetchFromNetwork(key)
        cache[key] = data
        return data
    }
}
```

### Pattern: ViewModel
```swift
@MainActor
@Observable
final class ContentViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    private let service: DataService

    init(service: DataService) {
        self.service = service
    }

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await service.getItems()
        } catch {
            self.error = error
        }
    }
}
```

---

## Session Protocol

1. **Start:** Read this file and CLAUDE.md
2. **Before coding:** Confirm understanding of the task
3. **During:** Update this file if priorities change
4. **After changes:** Update SESSION-LOG.md
5. **Before finishing:** Commit if stable, note next steps

---

## Recent Sessions

### [YYYY-MM-DD] [Time] - [AI Model]
**Goal:** [What we tried to accomplish]
**Outcome:** [What actually happened]
**Commit:** [Git hash if applicable]
**Next:** [What's next]

---

## Questions for Human

- [Any unresolved questions or decisions needed]

---
```

---

## Specialized Templates

### For BLE/Protocol Reverse Engineering

Add this section:

```markdown
## Device Information

| Property | Value |
|----------|-------|
| **Device Name** | [Name] |
| **MAC Address** | XX:XX:XX:XX:XX:XX |
| **BLE Services** | [UUIDs] |
| **Characteristics** | [UUIDs with properties] |

## Protocol Structure

| Field | Bytes | Description |
|-------|-------|-------------|
| Header | 0-1 | Always 0xABCD |
| Length | 2 | Payload length |
| Command | 3 | Command type |
| Payload | 4-N | Variable |
| Checksum | N+1 | XOR of bytes |

## Phase-by-Phase Analysis

### Phase 1: Connection (0:00-0:05)
**Expected packets:**
- Device discovery broadcast
- Connection request
- Service discovery

**Key items to extract:**
- Service UUIDs
- Characteristic handles
```

### For Video/Media Processing

Add this section:

```markdown
## Media Specifications

| Property | Value |
|----------|-------|
| **Input Formats** | MOV, MP4, MXF |
| **Output Formats** | ProRes, H.264 |
| **Max Resolution** | 4K (3840x2160) |
| **Frame Rates** | 23.976, 24, 25, 29.97, 30, 60 |

## Coordinate System

- **Source:** CGImage (pixels, top-left origin)
- **Display:** SwiftUI (points, top-left origin)
- **Scale Factor:** 2.0 on Retina

## FFmpeg Integration

```bash
# Passthrough copy (no re-encode)
ffmpeg -i input.mov -c copy output.mov

# ProRes encoding
ffmpeg -i input.mov -c:v prores_ks -profile:v 3 output.mov
```
```

---

## Tips for Effective Context Files

1. **Keep it current** — Stale context is worse than no context
2. **Be specific** — "Fix the bug" vs "Fix the crash in VideoPlayer.swift:234 when seeking past end"
3. **Include code patterns** — Show don't tell
4. **Note what failed** — Prevent repeating mistakes
5. **Reference other docs** — Don't duplicate, link
6. **Update after every session** — 2 minutes saves 20 minutes next time

---

*This template reduced re-explanation overhead by 80%+ across 15 projects.*
