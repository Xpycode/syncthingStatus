# Code Review Findings - syncthingStatus macOS App

**Review Date:** November 12, 2025
**Reviewer:** Claude Code (AI Assistant)
**Codebase Version:** commit 50c5500 on branch `Critical-Fixes`

---

## Executive Summary

A comprehensive code review identified **32 issues** across security, architecture, performance, and code quality categories. The application is well-structured and functional, but requires attention to several critical issues around resource management, concurrency, and architecture.

### Issue Breakdown
- **Critical Issues:** 3 (Fix Immediately)
- **High Priority:** 8 (Fix Soon)
- **Medium Priority:** 13 (Address During Refactoring)
- **Low Priority:** 8 (Nice to Have)

### Overall Code Quality: **B** (Good, but needs attention to critical issues)

---

## 🔴 Critical Issues (Fix Immediately)

### 1. Security-Scoped Resource Leak
**File:** `Client.swift:239-244`
**Severity:** CRITICAL
**Category:** Security, Resource Management

**Problem:**
The config.xml file access uses security-scoped resources but may not properly release them if errors occur.

```swift
let hasAccess = url.startAccessingSecurityScopedResource()
defer {
    if hasAccess {
        url.stopAccessingSecurityScopedResource()
    }
}
// Multiple early returns and potential exceptions follow
```

**Why it's an issue:**
- If exceptions are thrown, defer may not execute properly
- Could accumulate unreleased security-scoped resources
- May cause permission issues over time
- System limits on security-scoped resource handles

**Recommended Fix:**
```swift
let hasAccess = url.startAccessingSecurityScopedResource()
guard hasAccess else {
    return .failure(.configAccessDenied)
}
defer {
    url.stopAccessingSecurityScopedResource()
}
do {
    let data = try Data(contentsOf: url)
    // ... rest of parsing
} catch {
    return .failure(.configReadFailed(message: error.localizedDescription))
}
```

---

### 2. Race Condition in Debug Mode State Management
**File:** `Client.swift:1068-1229`
**Severity:** CRITICAL
**Category:** Concurrency, Data Integrity

**Problem:**
Multiple @Published properties are updated without synchronization, creating race conditions when toggling debug mode.

**Code Flow:**
```swift
func enableDebugMode(deviceCount: Int, folderCount: Int) {
    if !debugMode {
        realDevices = devices  // Line 1077 - save current data
        realFolders = folders
        // ...
    }
    debugMode = true  // Line 1083 - flag set
    // ... generate dummy data
    devices = dummyDevices  // Line 1205 - replace data
}
```

**Why it's an issue:**
- Between lines 1077 and 1205, if `refresh()` runs on another thread:
  - It could overwrite `realDevices` with debug data before dummy data is assigned
  - The check at line 452 (`!debugMode`) may pass before debugMode is set to true
- Multiple threads accessing @Published properties simultaneously
- No atomicity guarantee for state transitions

**Recommended Fix:**
```swift
func enableDebugMode(deviceCount: Int, folderCount: Int) {
    let shouldSaveReal = !debugMode

    // 1. Generate dummy data FIRST (off main state)
    let (dummyDevices, dummyFolders, dummyConnections, dummyStatuses) =
        generateDummyData(deviceCount: deviceCount, folderCount: folderCount)

    // 2. Then update state atomically
    if shouldSaveReal {
        realDevices = devices
        realFolders = folders
        realConnections = connections
        realFolderStatuses = folderStatuses
    }

    // 3. Update ALL state together
    debugMode = true
    debugDeviceCount = deviceCount
    debugFolderCount = folderCount
    devices = dummyDevices
    folders = dummyFolders
    connections = dummyConnections
    folderStatuses = dummyStatuses
}

// Extract data generation to pure function
private func generateDummyData(deviceCount: Int, folderCount: Int)
    -> (devices: [SyncthingDevice], folders: [SyncthingFolder],
        connections: [String: SyncthingConnection],
        statuses: [String: SyncthingFolderStatus]) {
    // ... current generation logic
    return (dummyDevices, dummyFolders, dummyConnections, dummyFolderStatuses)
}
```

