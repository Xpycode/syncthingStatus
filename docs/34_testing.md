<!--
TRIGGERS: test, testing, unit test, XCTest, TDD, mock, stub, coverage, XCUITest
PHASE: implementation, shipping
LOAD: full
-->

# Testing Guide

*What to test, how to test it, and when tests are worth writing.*

---

## Testing Strategy

### The Pragmatic Approach

Not everything needs tests. Focus testing effort where it matters most:

| Priority | What to Test | Why |
|----------|--------------|-----|
| **High** | Parsers, data transforms | Complex logic, easy to break |
| **High** | Business rules, calculations | Core correctness matters |
| **High** | State machines | Many edge cases |
| **Medium** | API request/response handling | Integration points break |
| **Medium** | Error paths | Often untested, often broken |
| **Low** | Simple CRUD | Low complexity |
| **Skip** | UI layout, colors | Better verified visually |
| **Skip** | Third-party library wrappers | Not your code |

### When to Write Tests

**Write tests when:**
- Logic is complex (multiple branches, edge cases)
- Bugs would be expensive (data corruption, security)
- You keep breaking the same thing
- You need confidence to refactor

**Skip tests when:**
- Code is trivial (simple getters, direct pass-through)
- Manual testing is faster and sufficient
- The feature is experimental and likely to change

---

## Test Types

### Unit Tests

Test individual functions/methods in isolation.

```swift
// What you're testing
func calculateDiscount(price: Double, tier: CustomerTier) -> Double {
    switch tier {
    case .standard: return price * 0.0
    case .silver: return price * 0.1
    case .gold: return price * 0.2
    }
}

// The test
func testGoldCustomerGets20PercentDiscount() {
    let discount = calculateDiscount(price: 100, tier: .gold)
    XCTAssertEqual(discount, 20.0)
}
```

### Integration Tests

Test multiple components working together.

```swift
func testSaveAndLoadProject() async throws {
    let store = ProjectStore()
    let project = Project(name: "Test")

    try await store.save(project)
    let loaded = try await store.load(project.id)

    XCTAssertEqual(loaded.name, "Test")
}
```

### UI Tests (XCUITest)

Test actual user flows through the interface.

```swift
func testUserCanCreateNewDocument() {
    let app = XCUIApplication()
    app.launch()

    app.menuBars.menuItems["File"].click()
    app.menuBars.menuItems["New"].click()

    XCTAssertTrue(app.windows["Untitled"].exists)
}
```

---

## XCTest Basics

### Test Structure

```swift
import XCTest
@testable import YourApp

final class ParserTests: XCTestCase {

    // Runs before each test
    override func setUp() {
        super.setUp()
        // Reset state
    }

    // Runs after each test
    override func tearDown() {
        // Cleanup
        super.tearDown()
    }

    func testParseValidInput() {
        // Arrange
        let input = "valid data"
        let parser = Parser()

        // Act
        let result = parser.parse(input)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)
    }

    func testParseInvalidInputThrows() {
        let parser = Parser()

        XCTAssertThrowsError(try parser.parse("invalid")) { error in
            XCTAssertEqual(error as? ParseError, .invalidFormat)
        }
    }
}
```

### Common Assertions

```swift
// Equality
XCTAssertEqual(actual, expected)
XCTAssertNotEqual(actual, expected)

// Boolean
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Nil
XCTAssertNil(value)
XCTAssertNotNil(value)

// Errors
XCTAssertThrowsError(try riskyOperation())
XCTAssertNoThrow(try safeOperation())

// Floating point (with tolerance)
XCTAssertEqual(1.0, 1.0001, accuracy: 0.01)

// Fail explicitly
XCTFail("This should not happen")
```

### Async Testing

```swift
func testAsyncOperation() async throws {
    let service = DataService()
    let result = try await service.fetchData()
    XCTAssertFalse(result.isEmpty)
}

// Or with expectations (older style)
func testAsyncWithExpectation() {
    let expectation = expectation(description: "Data loaded")

    service.loadData { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
}
```

