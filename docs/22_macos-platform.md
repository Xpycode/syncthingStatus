<!--
TRIGGERS: macOS, sandbox, entitlements, bookmark, Keychain, notarization, menu bar app, accessibility
PHASE: implementation
LOAD: sections
-->

# macOS Platform Specifics

*Platform-specific patterns, gotchas, and requirements for macOS development.*

---

## Security-Scoped Bookmarks

### When You Need Them

- Accessing files outside your sandbox
- Persisting access to user-selected files across app launches
- Any file access that should survive app restart

### Implementation Pattern

```swift
// SAVING a bookmark (after user selects file)
func saveBookmark(for url: URL) throws {
    let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(bookmarkData, forKey: "savedBookmark_\(url.lastPathComponent)")
}

// RESTORING a bookmark (on app launch)
func restoreBookmark(key: String) -> URL? {
    guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
        return nil
    }

    var isStale = false
    do {
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            // Re-save the bookmark
            try saveBookmark(for: url)
        }

        return url
    } catch {
        print("Failed to restore bookmark: \(error)")
        return nil
    }
}

// USING a security-scoped resource
func useSecurityScopedResource(at url: URL, operation: (URL) throws -> Void) throws {
    guard url.startAccessingSecurityScopedResource() else {
        throw SecurityError.accessDenied
    }
    defer {
        url.stopAccessingSecurityScopedResource()
    }
    try operation(url)
}
```

### Critical Rules

1. **Always balance start/stop** — Use `defer` to ensure `stopAccessingSecurityScopedResource()` is called
2. **Check return value** — `startAccessingSecurityScopedResource()` can return `false`
3. **Handle stale bookmarks** — Re-create them when `isStale` is true
4. **Store bookmark data, not URLs** — URLs don't persist permissions

---

## Keychain Operations

### Performance Warning

```swift
// WARNING: Keychain can be SLOW (50-200ms)
// Don't call on main thread during UI operations

// WRONG: Blocking main thread
func viewDidLoad() {
    let apiKey = Keychain.get("apiKey")  // Could block 200ms!
}

// RIGHT: Load async, cache result
@MainActor
class APIManager {
    private var cachedKey: String?

    func getAPIKey() async -> String? {
        if let cached = cachedKey {
            return cached
        }

        return await Task.detached {
            let key = Keychain.get("apiKey")
            await MainActor.run {
                self.cachedKey = key
            }
            return key
        }.value
    }
}
```

### Keychain Wrapper Pattern

```swift
enum Keychain {
    static func set(_ value: String, for key: String) -> Bool {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)  // Remove existing
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
```

---

## URLSession Default Timeout

### The Problem

```swift
// DEFAULT: 60 second timeout
// This is often too long for user-facing operations
let task = URLSession.shared.dataTask(with: url)
```

### The Fix

```swift
// Custom configuration with appropriate timeout
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 10  // 10 seconds
config.timeoutIntervalForResource = 30  // 30 seconds total

let session = URLSession(configuration: config)
```

---

## File Not in project.pbxproj (AI-Generated Files)

### The Problem

Claude/AI generates a file, but Xcode doesn't see it. Build fails with "file not found."

### Why It Happens

AI tools create files on disk but don't update Xcode's project file (`.pbxproj`).

### The Fix

**Option 1: Manual Add**
1. In Xcode, right-click the folder
2. "Add Files to [Project]..."
3. Select the new file(s)

**Option 2: Check After AI Generates Files**
```
After generating files, always tell Claude:
"Verify the new files are in the Xcode project.
Run: grep 'NewFileName' *.xcodeproj/project.pbxproj"
```

**Option 3: Use Swift Package Manager**
Files in SPM packages are auto-discovered (no pbxproj needed).

---

## Sandbox Considerations

### What Sandbox Restricts

