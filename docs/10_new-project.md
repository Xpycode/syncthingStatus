<!--
TRIGGERS: new project, starting project, project setup, init, create project
PHASE: discovery
LOAD: full
-->

# New Project Checklist

*Everything you need to set up a new Swift/SwiftUI project for AI-assisted development.*

---

## Phase 1: Project Creation

### Xcode Setup

- [ ] Create new Xcode project (App or Package)
- [ ] Set minimum deployment target (macOS 14.0 / iOS 17.0)
- [ ] Set Swift version (5.9+)
- [ ] Configure bundle identifier
- [ ] Set up code signing (Development / Distribution)

### Directory Structure

```
ProjectName/
├── Sources/
│   ├── Models/          # Pure data structs (Codable, Sendable)
│   ├── Services/        # Business logic (actors)
│   ├── ViewModels/      # UI state (@MainActor, @Observable)
│   └── Views/           # SwiftUI components
├── Resources/           # Assets, configs
├── Tests/               # Unit tests
├── CLAUDE.md            # AI rules (required)
├── AI-CONTEXT.md        # Session context (optional)
├── README.md            # Project overview
└── .gitignore           # Git ignore patterns
```

- [ ] Create Sources folder structure
- [ ] Create Resources folder
- [ ] Create Tests folder
- [ ] Initialize git repository (`git init`)
- [ ] Create `.gitignore` (Xcode template)

---

## Phase 2: AI Context Files

### CLAUDE.md (Required)

Create `CLAUDE.md` in project root with:

- [ ] Project name and purpose
- [ ] Build commands
- [ ] Tech stack (Swift version, UI framework, min deployment)
- [ ] Project structure overview
- [ ] Threading rules (ViewModels = @MainActor, Services = actor)
- [ ] Error handling rules (no `try?` swallowing)
- [ ] State management rules (@Observable patterns)
- [ ] Known issues / gotchas section

```markdown
# [Project Name]

## Quick Start
xcodebuild -scheme ProjectName -configuration Debug build

## Tech Stack
- Swift 5.9 / SwiftUI
- Minimum: macOS 14.0
- Architecture: MVVM with Actors
- Persistence: JSON files

## Rules
### Threading
- ViewModels: Always `@MainActor`
- Services: Always `actor`

### Error Handling
- Never use `try?` to swallow errors
- Log errors with context

## Critical Rules (Learned Hard Way)
- [Add as discovered]
```

### AI-CONTEXT.md (Recommended)

- [ ] Quick facts table (type, language, frameworks)
- [ ] Project purpose (one paragraph)
- [ ] Files to read first (priority order)
- [ ] Current priorities (NOW/NEXT/BLOCKED)
- [ ] Reference code patterns
- [ ] Session protocol

---

## Phase 3: Documentation Files

### README.md

- [ ] Project name and one-line description
- [ ] Badges (platform, Swift version, license)
- [ ] Why this tool exists (problem it solves)
- [ ] Features list
- [ ] Screenshots placeholder
- [ ] Quick start / installation
- [ ] Requirements
- [ ] Usage instructions
- [ ] Architecture overview
- [ ] Troubleshooting section
- [ ] License

### CHANGELOG.md

- [ ] Create with Keep a Changelog format
- [ ] Add `## [Unreleased]` section
- [ ] Plan for Added/Changed/Fixed/Removed sections

### Optional Documentation

- [ ] SECURITY.md (if public repo)
- [ ] PRIVACY.md (if user-facing app)
- [ ] THREAT_MODEL.md (if handling sensitive data)
- [ ] SESSION-LOG.md (for tracking AI sessions)

---

## Phase 4: Code Architecture

### Threading Setup

- [ ] ViewModels marked `@MainActor @Observable`
- [ ] Services declared as `actor`
- [ ] No shared mutable state in classes
- [ ] Use `async/await`, not completion handlers

```swift
// ViewModel Pattern
@MainActor
@Observable
final class ContentViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    private let service: DataService

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

// Service Pattern
actor DataService {
    private var cache: [String: Data] = [:]

    func getData(for key: String) async throws -> Data {
        if let cached = cache[key] { return cached }
        let data = try await fetchFromNetwork(key)
        cache[key] = data
        return data
    }
}
```

### State Management

- [ ] Use `@Observable` for view models
- [ ] Use `@State` only for view-local state
- [ ] Document nested mutation workarounds
- [ ] Use `@AppStorage` only for simple preferences

### Error Handling

- [ ] Create app-specific error types
- [ ] Plan for user-facing error display
- [ ] Set up logging with context
- [ ] No `try?` swallowing errors

### Persistence

- [ ] Choose storage method (JSON files / UserDefaults / Core Data)
- [ ] Create data directory: `~/Library/Application Support/[AppName]/`
- [ ] Plan for data migration
- [ ] Use Keychain for secrets (not UserDefaults)

---

## Phase 5: macOS-Specific Setup

### Entitlements

- [ ] Create entitlements file if needed
- [ ] Add required capabilities:
  - [ ] `com.apple.security.app-sandbox` (if sandboxed)
  - [ ] `com.apple.security.files.user-selected.read-write` (file access)
  - [ ] `com.apple.security.network.client` (network access)