---

## Swift Testing Framework (Swift 6+)

The newer `Testing` framework offers cleaner syntax:

```swift
import Testing
@testable import YourApp

@Suite("Parser Tests")
struct ParserTests {

    @Test("Parses valid input correctly")
    func parseValidInput() {
        let result = Parser().parse("valid")
        #expect(result != nil)
        #expect(result?.count == 3)
    }

    @Test("Throws on invalid input")
    func parseInvalidInput() throws {
        #expect(throws: ParseError.invalidFormat) {
            try Parser().parse("invalid")
        }
    }

    @Test("Handles edge cases", arguments: ["", " ", "\n"])
    func parseEdgeCases(input: String) {
        let result = Parser().parse(input)
        #expect(result == nil)
    }
}
```

### Key Differences from XCTest

| XCTest | Swift Testing |
|--------|---------------|
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `class XCTestCase` | `@Suite struct` |
| `func test...()` | `@Test func ...()` |

---

## Mocking and Stubbing

### Protocol-Based Mocking

```swift
// Define protocol for the dependency
protocol DataFetching {
    func fetch(id: String) async throws -> Data
}

// Real implementation
class NetworkDataFetcher: DataFetching {
    func fetch(id: String) async throws -> Data {
        // Real network call
    }
}

// Mock for testing
class MockDataFetcher: DataFetching {
    var mockData: Data?
    var shouldThrow = false
    var fetchCallCount = 0

    func fetch(id: String) async throws -> Data {
        fetchCallCount += 1
        if shouldThrow { throw TestError.simulated }
        return mockData ?? Data()
    }
}

// In tests
func testViewModelLoadsData() async {
    let mock = MockDataFetcher()
    mock.mockData = testData

    let viewModel = ViewModel(fetcher: mock)
    await viewModel.load()

    XCTAssertEqual(mock.fetchCallCount, 1)
    XCTAssertNotNil(viewModel.data)
}
```

### Dependency Injection Patterns

```swift
// Constructor injection (preferred)
class ViewModel {
    private let fetcher: DataFetching

    init(fetcher: DataFetching = NetworkDataFetcher()) {
        self.fetcher = fetcher
    }
}

// Property injection (for optional dependencies)
class ViewModel {
    var logger: Logging = DefaultLogger()
}

// Environment-based (SwiftUI)
struct ContentView: View {
    @Environment(\.dataFetcher) var fetcher
}
```

---

## Test Organization

### File Structure

```
Tests/
├── YourAppTests/
│   ├── Models/
│   │   ├── ProjectTests.swift
│   │   └── UserTests.swift
│   ├── Services/
│   │   ├── ParserTests.swift
│   │   └── NetworkServiceTests.swift
│   ├── ViewModels/
│   │   └── MainViewModelTests.swift
│   ├── Mocks/
│   │   ├── MockDataFetcher.swift
│   │   └── MockStorage.swift
│   └── Helpers/
│       └── TestData.swift
└── YourAppUITests/
    └── UserFlowTests.swift
```

### Naming Conventions

```swift
// Test class: [Subject]Tests
class ParserTests: XCTestCase { }

// Test method: test_[scenario]_[expectedResult]
func test_parseEmptyString_returnsNil() { }
func test_parseValidJSON_returnsModel() { }
func test_parseInvalidJSON_throwsError() { }

// Or: test[Action][Condition][ExpectedResult]
func testParseReturnsNilForEmptyString() { }
```

---

## Common Testing Gotchas

### 1. Testing Async Code on Main Thread

**Problem:** SwiftUI ViewModels are `@MainActor`, tests run on background.

```swift
// Wrong - may crash or behave unexpectedly
func testViewModel() async {
    let vm = ViewModel()  // @MainActor
    await vm.load()
}

// Right - explicitly run on MainActor
@MainActor
func testViewModel() async {
    let vm = ViewModel()
    await vm.load()
    XCTAssertNotNil(vm.data)
}
```

### 2. Flaky Tests Due to Timing