---

### 3. Potential Retain Cycle in Combine Publishers
**File:** `Client.swift:182-209`
**Severity:** CRITICAL
**Category:** Memory Management

**Problem:**
While using `[weak self]` in Combine sink closures, the Task capturing could still create retain cycles.

```swift
settings.$useAutomaticDiscovery
    .combineLatest(settings.$baseURLString, settings.$manualAPIKey)
    .sink { [weak self] useAuto, _, _ in
        guard let self else { return }
        // ...
        Task { await self.refresh() }  // ⚠️ Strong capture after weak check
    }
    .store(in: &cancellables)
```

**Why it's an issue:**
- The Task captures `self` strongly even though the sink uses `weak self`
- If the Task is long-running and the object is deallocated mid-execution, memory is retained
- Multiple settings changes create multiple concurrent Tasks, all holding strong references
- No mechanism to cancel tasks when object is deallocated

**Recommended Fix:**
```swift
settings.$useAutomaticDiscovery
    .combineLatest(settings.$baseURLString, settings.$manualAPIKey)
    .sink { [weak self] useAuto, _, _ in
        guard let self else { return }
        // ...
        Task { [weak self] in  // ✅ Weak capture in Task
            await self?.refresh()
        }
    }
    .store(in: &cancellables)
```

**Additional Improvement - Add Task Storage:**
```swift
private var refreshTask: Task<Void, Never>?

func refresh() async {
    // Cancel previous refresh if still running
    refreshTask?.cancel()

    refreshTask = Task {
        guard !isRefreshing else { return }
        // ... existing refresh logic
    }
}

deinit {
    refreshTask?.cancel()
}
```

---

## 🟠 High Priority Issues (Fix Soon)

### 4. Missing Task Cancellation for Async Operations
**File:** `Client.swift` (multiple locations)
**Severity:** HIGH
**Category:** Resource Management, Performance

**Problem:**
No Task storage or cancellation mechanism when object is deinitialized or when rapid refreshes happen.

**Current Code:**
```swift
func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    // ... long running operations
}
```

**Why it's an issue:**
- If `refresh()` is called multiple times rapidly, multiple tasks run simultaneously
- Previous refresh continues even when new one starts
- Tasks continue running after Client is deallocated
- Network requests aren't cancelled, wasting bandwidth and battery
- No way to cancel when app enters background

**Recommended Fix:**
```swift
private var activeRefreshTask: Task<Void, Never>?
private var activeFetchTasks: [String: Task<Void, Never>] = [:]

func refresh() async {
    // Cancel previous refresh
    activeRefreshTask?.cancel()

    activeRefreshTask = Task {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Check for cancellation throughout
        try? Task.checkCancellation()

        guard prepareCredentials() else {
            self.handleDisconnectedState()
            return
        }

        await fetchStatus()
        try? Task.checkCancellation()

        if let systemStatus = self.systemStatus {
            await fetchConfig(localDeviceID: systemStatus.myID)
            try? Task.checkCancellation()

            // Run concurrent fetches but store for cancellation
            async let versionTask: () = fetchVersion()
            async let connectionsTask: () = fetchConnections()
            async let folderStatusTask: () = fetchFolderStatus()
            async let deviceCompletionTask: () = fetchDeviceCompletions()

            _ = await [versionTask, connectionsTask, folderStatusTask, deviceCompletionTask]
        }
    }
}

deinit {
    activeRefreshTask?.cancel()
    activeFetchTasks.values.forEach { $0.cancel() }
}
```

---

### 5. Tight Coupling Between AppDelegate and Client
**File:** `App.swift` (throughout)
**Severity:** HIGH
**Category:** Architecture, Testability

