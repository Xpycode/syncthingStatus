<!--
TRIGGERS: architecture, tech stack, what technology, how to build, interview answers, technical decision
PHASE: discovery
LOAD: full
-->

# Architecture Decision Mapping

**Translating what you want into how to build it.**

*This guide maps your discovery interview answers to technical decisions.*

---

## How to Use This Document

After the discovery interview, use this guide to determine:
1. What technologies/patterns to use
2. What to tell Claude about the architecture
3. What to add to CLAUDE.md

---

## Platform Decisions

### "What platform?"

| You Said | Technical Choice | Tell Claude |
|----------|------------------|-------------|
| "Mac app" | macOS, SwiftUI | "SwiftUI macOS app, minimum macOS 14" |
| "iPhone app" | iOS, SwiftUI | "SwiftUI iOS app, minimum iOS 17" |
| "Both Mac and iPhone" | SwiftUI multiplatform | "SwiftUI multiplatform, shared code where possible" |
| "Menu bar app" | macOS, NSStatusItem | "Menu bar app using NSStatusItem, no dock icon" |
| "Menu bar AND window" | macOS, hybrid | "Menu bar app with optional main window" |
| "Website" | HTML/CSS/JS or framework | "Static site" or "React/Vue/etc." based on complexity |
| "Web app with backend" | Full stack | "Frontend + API + database - need to discuss stack" |

### "Just for me or for others?"

| You Said | Implications |
|----------|--------------|
| "Just me" | Skip notarization, simpler error handling, can use hardcoded paths |
| "Friends/family" | Need notarization for macOS, basic error messages, simple install |
| "Public release" | Full polish, App Store or notarized, help documentation, error handling |

---

## Persistence Decisions

### "Does it need to remember anything?"

| You Said | Technical Choice | When to Use |
|----------|------------------|-------------|
| "No, fresh every time" | No persistence | Tools that process and output |
| "Just settings/preferences" | UserDefaults | Toggle states, window position, theme |
| "User's data, simple" | JSON files | Lists, documents, user content |
| "User's data, complex/large" | SQLite or Core Data | Large datasets, complex queries |
| "Sync across devices" | CloudKit or custom sync | Multi-device apps |

### JSON vs. UserDefaults vs. Database

```
UserDefaults:
- Stores: Simple values (strings, numbers, bools, small arrays)
- Best for: App settings, preferences, UI state
- NOT for: User documents, large data, complex structures

JSON Files:
- Stores: Any Codable struct/class
- Best for: User data, documents, exportable content
- Location: Application Support folder
- NOT for: Huge datasets, complex queries

SQLite/Core Data:
- Stores: Relational data with queries
- Best for: Large datasets, search, complex relationships
- NOT for: Simple apps (overkill)
```

**Default recommendation: JSON files.** They're human-readable, easy to debug, and sufficient for most apps.

---

## File Handling Decisions

### "Does it work with files?"

| You Said | What's Needed |
|----------|---------------|
| "No files" | Nothing special |
| "App's own files only" | Application Support directory |
| "User chooses files" | NSOpenPanel + security-scoped bookmarks |
| "User's files, remember location" | Security-scoped bookmarks (persisted) |
| "Drag and drop files" | Drop delegate + security bookmarks |

### If Working with Images

| Task | What to Watch For |
|------|-------------------|
| Display images | Straightforward |
| Crop/resize | **Coordinate systems!** Points vs pixels, see `21_coordinate-systems.md` |
| Process with Core Graphics | CGImage uses pixels, NSImage uses points |
| Export images | Format, quality, metadata handling |

**CRITICAL:** Image processing is the #1 source of bugs. Always clarify coordinate systems.

### If Working with Video

| Task | Complexity |
|------|------------|
| Play video | AVPlayer - moderate |
| Trim/cut video | AVAssetExportSession - moderate |
| Process frames | AVAssetImageGenerator - complex, coordinate issues |
| Composite/overlay | AVMutableComposition - complex |

---

## Networking Decisions

### "Does it talk to the internet?"

| You Said | Technical Choice |
|----------|------------------|
| "No internet" | No networking code needed |
| "Fetch data from API" | URLSession with async/await |
| "Real-time updates" | WebSocket or Server-Sent Events |
| "Upload files" | URLSession multipart upload |
| "OAuth login" | ASWebAuthenticationSession |

### API Integration Pattern

```swift
// Tell Claude to use this pattern:
actor APIService {
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              200...299 ~= http.statusCode else {
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

---

## UI Architecture Decisions

### "What does the main screen look like?"

| You Described | Pattern to Use |
|---------------|----------------|
| "One main view" | Single view + ViewModel |
| "List of items → detail" | NavigationSplitView (macOS/iOS) |
| "Tabs at bottom/top" | TabView |
| "Sidebar with sections" | NavigationSplitView with sidebar |
| "Multiple panels side by side" | HSplitView (macOS) |
| "Settings/preferences" | Settings scene (macOS) or sheet |

### ViewModel Pattern (Always Use This)

```
Views/
├── ContentView.swift        # Main view, minimal logic
├── SettingsView.swift       # Settings UI
└── Components/              # Reusable UI pieces

