# Security Rules Reference

**Triggers:** security, secrets, credentials, authentication, privacy, HIPAA, healthcare data

Mandatory security checks before any commit.

---

## The Non-Negotiables

Every commit must pass these checks:

### 1. No Hardcoded Secrets

**Never commit:**
- API keys
- Passwords
- Tokens (auth, refresh, API)
- Private keys
- Database credentials
- Encryption keys

**Instead:**
```swift
// ❌ NEVER
let apiKey = "sk-1234567890abcdef"

// ✅ Environment variable
let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? ""

// ✅ Keychain (for apps)
let apiKey = KeychainManager.shared.get("api_key")

// ✅ Configuration file (gitignored)
let config = try Configuration.load() // reads from Config.plist (gitignored)
```

### 2. Validate All User Input

Never trust input from:
- Text fields
- URL parameters
- File contents
- Clipboard
- External APIs

```swift
// ❌ Direct use
let query = "SELECT * FROM users WHERE id = \(userInput)"

// ✅ Parameterized
let query = "SELECT * FROM users WHERE id = ?"
try db.execute(query, [userInput])

// ✅ Sanitized
let sanitized = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
guard sanitized.count < 1000 else { throw InputError.tooLong }
```

### 3. Authentication Checks

Every protected resource must verify auth:

```swift
// ❌ Missing check
func getProfile() -> UserProfile {
    return currentUser.profile
}

// ✅ With auth check
func getProfile() throws -> UserProfile {
    guard let user = AuthManager.shared.currentUser else {
        throw AuthError.notAuthenticated
    }
    return user.profile
}
```

### 4. Safe Error Messages

Don't expose internals:

```swift
// ❌ Leaks information
catch {
    return "Database error: \(error.localizedDescription) at line 42"
}

// ✅ Generic message
catch {
    Logger.error("DB error: \(error)") // Log details internally
    return "Something went wrong. Please try again."
}
```

---

## Healthcare/HIPAA Considerations

If handling health data, additional rules apply:

### Protected Health Information (PHI)

Never log, display, or transmit without encryption:
- Patient names
- Dates (birth, admission, discharge)
- Contact information
- Medical record numbers
- Device identifiers
- Biometric identifiers
- Photos

### Data Handling

```swift
// ❌ Logging PHI
print("Processing patient: \(patient.name)")

// ✅ Anonymized logging
print("Processing patient ID: \(patient.hashedId)")

// ❌ Unencrypted storage
UserDefaults.standard.set(healthData, forKey: "health")

// ✅ Encrypted storage
try SecureStorage.shared.store(healthData, key: "health")
```

### Minimum Necessary

Only access/display the minimum data needed:

```swift
// ❌ Loading everything
let patient = try database.loadPatient(id, includeAll: true)

// ✅ Only what's needed
let patient = try database.loadPatient(id, fields: [.name, .currentMedication])
```

---

## Security Checklist

Before every commit:

- [ ] **No secrets** in code, configs, or comments
- [ ] **All inputs validated** before use
- [ ] **Auth checks** on protected resources
- [ ] **Error messages** don't leak internals
- [ ] **Logging** doesn't include sensitive data
- [ ] **HTTPS only** for network calls
- [ ] **Encryption** for sensitive stored data

## File-Level Checklist

Scan for these patterns:

| Search For | Red Flag |
|------------|----------|
| `password`, `secret`, `key`, `token` | Hardcoded credential? |
| `print(`, `NSLog(`, `Logger.` | Logging sensitive data? |
| String concatenation in queries | SQL injection risk? |
| `.userDefaults` with sensitive data | Unencrypted storage? |
| `http://` (not https) | Insecure connection? |
| `try?` or `try!` | Silencing security errors? |

---

## If You Find a Security Issue

1. **Stop** - Don't commit
2. **Fix** - Address the vulnerability
3. **Rotate** - If secrets were exposed, rotate them immediately
4. **Audit** - Check for similar issues elsewhere
5. **Document** - Log what happened and how it was fixed

---

## Related

- `34_testing.md` - Security testing section
- `/code-review` command - Includes security checks
- `22_macos-platform.md` - Keychain, sandboxing

---

*Adapted from [everything-claude-code](https://github.com/affaan-m/everything-claude-code) security rules*