**Problem:**
AppDelegate directly manages SyncthingClient lifecycle and binds to all its properties, violating single responsibility principle.

**Current Structure:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let syncthingClient: SyncthingClient

    // Direct bindings to 10+ client properties
    syncthingClient.$isConnected.sink { ... }
    syncthingClient.$devices.sink { ... }
    syncthingClient.$folders.sink { ... }
    syncthingClient.$systemStatus.sink { ... }
    syncthingClient.$connections.sink { ... }
    syncthingClient.$folderStatuses.sink { ... }
    // etc...
}
```

**Why it's an issue:**
- AppDelegate has too many responsibilities (UI, client management, notifications)
- Impossible to test AppDelegate in isolation
- Tight coupling makes refactoring difficult
- Hard to mock Client for testing
- Violates dependency inversion principle

**Recommended Fix:**
Create a ViewModel layer to decouple presentation from business logic:

```swift
// New file: StatusViewModel.swift
@MainActor
class StatusViewModel: ObservableObject {
    private let client: SyncthingClient

    // Aggregate state for presentation
    @Published var statusIconState: IconState
    @Published var statusTooltip: String
    @Published var showAlert: Bool = false
    @Published var alertMessage: String?

    init(client: SyncthingClient) {
        self.client = client
        setupBindings()
    }

    private func setupBindings() {
        // Combine multiple client properties into presentation state
        Publishers.CombineLatest3(
            client.$isConnected,
            client.$devices,
            client.$folders
        )
        .map { isConnected, devices, folders in
            self.computeIconState(
                isConnected: isConnected,
                devices: devices,
                folders: folders
            )
        }
        .assign(to: &$statusIconState)
    }

    private func computeIconState(...) -> IconState {
        // Extract complex logic from AppDelegate
    }
}

// Updated AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel: StatusViewModel

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    // Now only observes viewModel, not client directly
}
```

---

### 6. Keychain Operations on Main Thread
**File:** `SyncthingSettings.swift:165-172, 220-262`
**Severity:** HIGH
**Category:** Performance, User Experience

**Problem:**
Keychain read/write/delete operations happen synchronously on the main thread, potentially blocking UI.

**Current Code:**
```swift
private func persistKeychainIfNeeded() {
    guard !isLoading else { return }
    if manualAPIKey.isEmpty {
        keychain.delete()  // Blocks main thread
    } else {
        keychain.save(manualAPIKey)  // Blocks main thread
    }
}
```

**Why it's an issue:**
- Keychain operations can take 50-200ms on slower machines
- Network home directories make this worse (can be seconds)
- Every API key change blocks the UI
- Noticeable lag when typing in settings
- Multiple rapid changes queue up on main thread

**Recommended Fix:**
```swift
private let keychainQueue = DispatchQueue(
    label: "com.syncthingstatus.keychain",
    qos: .userInitiated
)

private func persistKeychainIfNeeded() {
    guard !isLoading else { return }
    let key = manualAPIKey  // Capture value

    keychainQueue.async { [weak self] in
        if key.isEmpty {
            self?.keychain.delete()
        } else {
            self?.keychain.save(key)
        }
    }
}

// For loading, use async/await
func loadAPIKey() async -> String? {
    await withCheckedContinuation { continuation in
        keychainQueue.async { [weak self] in
            let key = self?.keychain.load()
            continuation.resume(returning: key)
        }
    }
}
```

---

### 7. Excessive Settings Saves to UserDefaults
**File:** `SyncthingSettings.swift:6-74`
**Severity:** HIGH
**Category:** Performance, I/O

**Problem:**
Every property change triggers a UserDefaults save via didSet, causing excessive disk I/O.

**Current Pattern:**
```swift
@Published var useAutomaticDiscovery: Bool {
    didSet { persistDefaultsIfNeeded() }
}
@Published var baseURLString: String {
    didSet { persistDefaultsIfNeeded() }
}
// ... 15 more properties with same pattern
```

**Why it's an issue:**
- If multiple settings change rapidly: 15+ UserDefaults writes
- During reset, all properties change → 15+ synchronous I/O operations
- UserDefaults writes are relatively expensive (~10-50ms each)
- No batching or debouncing
- Can cause UI stutter when changing multiple settings

**Recommended Fix - Batch Updates with Debouncing:**
```swift
class SyncthingSettings: ObservableObject {
    // Remove didSet from properties
    @Published var useAutomaticDiscovery: Bool
    @Published var baseURLString: String
    // ... etc

