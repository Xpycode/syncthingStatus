<!--
TRIGGERS: UI not updating, @Observable, @State, SwiftUI bug, layout broken, view not refreshing
PHASE: implementation
LOAD: full
-->

# SwiftUI Gotchas Reference

*Common pitfalls that cause bugs in macOS/iOS development.*

---

## The Big Five (Most Common Issues)

### 1. @Observable Doesn't Detect Nested Mutations

**Problem:** UI doesn't update when you change a nested property.

```swift
// BROKEN: @Observable doesn't see this
video.activeSelection?.inPoint = newValue

// WORKS: Reassign the entire struct
var selection = video.activeSelection
selection?.inPoint = newValue
video.activeSelection = selection
```

**Why:** Swift's `@Observable` macro only detects when properties are *assigned*, not when nested values inside them mutate.

**Detection:** UI doesn't update. Add logging: `print("hasSelection: \(hasSelection), value: \(value)")` — if values are correct but UI is stale, this is likely the cause.

**Rule:** When modifying nested properties in `@Observable` objects, always reassign the parent property.

---

### 2. @State with Class References

**Problem:** Toggle buttons stuck, UI doesn't respond to state changes.

```swift
// BROKEN: @State doesn't observe class changes
@State private var manager = SomeManager.shared

// WORKS: Use explicit state + refresh trigger
@State private var isEnabled = false
@State private var refreshTrigger = UUID()

Button("Toggle") {
    manager.toggle()
    isEnabled = manager.isEnabled
    refreshTrigger = UUID()  // Force view refresh
}
```

**Why:** `@State` is designed for value types (structs). Class reference changes don't trigger view updates.

**Rule:** For class-backed state, use explicit `@State` properties that you manually update, or use `@Observable` properly.

---

### 3. HSplitView Layout Bugs

**Problem:** Large empty spaces, content doesn't fill vertical space, unpredictable sizing.

```swift
// BROKEN: HSplitView on macOS has quirks
HSplitView {
    SidebarView()
    ContentView()
}

// WORKS: Manual layout with dividers
HStack(spacing: 0) {
    SidebarView()
        .frame(width: sidebarWidth)

    Divider()

    ContentView()
}
```

**Why:** `HSplitView` on macOS doesn't properly fill vertical space in all configurations.

**Rule:** Prefer `HStack` + `Divider()` for predictable macOS layouts.

---

### 4. PreferenceKey.reduce() Conditionals

**Problem:** Popover sizing breaks, initial layout wrong.

```swift
// BROKEN: Conditional blocks updates
struct ContentHeightKey: PreferenceKey {
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if abs(next - value) > threshold {  // DON'T DO THIS
            value = next
        }
    }
}

// WORKS: Always take the value
struct ContentHeightKey: PreferenceKey {
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())  // Always update
    }
}
```

**Why:** Adding thresholds or conditional updates breaks initial popover sizing. SwiftUI depends on consistent reduce behavior.

**Rule:** In `PreferenceKey.reduce()`, always use `value = max(value, nextValue())` or similar unconditional logic.

---

### 5. .clipped() vs .clipShape()

**Problem:** Overlays extend outside intended bounds.

```swift
// BROKEN: .clipped() only clips the view, not overlays
Rectangle()
    .frame(width: 100, height: 100)
    .clipped()
    .overlay {
        Text("Hello")  // NOT clipped!
    }

// WORKS: .clipShape() clips the entire composite
Color.clear
    .frame(width: 100, height: 100)
    .overlay {
        Text("Hello")  // IS clipped
    }
    .clipShape(Rectangle())
```

**Why:** `.clipped()` applies before overlays are added. `.clipShape()` applies to the final composite.

**Rule:** Use `.clipShape(Rectangle())` when you need to constrain overlays within bounds.

---

## Layout Issues

### Text Wrapping at Narrow Widths

**Problem:** Labels break into stacked individual characters.

```swift
// BROKEN: Multiple Labels wrap character-by-character
HStack {
    Label("Duration", systemImage: "clock")
    Label("Size", systemImage: "doc")
    Label("Format", systemImage: "film")
}

// WORKS: Single Text with inline separators
Text("Duration • Size • Format")
```