ViewModels/
├── ContentViewModel.swift   # @MainActor, @Observable
└── SettingsViewModel.swift  # @MainActor, @Observable
```

**Rule:** Views only display. ViewModels contain state and logic.

---

## Concurrency Decisions

### "Does it do heavy processing?"

| Task Type | Pattern |
|-----------|---------|
| Quick operations | Direct call, no special handling |
| File I/O | async/await on background |
| Image processing | async/await, possibly with progress |
| Long-running tasks | Task with cancellation support |
| Multiple concurrent operations | TaskGroup |

### The Actor Rule

**If data is accessed from multiple places → use an actor**

```swift
// BAD: Class with shared state
class DataManager {
    var items: [Item] = []  // Race condition risk!
}

// GOOD: Actor protects state
actor DataManager {
    var items: [Item] = []  // Safe!
}
```

---

## Project Structure Template

Based on interview answers, here's your starting structure:

### Simple App (No Networking, Basic Persistence)

```
AppName/
├── AppNameApp.swift         # Entry point
├── Models/
│   └── Item.swift           # Data structures
├── ViewModels/
│   └── ContentViewModel.swift
├── Views/
│   └── ContentView.swift
└── Services/
    └── StorageService.swift # JSON persistence
```

### Medium App (Networking, Multiple Screens)

```
AppName/
├── AppNameApp.swift
├── Models/
│   ├── Item.swift
│   └── APIModels.swift
├── ViewModels/
│   ├── ContentViewModel.swift
│   └── DetailViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── DetailView.swift
│   └── Components/
├── Services/
│   ├── APIService.swift     # Actor
│   └── StorageService.swift # Actor
└── Utilities/
    └── Extensions.swift
```

### Complex App (Multiple Features, Background Processing)

```
AppName/
├── AppNameApp.swift
├── Models/
├── ViewModels/
├── Views/
├── Services/
├── Utilities/
├── Resources/
└── Features/
    ├── Import/
    ├── Export/
    └── Processing/
```

---

## CLAUDE.md Generation

After the interview, add to CLAUDE.md:

```markdown
# [Project Name]

## Quick Facts
- Platform: [macOS/iOS/Web]
- Minimum OS: [version]
- Distribution: [personal/App Store/direct]

## Tech Stack
- UI: SwiftUI
- Persistence: [UserDefaults/JSON/SQLite]
- Networking: [None/URLSession/specific API]
- Concurrency: Swift actors + async/await

## Architecture
- Models/: Data structures (Codable)
- ViewModels/: UI state (@MainActor, @Observable)
- Views/: SwiftUI components
- Services/: Business logic (actors)

## Rules
- ViewModels are @MainActor
- Services are actors (thread-safe)
- Persist to [location] using [format]
- [Any project-specific rules from interview]

## Known Constraints
- [File access needs bookmarks]
- [Image processing uses CGImage coordinates]
- [etc.]
```

---

## Decision Checklist

After the interview, you should know:

- [ ] Platform and minimum OS version
- [ ] Who will use it (affects polish level)
- [ ] Persistence approach (none/UserDefaults/JSON/database)
- [ ] File handling needs (none/read-only/read-write/drag-drop)
- [ ] Networking needs (none/API/real-time)
- [ ] UI structure (single view/navigation/tabs/split)
- [ ] Heavy processing needs (affects concurrency approach)
- [ ] Distribution method (personal/notarized/App Store)

---

## Common Combinations

### "Personal Utility Tool"
- Platform: macOS
- Distribution: Just me
- Persistence: JSON for data, UserDefaults for preferences
- Architecture: Simple, single ViewModel
- Skip: Notarization, extensive error handling

### "Productivity App for Others"
- Platform: macOS or iOS
- Distribution: Notarized or App Store
- Persistence: JSON with proper error handling
- Architecture: Full ViewModel pattern, actors for services
- Include: Good error messages, help documentation

### "Image/Video Processing Tool"
- Platform: macOS
- Persistence: Processed files to user-chosen location
- **Critical:** Load `21_coordinate-systems.md` - coordinate bugs guaranteed otherwise
- Architecture: Actor for processing, progress reporting
- Include: Security-scoped bookmarks for file access

### "API-Connected App"
- Networking: URLSession with async/await
- Architecture: APIService actor, proper error handling
- Include: Offline handling, loading states, retry logic

---

*Map the interview to architecture. Then build phase by phase.*