    private var pendingKeys = Set<String>()
    private var saveWorkItem: DispatchWorkItem?

    init(defaults: UserDefaults = .standard, keychainService: String = "...") {
        // ... existing init

        // Setup debounced auto-save
        setupAutoSave()
    }

    private func setupAutoSave() {
        // Observe all published properties
        $useAutomaticDiscovery.sink { [weak self] _ in
            self?.scheduleSave()
        }.store(in: &cancellables)

        $baseURLString.sink { [weak self] _ in
            self?.scheduleSave()
        }.store(in: &cancellables)

        // ... repeat for all properties
    }

    private func scheduleSave() {
        guard !isLoading else { return }

        // Cancel pending save
        saveWorkItem?.cancel()

        // Schedule new save after delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistAllSettings()
        }
        saveWorkItem = workItem

        // Debounce: wait 300ms after last change
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.3,
            execute: workItem
        )
    }

    private func persistAllSettings() {
        defaults.set(useAutomaticDiscovery, forKey: Keys.useAutomaticDiscovery)
        defaults.set(baseURLString, forKey: Keys.baseURLString)
        // ... set all properties in one batch

        // Keychain save
        persistKeychainIfNeeded()
    }

    private var cancellables = Set<AnyCancellable>()
}
```

**Benefits:**
- Multiple rapid changes result in single save
- 300ms debounce prevents excessive I/O
- Better performance during settings changes
- Still saves promptly (within 300ms of last change)

---

### 8. Weak AppDelegate References Create Unsafe Access
**File:** `Views.swift:23, 161, 189`
**Severity:** HIGH
**Category:** Safety, Architecture

**Problem:**
Views use `weak var appDelegate: AppDelegate?` but access it unsafely, and AppDelegate could theoretically be deallocated while view is active.

**Current Code:**
```swift
struct ContentView: View {
    weak var appDelegate: AppDelegate?

    var body: some View {
        // ...
        Button("Open Settings") {
            if let appDelegate {
                appDelegate.presentSettings(using: openSettings.callAsFunction)
            } else {
                openSettings()
            }
        }
    }
}
```

**Why it's an issue:**
- SwiftUI doesn't support weak references in the same way UIKit does
- AppDelegate lifecycle is tied to app, but weak reference suggests it might be nil
- Inconsistent pattern - sometimes checks for nil, sometimes force-unwraps
- If AppDelegate is nil, functionality silently fails
- Makes intent unclear: should AppDelegate outlive views or not?

**Recommended Fix:**
Use proper SwiftUI dependency injection pattern:

```swift
// Option 1: Environment Object (Best for SwiftUI)
@main
struct SyncthingStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                settings: appDelegate.settings,
                syncthingClient: appDelegate.syncthingClient
            )
            .environmentObject(appDelegate)  // Inject as environment
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate  // Strong, guaranteed present
    @ObservedObject var syncthingClient: SyncthingClient
    @ObservedObject var settings: SyncthingSettings
    var isPopover: Bool

    // No more weak reference, no more nil checks
    var body: some View {
        Button("Open Settings") {
            appDelegate.presentSettings(using: openSettings.callAsFunction)
        }
    }
}

