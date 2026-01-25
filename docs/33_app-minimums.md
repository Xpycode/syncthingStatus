<!--
TRIGGERS: minimums, baseline features, must have, essential features, app features, ship requirements
PHASE: building, shipping
LOAD: full
-->

# App Minimums Reference

*Baseline features every app should have. Compiled from patterns across 15+ shipped macOS/iOS apps.*

> **Two-part release flow:**
> 1. First run `/minimums` → Feature baselines (this file)
> 2. Then run `/review` → Code quality ([30_production-checklist.md](30_production-checklist.md))

---

## Quick Reference

Before shipping, check that your app has these baseline features:

```
DEPLOYMENT
├── [ ] Auto-update mechanism (Sparkle/App Store)
├── [ ] Version visible in UI (About window or Settings)
├── [ ] Notarized and code-signed (macOS)
└── [ ] App icon at all required sizes

INFRASTRUCTURE
├── [ ] Diagnostic logging (to ~/Library/Application Support/)
├── [ ] Preferences system (@AppStorage)
├── [ ] Error handling with user feedback
└── [ ] Progress feedback for async operations

UI POLISH
├── [ ] Empty states with clear CTAs
├── [ ] Loading states (not blank screens)
├── [ ] Error states with retry option
├── [ ] Keyboard shortcuts (and document them)
└── [ ] About window

PLATFORM-SPECIFIC
├── macOS: Menu bar (About, Preferences, Quit)
├── macOS: Window state restoration
├── iOS: Review prompt (at the right moment)
├── iOS: What's New on update
└── Web: Favicon, meta tags, 404 page
```

---

## Deployment & Distribution

### Auto-Update Mechanism

**Why:** Users won't manually check for updates. You'll ship bugs. You need a way to push fixes.

**macOS (Non-App Store):**
- Use Sparkle framework with EdDSA signing
- Host appcast.xml with update info
- Check on launch + periodically

**macOS (App Store):**
- System handles updates, but show "What's New" on first launch after update

**iOS:**
- System handles updates via App Store
- Show "What's New" screen on first launch after update
- Consider in-app prompt for critical updates

### Version Visibility

**Why:** Users need to tell you what version they're running when reporting bugs.

- Show in About window: `v1.2.3 (build 45)`
- Consider: Settings footer, menu bar tooltip
- Format: Marketing version + build number

### Code Signing & Notarization (macOS)

**Why:** Gatekeeper blocks unsigned apps. Users get scary warnings.

```bash
# Sign
codesign --force --sign "Developer ID Application: ..." --options runtime MyApp.app

# Notarize
xcrun notarytool submit MyApp.zip --apple-id ... --wait

# Staple
xcrun stapler staple MyApp.app
```

---

## Infrastructure

### Diagnostic Logging

**Why:** When users report issues, you need to see what happened. Crash logs aren't enough.

**Pattern:**
```swift
final class DiagnosticLogger {
    static let shared = DiagnosticLogger()
    private let logURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("YourApp")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        logURL = appFolder.appendingPathComponent("diagnostic.log")
    }

    func log(_ message: String, state: [String: Any] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let stateStr = state.isEmpty ? "" : " | \(state)"
        let entry = "[\(timestamp)] \(message)\(stateStr)\n"
        // Append to file...
    }
}
```

**Key principle:** Log **state**, not just flow. Include `hasSelection: true, isEnabled: false` — not just "button tapped."

**Location:** `~/Library/Application Support/YourApp/diagnostic.log`

### Preferences System

**Why:** Users expect their settings to persist. Use @AppStorage backed by UserDefaults.

**Pattern:**
```swift
// Simple preferences
@AppStorage("showInDock") var showInDock = true
@AppStorage("checkUpdatesAutomatically") var checkUpdates = true

// Feature flags for migrations
@AppStorage("useNewWorkspace") var useNewWorkspace = false
```

**Advanced:** For per-entity settings (e.g., per-monitor, per-project), use JSON in App Support.

### Error Handling with User Feedback

**Why:** Silent failures frustrate users. They don't know if it worked or not.

**Pattern:**
```swift
do {
    try await performOperation()
    // Show success feedback
} catch is CancellationError {
    // Don't show anything — user cancelled
} catch {
    // Generic message for security
    showError("Operation failed. Please try again.")
    // Log full error for debugging
    DiagnosticLogger.shared.log("Operation failed", state: ["error": error.localizedDescription])
}
```

**Never expose:** File paths, internal state, stack traces to users.

### Progress Feedback

**Why:** Long operations need visual feedback or users think the app is frozen.

**Pattern:**
```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""

    func processFiles(_ files: [URL]) async {
        isProcessing = true
        defer { isProcessing = false }

        for (index, file) in files.enumerated() {
            progress = Double(index) / Double(files.count)
            statusMessage = "Processing \(file.lastPathComponent)..."
            await processFile(file)
        }
    }
}
```

---

## UI Polish

### Empty States

**Why:** Blank screens confuse users. Tell them what to do.

**Pattern:**
```
┌─────────────────────────────────────┐
│                                     │
│         📁 No files yet             │
│                                     │
│    Drag files here or click         │
│    [Import] to get started          │
│                                     │
└─────────────────────────────────────┘
```

**Include:** Icon/illustration, explanation, clear action button.