**Rule:** For narrow layouts, use single `Text` with separators instead of multiple `Label` views.

---

### State Mutation During View Updates

**Problem:** Infinite update loops, "Publishing changes from within view updates" warning.

```swift
// BROKEN: Modifying state in body computation
var body: some View {
    if condition {
        viewModel.updateSomething()  // NEVER do this
    }
    return SomeView()
}

// WORKS: Use onChange or task
var body: some View {
    SomeView()
        .onChange(of: condition) { _, newValue in
            if newValue {
                viewModel.updateSomething()
            }
        }
}
```

**Rule:** Never modify `@Published` properties during view body computation. Use `.onChange`, `.task`, or `.onAppear`.

---

### ForEach + ObservedObject Rebuilds

**Problem:** O(n) view rebuilds when any item changes.

```swift
// SLOW: Every item rebuilds when collection changes
ForEach(viewModel.items) { item in
    ItemRow(item: item)
}

// BETTER: Use identifiable items with stable IDs
ForEach(viewModel.items, id: \.stableId) { item in
    ItemRow(item: item)
}
```

**Why:** If IDs change, SwiftUI treats them as new items and rebuilds everything.

**Rule:** Use stable IDs that don't change when content changes (UUID assigned at creation, not content hash).

---

## Threading Issues

### Publishing from Background Threads

**Problem:** Purple runtime warning, potential crashes.

```swift
// BROKEN: Combine sink runs on background thread
cancellable = publisher
    .sink { value in
        viewModel.value = value  // Wrong thread!
    }

// WORKS: Receive on main thread
cancellable = publisher
    .receive(on: DispatchQueue.main)
    .sink { value in
        viewModel.value = value
    }
```

**Rule:** Always `.receive(on: DispatchQueue.main)` before updating `@Published` properties.

---

### Deferred @Published Updates

**Problem:** Removing `DispatchQueue.main.async` breaks updates.

```swift
// Sometimes needed to defer @Published changes
DispatchQueue.main.async {
    self.viewModel.isLoading = false
}
```

**Why:** Sometimes updates need to be deferred to the next run loop to avoid "Publishing changes from within view updates."

**Rule:** If removing `DispatchQueue.main.async` breaks things, it's probably needed for timing. Document why.

---

## NSCursor Issues

### Cursor Stack Imbalance

**Problem:** Cursor gets stuck in wrong state (spinning, crosshair, etc.)

```swift
// BROKEN: Push without guaranteed pop
func startOperation() {
    NSCursor.pointingHand.push()
    // If this throws, pop never happens
    try riskyOperation()
    NSCursor.pop()
}

// WORKS: Use defer
func startOperation() {
    NSCursor.pointingHand.push()
    defer { NSCursor.pop() }
    try riskyOperation()
}
```

**Rule:** Always use `defer { NSCursor.pop() }` immediately after pushing a cursor.

---

## Window and Popover Issues

### Window Style Causing Layout Problems

**Problem:** Extra space between title bar and content.

```swift
// PROBLEMATIC: Can cause spacing issues
.windowStyle(.hiddenTitleBar)

// SAFER: Standard window style
// (remove .windowStyle modifier entirely)
```

**Rule:** Only use `.windowStyle(.hiddenTitleBar)` if you've tested all layout scenarios.

---

## Quick Diagnostic Commands

When UI doesn't update, add this logging:

```swift
print("State check - hasSelection: \(hasSelection), isEnabled: \(isEnabled), count: \(items.count)")
```

If values are correct but UI is wrong → `@Observable` / `@State` observation issue.
If values are wrong → Logic bug, trace the data flow.

---

## Summary Table

| Issue | Symptom | Fix |
|-------|---------|-----|
| Nested mutation | UI doesn't update | Reassign parent property |
| @State + class | Buttons stuck | Use explicit @State + refreshTrigger |
| HSplitView | Layout gaps | Use HStack + Divider |
| PreferenceKey conditional | Sizing breaks | Always use max(value, nextValue()) |
| .clipped() | Overlay escapes | Use .clipShape(Rectangle()) |
| Background publish | Purple warning | .receive(on: .main) |
| Cursor imbalance | Cursor stuck | defer { NSCursor.pop() } |

---

*Add issues to this document as you encounter them.*