// Option 2: Make AppDelegate conform to ObservableObject (if not already)
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // ...
}
```

---

### 9. No Request Timeout Configuration
**File:** `Client.swift:318-342, 344-360`
**Severity:** HIGH
**Category:** Performance, User Experience

**Problem:**
URLSession requests have no explicit timeout, defaulting to 60 seconds, which can make the app unresponsive.

**Current Code:**
```swift
func makeRequest<T: Decodable>(endpoint: String, responseType: T.Type) async throws -> T {
    // ... build request
    let (data, response) = try await session.data(for: request)
    // ... process response
}
```

**Why it's an issue:**
- Default timeout is 60 seconds
- If Syncthing hangs, app is unresponsive for 60s per request
- refresh() makes 4-5 concurrent requests = potentially 60s of hanging
- No user feedback during long waits
- Battery drain from hanging connections

**Recommended Fix:**
```swift
class SyncthingClient: ObservableObject {
    private let session: URLSession

    init(settings: SyncthingSettings, session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10     // 10s per request
            config.timeoutIntervalForResource = 30    // 30s total
            config.waitsForConnectivity = false       // Fail fast
            self.session = URLSession(configuration: config)
        }

        self.settings = settings
        observeSettings()
    }

    // Rest of implementation
}
```

---

### 10. Inconsistent Error Handling
**File:** `Client.swift` (multiple locations: 405-427, 457-469, etc.)
**Severity:** MEDIUM
**Category:** User Experience, Code Quality

**Problem:**
Some errors set `lastErrorMessage`, some print to console only - inconsistent UX.

**Examples:**
```swift
// Location 1: Sets user-facing error
catch {
    let errorMessage = "Failed to fetch config: \(error.localizedDescription)"
    print(errorMessage)
    if !debugMode {
        self.lastErrorMessage = errorMessage  // User sees this
    }
}

// Location 2: Only prints to console
catch {
    print("Failed to fetch folder status for \(folder.id): \(error.localizedDescription)")
    // User never sees this error
}

// Location 3: Different pattern
catch {
    self.lastErrorMessage = "Failed to connect to Syncthing: \(message)"
    // No print statement
}
```

**Why it's an issue:**
- Users won't see errors that are only printed
- Inconsistent user experience
- Hard to track which errors are user-facing
- No error categorization (recoverable vs critical)
- Can't filter or aggregate errors

**Recommended Fix:**
Create a structured error system:

```swift
// New error model
enum ClientError: LocalizedError {
    case connection(message: String, recoverable: Bool)
    case authentication(message: String)
    case apiError(endpoint: String, message: String)
    case configurationError(message: String)
    case timeout(endpoint: String)

    var errorDescription: String? {
        switch self {
        case .connection(let message, _):
            return "Connection Error: \(message)"
        case .authentication(let message):
            return "Authentication Error: \(message)"
        case .apiError(let endpoint, let message):
            return "API Error (\(endpoint)): \(message)"
        case .configurationError(let message):
            return "Configuration Error: \(message)"
        case .timeout(let endpoint):
            return "Request Timeout: \(endpoint)"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .connection(_, let recoverable): return recoverable
        case .timeout: return true
        case .authentication: return false
        case .apiError: return true
        case .configurationError: return false
        }
    }
}

// In Client
@Published var currentError: ClientError?
@Published var errorHistory: [ClientError] = []

private func handleError(_ error: ClientError) {
    print("[ERROR] \(error.errorDescription ?? "Unknown error")")

    if !debugMode {
        self.currentError = error
        self.errorHistory.append(error)

        // Keep only last 10 errors
        if errorHistory.count > 10 {
            errorHistory.removeFirst()
        }
    }
}