### Security-Scoped Bookmarks

If persisting file access:
- [ ] Implement bookmark save function
- [ ] Implement bookmark restore function
- [ ] Use `startAccessingSecurityScopedResource()` with `defer` cleanup
- [ ] Handle stale bookmarks

### App Type Setup

**Standard App:**
- [ ] Configure main window scene

**Menu Bar App:**
- [ ] Use `MenuBarExtra` in App struct
- [ ] Set `.accessory` activation policy
- [ ] Add quit command

**Document-Based App:**
- [ ] Set up document types in Info.plist
- [ ] Implement document model

---

## Phase 6: Build Configuration

### Schemes

- [ ] Debug scheme configured
- [ ] Release scheme configured
- [ ] Test scheme configured (if separate)

### Build Settings

- [ ] Optimizations enabled for Release
- [ ] Debug code uses `#if DEBUG`
- [ ] No hardcoded development URLs/keys
- [ ] Warning settings appropriate

### Info.plist

- [ ] Bundle display name
- [ ] Bundle identifier
- [ ] Version and build numbers
- [ ] Minimum deployment target
- [ ] Required device capabilities (if iOS)
- [ ] Privacy usage descriptions (if needed)

---

## Phase 7: Development Workflow

### Git Setup

- [ ] Initialize repository
- [ ] Create `.gitignore`
- [ ] Make initial commit
- [ ] Set up remote (GitHub/GitLab)
- [ ] Create develop branch (if using git-flow)

### Claude Code Integration

- [ ] Test `claude` command in project directory
- [ ] Verify CLAUDE.md is being read
- [ ] Set up any custom slash commands (`.claude/commands/`)
- [ ] Configure permissions if needed (`.claude/settings.json`)

### Workflow Process

1. **Spec:** Interview about requirements
2. **Plan:** Break into <30 min phases
3. **Implement:** One phase at a time
4. **Review:** Adversarial review (2-3 passes)
5. **Verify:** Test actual user flow
6. **Commit:** Clear message

---

## Phase 8: Quality Checklist

### Code Quality

- [ ] No `try?` swallowing errors silently
- [ ] No `@unchecked Sendable` without justification
- [ ] No force unwraps (`!`) without nil guards
- [ ] Files under 500 lines
- [ ] `defer` used for cleanup

### Thread Safety

- [ ] Services are actors (not classes with locks)
- [ ] ViewModels are `@MainActor`
- [ ] No plain Bool/Dictionary across threads
- [ ] `@Published` updates on main thread

### Security

- [ ] Input validated
- [ ] Secrets in Keychain
- [ ] Path traversal prevented
- [ ] Sensitive data not logged
- [ ] Security-scoped resources balanced

---

## Phase 9: App Minimums Check

Before shipping, verify baseline features are in place. See **33_app-minimums.md** for the full checklist.

### Quick Check
- [ ] Auto-update mechanism (Sparkle / App Store)
- [ ] Version visible in UI (About window)
- [ ] Diagnostic logging set up
- [ ] Preferences system (@AppStorage)
- [ ] Empty states designed
- [ ] Loading/error states implemented
- [ ] Keyboard shortcuts documented

---

## Phase 10: Pre-Release Prep

### Distribution Setup

- [ ] Developer ID certificate (macOS)
- [ ] Provisioning profile (iOS)
- [ ] App Store Connect setup (if applicable)

### Notarization (macOS)

- [ ] Code signing configured
- [ ] Notarization credentials set up
- [ ] Stapler workflow tested

### Release Checklist

- [ ] Version number updated
- [ ] CHANGELOG updated
- [ ] README current
- [ ] Build succeeds (Release configuration)
- [ ] No warnings
- [ ] Tested on clean install
- [ ] Code signed and notarized

---

## Quick Reference Tables

### Essential Files

| File | Purpose | Required |
|------|---------|----------|
| `CLAUDE.md` | AI rules and patterns | Yes |
| `README.md` | Project documentation | Yes |
| `.gitignore` | Git ignore patterns | Yes |
| `AI-CONTEXT.md` | Session context | Recommended |
| `CHANGELOG.md` | Version history | Recommended |

### Architecture Patterns

| Component | Pattern |
|-----------|---------|
| ViewModels | `@MainActor @Observable` class |
| Services | `actor` |
| Models | `struct` (Codable, Sendable) |
| Views | SwiftUI structs |
| Data storage | JSON files in App Support |
| Secrets | Keychain |

### Red Flags to Avoid

| Pattern | Problem | Fix |
|---------|---------|-----|
| `try?` | Errors ignored | Use `do/catch` |
| `!` force unwrap | Crash on nil | Use `guard let` |
| `@unchecked Sendable` | Thread unsafety | Use proper actors |
| 500+ line file | Unmaintainable | Split into modules |
| Class with shared state | Race conditions | Convert to actor |

---

## First Day Workflow

1. **Create project** with this checklist open
2. **Set up CLAUDE.md** first (AI needs context)
3. **Create directory structure**
4. **Make initial commit** ("Initial project structure")
5. **Start spec interview** for first feature
6. **Plan in phases** (<30 min each)
7. **Implement, review, verify, commit**

---

*Use this checklist for every new project. Update it as you discover new patterns.*