**Problem:** Tests pass sometimes, fail others.

```swift
// Wrong - race condition
func testNotification() {
    NotificationCenter.default.post(name: .dataLoaded, object: nil)
    XCTAssertTrue(viewModel.hasData)  // May not have processed yet
}

// Right - use expectations
func testNotification() {
    let exp = expectation(for: NSPredicate { _, _ in
        self.viewModel.hasData
    }, evaluatedWith: nil)

    NotificationCenter.default.post(name: .dataLoaded, object: nil)
    wait(for: [exp], timeout: 1.0)
}
```

### 3. Testing File System

**Problem:** Tests leave files behind or depend on file locations.

```swift
// Right - use temporary directory
func testFileSave() throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let store = FileStore(directory: tempDir)
    try store.save(testData)

    XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("data.json").path))
}
```

### 4. Not Testing Error Paths

**Problem:** Only testing happy paths, errors untested.

```swift
// Add error case tests
func testLoadHandlesMissingFile() async {
    let store = FileStore(directory: nonExistentPath)

    do {
        _ = try await store.load()
        XCTFail("Should have thrown")
    } catch {
        XCTAssertEqual(error as? StoreError, .fileNotFound)
    }
}
```

### 5. Over-Mocking

**Problem:** Mocking so much that tests don't catch real bugs.

```swift
// Too much mocking - test proves nothing
func testBadExample() {
    let mockParser = MockParser()
    mockParser.mockResult = expectedResult

    let result = mockParser.parse(input)  // Just returns mock
    XCTAssertEqual(result, expectedResult)  // Always passes!
}

// Better - test real logic, mock only external dependencies
func testGoodExample() {
    let realParser = Parser()
    let result = realParser.parse(input)  // Tests actual code
    XCTAssertEqual(result, expectedResult)
}
```

---

## Asking Claude to Write Tests

### Generate Tests for Existing Code

```
Write unit tests for this function. Cover:
1. Normal inputs
2. Edge cases (empty, nil, max values)
3. Error conditions

[paste function]
```

### Test-Driven Development

```
I need a function that [description].

Write the tests first, then implement the function to pass them.
Include edge cases.
```

### Add Tests for Bug Fix

```
I fixed this bug: [description]

Write a regression test that would have caught it.
The test should fail before the fix and pass after.
```

### Generate Mock Objects

```
Create a mock for this protocol for testing:

[paste protocol]

Include:
- Properties to control return values
- Call counting
- Ability to simulate errors
```

---

## Test Coverage Guidelines

### What Coverage Means

- **Line coverage:** Was this line executed during tests?
- **Branch coverage:** Was each if/else path taken?
- **100% coverage ≠ bug-free:** Tests can execute code without verifying behavior

### Practical Targets

| Code Type | Target Coverage | Notes |
|-----------|-----------------|-------|
| Parsers, transforms | 90%+ | High value, test thoroughly |
| Business logic | 80%+ | Core correctness |
| ViewModels | 60-80% | Test logic, not UI binding |
| UI code | 20-40% | Focus on critical flows |
| Utilities | 80%+ | Usually easy to test |

### Viewing Coverage in Xcode

1. Edit Scheme → Test → Options → Code Coverage ✓
2. Run tests (⌘U)
3. View: Editor → Show Code Coverage

---

## Quick Reference

### Test Checklist

Before shipping, verify:

```
[ ] Critical paths have tests
[ ] Parsers/transforms tested with valid, invalid, edge case inputs
[ ] Error paths tested (not just happy paths)
[ ] Async code properly awaited
[ ] No flaky tests (run suite 3x)
[ ] Tests clean up after themselves
[ ] Tests don't depend on execution order
```

### When Tests Fail in CI

1. **Run locally first** — same configuration
2. **Check for timing issues** — add explicit waits
3. **Check for order dependence** — run single test in isolation
4. **Check for environment differences** — file paths, permissions

---

*Add tests as you build. Retrofitting tests to untested code is painful—writing them alongside is natural.*