// Usage
catch {
    handleError(.apiError(
        endpoint: "system/config",
        message: error.localizedDescription
    ))
}
```

---

### 11. Inefficient Transfer History Management
**File:** `Client.swift:538-546`
**Severity:** MEDIUM
**Category:** Performance, Memory

**Problem:**
Creates new DeviceTransferHistory struct copies on every update, inefficient for 15 devices updating every 10 seconds.

**Current Code:**
```swift
var history = transferHistory[deviceID] ?? DeviceTransferHistory()
history.addDataPoint(downloadRate: rates.downloadRate, uploadRate: rates.uploadRate)
transferHistory[deviceID] = history           // Copy 1
deviceTransferHistory[deviceID] = history     // Copy 2 (duplicate!)
```

**Why it's an issue:**
- DeviceTransferHistory is a struct (value type) so this creates copies
- For 15 devices: 30 struct copies every refresh (10s default)
- That's 180 copies per minute, 10,800 per hour
- Each copy includes 60 data points (arrays)
- `deviceTransferHistory` is a duplicate of `transferHistory`

**Recommended Fix:**
```swift
// Option 1: Make DeviceTransferHistory a class
class DeviceTransferHistory {  // Changed from struct to class
    private(set) var dataPoints: [TransferDataPoint] = []
    private(set) var maxDownloadRate: Double = 0
    private(set) var maxUploadRate: Double = 0

    func addDataPoint(downloadRate: Double, uploadRate: Double) {
        // Direct mutation, no copies
        let point = TransferDataPoint(
            downloadRate: downloadRate,
            uploadRate: uploadRate,
            timestamp: Date()
        )
        dataPoints.append(point)

        // Update max values incrementally
        maxDownloadRate = max(maxDownloadRate, downloadRate)
        maxUploadRate = max(maxUploadRate, uploadRate)

        if dataPoints.count > 60 {
            dataPoints.removeFirst()
        }
    }
}

// In calculateTransferRates:
if transferHistory[deviceID] == nil {
    transferHistory[deviceID] = DeviceTransferHistory()
}
transferHistory[deviceID]?.addDataPoint(
    downloadRate: max(0, downloadRate),
    uploadRate: max(0, uploadRate)
)

// Remove duplicate storage
deviceTransferHistory = transferHistory  // Single assignment, shares references

