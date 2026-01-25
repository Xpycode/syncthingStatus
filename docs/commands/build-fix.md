# Build Fix

Resolve Xcode build errors quickly with minimal changes.

## When to Use

- Xcode build fails with errors
- Swift compiler errors blocking progress
- "Cannot find X in scope" mysteries
- Type mismatches and inference failures
- Import/module resolution problems

## Core Principle

**Minimal diffs only.** Fix the error, nothing else. No refactoring, no improvements, no cleanup. Get it building, then move on.

## Step 1: Collect All Errors

Build and capture the full error list:

```bash
# Command line build (shows all errors)
xcodebuild -scheme "YourScheme" -destination "platform=macOS" build 2>&1 | grep -E "error:|warning:"

# Or just build in Xcode and check Issue Navigator (⌘5)
```

**Don't stop at the first error.** Often fixing one reveals others, or multiple errors have the same root cause.

## Step 2: Categorize Errors

| Error Type | Example | Typical Fix |
|------------|---------|-------------|
| **Missing import** | "Cannot find 'X' in scope" | Add `import Module` |
| **Type mismatch** | "Cannot convert 'A' to 'B'" | Add explicit type or conversion |
| **Optional unwrap** | "Value of optional type must be unwrapped" | Use `if let`, `guard let`, or `??` |
| **Missing conformance** | "Type does not conform to 'X'" | Add required protocol methods |
| **Access control** | "X is inaccessible due to 'private'" | Change access level |
| **Circular dependency** | Module import cycles | Restructure imports |

## Step 3: Fix in Priority Order

### 🔴 Fix First: Import/Module Errors
These cascade into many false errors. Fix them first.

```swift
// ❌ Cannot find 'URLSession' in scope
let session = URLSession.shared

// ✅ Add import
import Foundation
let session = URLSession.shared
```

### 🟡 Fix Second: Type Errors

```swift
// ❌ Cannot convert value of type 'String' to expected argument type 'Int'
let count: Int = textField.text

// ✅ Parse the string
let count: Int = Int(textField.text ?? "0") ?? 0
```

### 🟢 Fix Third: Optional Handling

```swift
// ❌ Value of optional type 'String?' must be unwrapped
let name: String = user.name

// ✅ Provide default
let name: String = user.name ?? "Unknown"

// ✅ Or guard
guard let name = user.name else { return }
```

## Step 4: SwiftUI-Specific Errors

Reference: `20_swiftui-gotchas.md`

### View Body Return Type
```swift
// ❌ Function declares an opaque return type, but has no return statements
var body: some View {
    if condition {
        Text("Yes")
    }
    // Missing else!
}

// ✅ Always return something
var body: some View {
    if condition {
        Text("Yes")
    } else {
        EmptyView()
    }
}
```

### Missing Identifiable
```swift
// ❌ Initializer 'init(_:content:)' requires 'Item' conform to 'Identifiable'
ForEach(items) { item in ... }

// ✅ Add id parameter
ForEach(items, id: \.self) { item in ... }

// ✅ Or make type Identifiable
struct Item: Identifiable {
    let id = UUID()
    ...
}
```

### State Mutation in Init
```swift
// ❌ Cannot assign to property: 'self' is immutable
init(name: String) {
    self.name = name      // This is fine
    _items = State(initialValue: [])  // Use underscore for State
}
```

## Step 5: Verify Fix

After each fix:

1. **Build again** - Check if error is gone
2. **Check for new errors** - Sometimes fixes reveal hidden issues
3. **Run affected tests** - Make sure fix didn't break behavior

## Minimal Diff Examples

```swift
// File has 200 lines, error on line 45

// ❌ WRONG: Refactor the whole function
// Result: 50 lines changed, new bugs possible

// ✅ CORRECT: Fix only the error
// Line 45: func process(data) { ...
// Change to: func process(data: [String]) { ...
// Result: 1 line changed
```

## Quick Reference: Common Xcode Errors

| Error Message | Quick Fix |
|---------------|-----------|
| "Cannot find 'X' in scope" | Add import or check spelling |
| "Type 'X' has no member 'Y'" | Check property name, might be optional |
| "Missing argument for parameter 'X'" | Add the required parameter |
| "Extra argument in call" | Remove the extra parameter |
| "Ambiguous use of 'X'" | Add explicit type annotation |
| "Expression type 'X' is ambiguous" | Break into multiple lines with types |
| "Escaping closure captures mutating 'self'" | Use `[weak self]` or restructure |
| "Modifying state during view update" | Move mutation to `.onAppear` or button action |

## When NOT to Use This

Use `/build-fix` only for compilation errors. For other issues:

- Logic bugs → Debug normally
- Architecture problems → Plan refactor
- Performance issues → Profile first
- Test failures → Fix the code, not the test

## Success Criteria

- ✅ Build succeeds (exit code 0)
- ✅ No new warnings introduced
- ✅ Minimal lines changed
- ✅ No behavioral changes (just compilation fixes)
- ✅ Tests still pass

---

*Adapted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) build-error-resolver agent*
