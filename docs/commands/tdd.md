# Test-Driven Development

Write tests first, then implement. RED → GREEN → REFACTOR.

## When to Use

- New feature implementation
- Bug fixes (write failing test that reproduces bug first)
- Refactoring existing code
- Critical business logic (payments, auth, data handling)

## The Cycle

```
┌─────────────────────────────────────────┐
│  1. RED: Write a failing test           │
│     ↓                                   │
│  2. GREEN: Write minimal code to pass   │
│     ↓                                   │
│  3. REFACTOR: Clean up, tests stay green│
│     ↓                                   │
│  4. REPEAT                              │
└─────────────────────────────────────────┘
```

## Step 1: Define What to Test

Before writing any code, answer:

- What should this function/view/feature do?
- What are the inputs and expected outputs?
- What are the edge cases?
- What should happen when things go wrong?

Write these down as test case names:

```swift
// Example: Testing a date formatter
func test_formatDate_returnsRelativeString_forToday()
func test_formatDate_returnsWeekday_forThisWeek()
func test_formatDate_returnsFullDate_forOlderDates()
func test_formatDate_handlesNil_gracefully()
```

## Step 2: Write Failing Test (RED)

Write the test before the implementation exists:

```swift
func test_calculateTotal_appliesDiscount() {
    let cart = ShoppingCart()
    cart.add(item: Item(price: 100))
    cart.applyDiscount(percent: 10)

    XCTAssertEqual(cart.total, 90) // This will fail - no implementation yet
}
```

**Run the test. It MUST fail.** If it passes, your test is wrong.

## Step 3: Write Minimal Code (GREEN)

Write the simplest code that makes the test pass:

```swift
struct ShoppingCart {
    private var items: [Item] = []
    private var discountPercent: Double = 0

    var total: Double {
        let subtotal = items.reduce(0) { $0 + $1.price }
        return subtotal * (1 - discountPercent / 100)
    }

    mutating func add(item: Item) {
        items.append(item)
    }

    mutating func applyDiscount(percent: Double) {
        discountPercent = percent
    }
}
```

**Run the test. It MUST pass now.**

## Step 4: Refactor

With tests green, improve the code:

- Extract helper functions
- Rename for clarity
- Remove duplication
- Improve performance

**Run tests after each change. They must stay green.**

## Step 5: Repeat

Move to the next test case. Continue the cycle.

## Coverage Guidelines

| Code Type | Target Coverage |
|-----------|-----------------|
| General code | 80%+ |
| Business logic | 100% |
| Financial/billing | 100% |
| Authentication | 100% |
| Data handling | 100% |
| UI code | Focus on logic, not layout |

## XCTest Quick Reference

```swift
// Assertions
XCTAssertEqual(actual, expected)
XCTAssertNotEqual(actual, notExpected)
XCTAssertTrue(condition)
XCTAssertFalse(condition)
XCTAssertNil(optional)
XCTAssertNotNil(optional)
XCTAssertThrowsError(try expression)

// Async testing
func test_async() async throws {
    let result = await fetchData()
    XCTAssertEqual(result.count, 5)
}

// Setup and teardown
override func setUp() {
    // Runs before each test
}

override func tearDown() {
    // Runs after each test
}
```

## Common Mistakes

**DON'T:**
- Write implementation before tests
- Skip running the test to see it fail
- Write multiple features before testing
- Test implementation details (private methods)
- Over-mock (test real behavior when possible)

**DO:**
- One assertion focus per test (can have multiple XCTAssert, but one concept)
- Test behavior, not implementation
- Use descriptive test names
- Keep tests independent (no shared state)
- Test edge cases and error conditions

## Integration with /execute

When using TDD with wave-based execution:

```markdown
### Wave 1: Write Tests
- [ ] Task 1.1: Write tests for UserAuth → `UserAuthTests.swift`
- [ ] Task 1.2: Write tests for LoginView → `LoginViewTests.swift`

### Wave 2: Implement (tests guide you)
- [ ] Task 2.1: Implement UserAuth → `UserAuth.swift`
- [ ] Task 2.2: Implement LoginView → `LoginView.swift`

### Wave 3: Refactor & Polish
- [ ] Task 3.1: Refactor, ensure tests still pass
```

---

*Adapted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) TDD workflow*