// Option 2: Keep struct but use in-place mutation
private func calculateTransferRates(newConnections: [String: SyncthingConnection]) {
    // ... existing logic

    // Mutate in place
    if transferHistory[deviceID] == nil {
        transferHistory[deviceID] = DeviceTransferHistory()
    }
    transferHistory[deviceID]?.addDataPoint(...)

    // Share the dictionary, not duplicate it
    deviceTransferHistory = transferHistory
}
```

---

## 🟡 Medium Priority Issues

### 12. Hard-coded Sleep Duration After Config Changes
**File:** `Client.swift:1051`
**Severity:** MEDIUM

**Problem:** Fixed 2-second sleep after config changes may be insufficient or wasteful.

**Recommended Fix:** Poll for Syncthing availability with exponential backoff.

---

### 13. Timer Not Properly Invalidated in Correct Order
**File:** `App.swift:253-267`
**Severity:** MEDIUM

**Problem:** Timer starts before async task completes, could cause race conditions.

---

### 14. Complex Status Icon Update Logic
**File:** `App.swift:269-328`
**Severity:** MEDIUM

**Problem:** 60 lines of nested if-else logic, hard to test and maintain.

**Recommended Fix:** Extract to separate state machine or resolver class.

---

### 15. View Height Tracking Creates Unnecessary Recalculations
**File:** `Views.swift:65-73`
**Severity:** MEDIUM

**Problem:** Preference key changes trigger on every layout, performance impact.

**Recommended Fix:** Add threshold-based updates (only update if change > 5pt).

---

### 16. Chart Calculation Performance Issues
**File:** `Views.swift:505-511, 589-595`
**Severity:** MEDIUM

**Problem:** Max speed calculated on every render by iterating 60+ data points.

**Recommended Fix:** Cache max values in DeviceTransferHistory, update incrementally.

---

### 17. Popover Size Calculation Complexity
**File:** `App.swift:218-251`
**Severity:** LOW

**Problem:** Complex calculations with magic numbers.

---

### 18-24. Additional Medium/Low Priority Issues
(See full code review report for details)

---

## 🟢 Low Priority Issues

### 25. Duplicate Data Storage
**File:** `Client.swift:541-542`

**Problem:** Same data in `transferHistory` and `deviceTransferHistory`.

---

### 26. Magic Numbers Throughout Codebase
**Files:** Multiple locations

**Recommended Fix:** Extract to configuration constants.

---

### 27-32. Additional Low Priority Items
(Code quality improvements, accessibility, formatters, etc.)

---

## Architecture Issues

### A1. No Dependency Injection
**Severity:** HIGH

Direct instantiation throughout makes testing impossible. Need protocol-based abstractions.

---

### A2. No Error Type Hierarchy
**Severity:** MEDIUM

Errors are strings or ad-hoc types. Need comprehensive error hierarchy.

---

### A3. Mixed Responsibilities in Client
**Severity:** HIGH

Client handles API calls, state management, notifications, tracking, etc. Need separation.

---

### A4. No Offline/Mock Mode
**Severity:** LOW

Must run actual Syncthing to test. Need protocol-based client with mock.

---

## Performance Issues Summary

1. **Memory:** Transfer history creates excessive copies (MEDIUM)
2. **CPU:** Chart calculations on every render (MEDIUM)
3. **I/O:** Excessive UserDefaults writes (HIGH)
4. **I/O:** Keychain on main thread (HIGH)
5. **Network:** No request coalescing or caching (LOW)

---

## Security Issues Summary

1. **CRITICAL:** Security-scoped resource not properly managed
2. **MEDIUM:** API keys in memory not cleared
3. **LOW:** No input validation on URLs
4. **LOW:** XML parser unbounded buffer

---

## Recommended Action Plan

### Phase 1: Critical Fixes (This Sprint)
1. ✅ Fix security-scoped resource leak (Issue #1)
2. ✅ Fix race condition in debug mode (Issue #2)
3. ✅ Fix retain cycle in observeSettings (Issue #3)
4. ✅ Add task cancellation (Issue #4)
5. ✅ Batch settings saves (Issue #7)

### Phase 2: High Priority (Next Sprint)
1. Move keychain off main thread (Issue #6)
2. Add request timeouts (Issue #9)
3. Standardize error handling (Issue #10)
4. Improve transfer history efficiency (Issue #11)
5. Fix weak AppDelegate references (Issue #8)

### Phase 3: Architectural Improvements (Future)
1. Decouple AppDelegate and Client (Issue #5)
2. Extract status icon logic to state machine (Issue #14)
3. Implement dependency injection (Issue A1)
4. Create error type hierarchy (Issue A2)
5. Add mock mode for testing (Issue A4)

### Phase 4: Polish (As Time Permits)
1. Cache chart calculations (Issue #16)
2. Add accessibility labels (Issue #24)
3. Convert to static formatters (Issue #26)
4. Add Hashable/Equatable to models (Issue #25)
5. Improve code organization and constants (Issue #27)

---

## Testing Recommendations

After fixes are implemented, test:

1. **Debug Mode Transitions:** Enable/disable rapidly, verify data integrity
2. **Concurrent Refreshes:** Trigger multiple refreshes, check for crashes
3. **Memory Leaks:** Run Instruments to verify fixes
4. **Settings Performance:** Change multiple settings rapidly, check UI responsiveness
5. **Error Scenarios:** Disconnect Syncthing, verify error handling
6. **Long Running:** Leave app running for hours, check resource usage

---

## Metrics to Track

- **Memory Usage:** Should be stable, no growth over time
- **CPU Usage:** Should be minimal when idle
- **Disk I/O:** Reduced writes to UserDefaults/Keychain
- **Network Requests:** Properly cancelled when not needed
- **UI Responsiveness:** No stuttering during settings changes

---

**Next Steps:** Begin implementing Phase 1 fixes in the `Critical-Fixes` branch.