### Loading States

**Why:** Users need to know something is happening.

**Options:**
- Progress bar (determinate) — for known duration
- Spinner (indeterminate) — for unknown duration
- Skeleton UI — for content that will load
- Status text — "Loading 3 of 10..."

### Error States

**Why:** Users need to know what went wrong and what to do about it.

**Pattern:**
```
┌─────────────────────────────────────┐
│                                     │
│         ⚠️ Connection failed        │
│                                     │
│    Couldn't reach the server.       │
│    Check your internet and          │
│    [Try Again]                      │
│                                     │
└─────────────────────────────────────┘
```

**Include:** What happened, why (if known), action to resolve.

### Keyboard Shortcuts

**Why:** Power users expect them. macOS apps especially.

**Must-have for macOS:**
- ⌘Q — Quit
- ⌘, — Preferences
- ⌘W — Close window
- ⌘N — New (if applicable)
- ⌘O — Open (if applicable)
- ⌘S — Save (if applicable)

**Document them:**
- In Help menu → Keyboard Shortcuts
- In onboarding or tips
- In README

### About Window

**Why:** Standard expectation. Shows version, links to support.

**Include:**
- App icon
- App name
- Version (marketing + build)
- Copyright
- Links: Website, Support, Privacy Policy
- Acknowledgments/Credits (if applicable)

---

## Platform-Specific

### macOS Menu Bar

**Required menus:**
- **App menu:** About, Preferences (⌘,), Quit (⌘Q)
- **File menu:** (if file-based) New, Open, Save, Close
- **Edit menu:** Undo, Redo, Cut, Copy, Paste, Select All
- **Window menu:** Minimize, Zoom, standard window commands
- **Help menu:** Search, link to documentation

### macOS Window State Restoration

**Why:** Users expect windows to reopen where they left them.

```swift
// In your WindowGroup or NSWindow setup
.handlesExternalEvents(matching: Set(arrayLiteral: "*"))
// Or implement NSWindowRestoration
```

### macOS Dock Icon Behavior

**For menu bar apps:** Option to show/hide dock icon.

```swift
// Hide dock icon
NSApp.setActivationPolicy(.accessory)

// Show dock icon
NSApp.setActivationPolicy(.regular)
```

### iOS App Store Review Prompt

**Why:** Reviews help discovery. But timing matters — don't annoy users.

**When to prompt:**
- After a positive action (completed task, saved file)
- After N successful uses (not on first launch)
- Not during onboarding
- Not after an error

```swift
import StoreKit

// After positive moment
if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    SKStoreReviewController.requestReview(in: scene)
}
```

### iOS What's New Screen

**Why:** Users don't read App Store changelogs. Show them in-app.

**Pattern:**
- Check stored version vs current version on launch
- If different, show What's New sheet
- Store new version after dismissal

### Website Essentials

- **Favicon:** favicon.ico + apple-touch-icon
- **Meta tags:** title, description, og:image
- **404 page:** Helpful, branded, links to home
- **Mobile responsive:** Test on actual phones
- **SSL/HTTPS:** Always

---

## Architecture Patterns (Your Defaults)

Based on your codebase patterns:

| Layer | Your Default | Why |
|-------|--------------|-----|
| **UI** | SwiftUI + occasional AppKit | AppKit for Canvas, NSWorkspace |
| **Concurrency** | async/await + actors | Not raw GCD |
| **State** | @Published + ObservableObject | @EnvironmentObject for sharing |
| **Persistence** | JSON + UserDefaults | No Core Data |
| **ViewModels** | @MainActor | Thread safety by design |
| **Services** | Actors | Thread safety by design |
| **Distribution** | Notarized DMG | Non-App Store for entitlements |
| **Updates** | Sparkle | EdDSA signed |

---

## Pre-Ship Minimums Checklist

Run through this before every release:

### Deployment
- [ ] Auto-update works (test the flow)
- [ ] Version shows correctly in About
- [ ] App is signed and notarized
- [ ] DMG/installer works on clean system

### Infrastructure
- [ ] Diagnostic log writes to correct location
- [ ] Preferences save and restore correctly
- [ ] Errors show user-friendly messages
- [ ] Progress shows for long operations

### UI Polish
- [ ] Empty states have clear CTAs
- [ ] Loading states show (not blank)
- [ ] Error states have retry option
- [ ] Keyboard shortcuts work
- [ ] About window has current version

### Platform
- [ ] macOS: Menu bar items work
- [ ] macOS: Window state restores
- [ ] iOS: Review prompt triggers appropriately
- [ ] iOS: What's New shows after update
- [ ] Web: Favicon, meta, 404 all present

---

## Common Oversights

Things you've forgotten before:

| Oversight | Consequence | Prevention |
|-----------|-------------|------------|
| No update mechanism | Users stuck on buggy versions | Sparkle from day 1 |
| No version in UI | Can't debug user reports | About window required |
| No diagnostic logging | Blind when users report issues | Add logger early |
| Silent errors | Users confused, retry blindly | Always show feedback |
| No empty states | Users think app is broken | Design from empty first |
| Hardcoded debug URLs | Ships with wrong endpoints | Use build config |
| Missing keyboard shortcuts | Power users frustrated | Standard shortcuts + docs |

---

*Add items here as you discover new minimums. This list grows with experience.*