| Operation | Sandboxed | Non-Sandboxed |
|-----------|-----------|---------------|
| Access ~/Documents | Via bookmark | Direct |
| Access /Applications | No | Yes |
| Network access | With entitlement | Yes |
| Keychain (full) | Limited | Full |
| System preferences | No | Yes |
| Apple Events | With entitlement | Yes |

### Entitlements File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### When to Go Non-Sandboxed

- System-level audio routing (HAL drivers)
- Window management across apps (Accessibility API)
- Full filesystem access requirements
- Distributing outside Mac App Store anyway

**Trade-off:** Non-sandboxed apps cannot be distributed via Mac App Store.

---

## Menu Bar Apps

### Basic Structure

```swift
@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("My App", systemImage: "star") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)  // or .menu for simple menu

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu-bar-only apps
        NSApp.setActivationPolicy(.accessory)
    }
}
```

### Dual Interface Pattern

```swift
// Menu bar + main window
@main
struct DualInterfaceApp: App {
    @State private var showMainWindow = false

    var body: some Scene {
        MenuBarExtra("App", systemImage: "star") {
            Button("Show Main Window") {
                showMainWindow = true
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }

        Window("Main", id: "main") {
            MainView()
        }
        .defaultVisibility(showMainWindow ? .visible : .hidden)
    }
}
```

---

## Accessibility API (Window Management)

### Permissions

```swift
// Check accessibility permissions
func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}
```

### Getting Window Information

```swift
func getWindowsForApp(pid: pid_t) -> [[String: Any]]? {
    let app = AXUIElementCreateApplication(pid)

    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)

    guard result == .success, let windows = windowsRef as? [AXUIElement] else {
        return nil
    }

    return windows.map { window in
        var title: CFTypeRef?
        var position: CFTypeRef?
        var size: CFTypeRef?

        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size)

        return [
            "title": (title as? String) ?? "",
            "position": position,
            "size": size
        ]
    }
}
```

---

## Quarantine and Gatekeeper

### Checking Quarantine Status

```bash
# Check if file is quarantined
xattr -l /path/to/app.app

# Remove quarantine (for development)
xattr -dr com.apple.quarantine /path/to/app.app
```

### Common Issues

**Problem:** App won't launch, says "damaged"
**Cause:** Quarantine flag + missing signature
**Fix:** `xattr -cr /path/to/app.app` (clears all extended attributes)

---

## Notarization for Distribution

### Process

1. **Archive:** Xcode → Product → Archive
2. **Export:** Distribute App → Developer ID
3. **Notarize:** Automatically submitted to Apple
4. **Staple:** `xcrun stapler staple MyApp.app`

### DMG Distribution

```bash
# Create DMG
hdiutil create -volname "MyApp" -srcfolder ./MyApp.app -ov -format UDZO MyApp.dmg

# Notarize DMG
xcrun notarytool submit MyApp.dmg --apple-id "email" --team-id "TEAM" --password "app-specific-password" --wait

# Staple
xcrun stapler staple MyApp.dmg
```

---

## Debugging Tools

| Tool | Purpose | Command |
|------|---------|---------|
| Console.app | System logs | GUI app |
| `log stream` | Live logs | `log stream --predicate 'processImagePath contains "MyApp"'` |
| `otool -L` | Check linked libraries | `otool -L MyApp.app/Contents/MacOS/MyApp` |
| `codesign -dv` | Verify signature | `codesign -dv --verbose=4 MyApp.app` |
| `xattr` | Extended attributes | `xattr -l file` |
| `mdls` | Spotlight metadata | `mdls file` |
| `qlmanage` | Quick Look preview | `qlmanage -p file` |

---

## Quick Reference

| Task | Pattern |
|------|---------|
| Persist file access | Security-scoped bookmarks |
| Store secrets | Keychain (async, cached) |
| Menu bar app | MenuBarExtra + .accessory policy |
| Window management | Accessibility API + permissions |
| Distribution | Notarized DMG |
| Debug crashes | Console.app + log stream |

---

*Keep this reference updated as you encounter platform-specific issues.*
