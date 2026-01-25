<!--
TRIGGERS: README template, CHANGELOG template, SECURITY, PRIVACY, documentation
PHASE: planning
LOAD: sections
-->

# Documentation Templates

*Ready-to-use templates for project documentation.*

---

## CHANGELOG.md Template

Based on [Keep a Changelog](https://keepachangelog.com/) format with file:line references.

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- New feature description

### Changed
- Modified behavior description

### Fixed
- Bug fix description

## [1.2.0] - 2026-01-15

### Added
- Dark mode support (#12)
- Export to PDF feature

### Changed
- Improved thumbnail generation performance (ThumbnailCache.swift:45)
- Updated minimum macOS version to 14.0

### Fixed
- Crash when opening empty file (SettingsView.swift:234)
- Memory leak in video preview (VideoPlayer.swift:89)

### Security
- Updated dependency X to fix CVE-XXXX-XXXX

## [1.1.0] - 2026-01-01

### Added
- Initial release features
```

**Key Points:**
- Use `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Security`
- Include file:line references for fixes
- Link to issues/PRs where applicable
- Most recent version at top

---

## SECURITY.md Template

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via:

1. **GitHub Security Advisories** (preferred): [Create advisory](link)
2. **Email**: security@yourdomain.com

### What to Include

- Type of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

| Stage | Timeline |
|-------|----------|
| Initial acknowledgment | 24 hours |
| Detailed response | 3 business days |
| Status updates | Weekly |
| Resolution target | 90 days |

### Safe Harbor

We will not pursue legal action against security researchers who:
- Make a good faith effort to avoid privacy violations
- Avoid destruction of data
- Give us reasonable time to respond before disclosure

## Security Measures

This application implements:
- Input validation on all user-provided data
- Secure credential storage in macOS Keychain
- Code signing and notarization
- No collection of personal data
```

---

## PRIVACY.md Template

```markdown
# Privacy Policy

**Last Updated:** [Date]

## Overview

[App Name] is designed with privacy in mind. This document explains what data
the app accesses and how it's handled.

## Data Collection

**[App Name] does not collect, store, or transmit any personal data.**

- No usage statistics
- No tracking
- No analytics
- No third-party services

## Data Storage

All data is stored locally on your device:

| Data Type | Storage Location | Purpose |
|-----------|------------------|---------|
| Preferences | UserDefaults | App settings |
| Credentials | macOS Keychain | Secure API key storage |
| Cache | ~/Library/Caches/[App] | Performance optimization |
| Documents | User-selected locations | User files |

## Network Communication

[Choose one:]

**Option A - No Network:**
This app does not communicate over the network.

**Option B - Limited Network:**
[App Name] only communicates with:
- [Specific endpoint] for [specific purpose]

No user data is transmitted. API keys are stored locally and sent only to
authenticate with the configured service.

## Third-Party Services

[None / List any third-party services and link to their privacy policies]

## Open Source

This app is open source. You can verify these claims by reviewing the source
code at: [GitHub URL]

## Contact

Questions about this privacy policy: [email]

## Changes

We will post any changes to this policy on this page with an updated date.
```

---

## README.md Template

```markdown
# [Project Name]

> One-line description of what this does.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)]()
[![Swift](https://img.shields.io/badge/swift-5.9-orange)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

## Why This Tool Exists

[2-3 sentences explaining the problem this solves. What pain point does it address?
Why would someone use this instead of alternatives?]

## Features

### Core
- Feature 1 — Brief description
- Feature 2 — Brief description

### Advanced
- Feature 3 — Brief description

## Screenshots

[Include 1-3 screenshots of the main interface]

![Main Interface](screenshots/main.png)

## Quick Start

```bash
# Download from Releases or build from source
git clone https://github.com/user/project
cd project
open Project.xcodeproj
# Build and run (Cmd+R)
```

## Requirements

- macOS 14.0 (Sonoma) or later
- [Any additional requirements]

## Installation

### Download
Download the latest release from [Releases](link).

### Build from Source
```bash
git clone https://github.com/user/project
cd project
xcodebuild -scheme ProjectName -configuration Release
```

## Usage

### Basic Workflow
1. Step 1
2. Step 2
3. Step 3

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open File | Cmd+O |
| Save | Cmd+S |
| Export | Cmd+E |

## Architecture

```
Project/
├── Sources/
│   ├── Models/      # Data structures
│   ├── Services/    # Business logic (actors)
│   ├── ViewModels/  # UI state
│   └── Views/       # SwiftUI views
├── Resources/       # Assets
└── Tests/           # Unit tests
```

## Troubleshooting

### Problem: [Common issue]
**Solution:** [How to fix it]

### Problem: [Another issue]
**Solution:** [How to fix it]

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Credit any libraries, inspirations, contributors]
```

---

## THREAT_MODEL.md Template

Based on STRIDE methodology.

```markdown
# Threat Model

**Last Updated:** [Date]
**Scope:** [Application name and version]

## Assets to Protect

| Asset | Sensitivity | Impact if Compromised |
|-------|-------------|----------------------|
| User credentials | High | Unauthorized access |
| User files | Medium | Data loss/exposure |
| Application integrity | High | Malware delivery |
| Configuration | Low | Misconfiguration |

## Trust Boundaries

```
[User Input] --> [Validation Layer] --> [Business Logic] --> [File System]
                                               |
                                               v
                                        [Network (if any)]
```

| Component | Trust Level |
|-----------|-------------|
| User input | Untrusted |
| Configuration files | Semi-trusted |
| Local file system | Trusted |
| Network responses | Untrusted |

## STRIDE Analysis

### Spoofing
| Threat | Risk | Mitigation |
|--------|------|------------|
| Malicious file impersonating valid input | Medium | Validate file format headers |

### Tampering
| Threat | Risk | Mitigation |
|--------|------|------------|
| Modified configuration file | Low | Validate configuration values |

### Repudiation
| Threat | Risk | Mitigation |
|--------|------|------------|
| N/A (single-user app) | - | - |

### Information Disclosure
| Threat | Risk | Mitigation |
|--------|------|------------|
| Error messages exposing paths | Low | Generic error messages |
| Sensitive data in logs | Medium | Don't log credentials |

### Denial of Service
| Threat | Risk | Mitigation |
|--------|------|------------|
| Large file causing memory exhaustion | Medium | File size limits, streaming |

### Elevation of Privilege
| Threat | Risk | Mitigation |
|--------|------|------------|
| Path traversal to access system files | High | Validate paths within bounds |

## Recommendations

1. **Input Validation:** Sanitize all user-provided paths and IDs
2. **Error Handling:** Use generic error messages externally
3. **Resource Limits:** Implement timeouts and size limits
4. **Secure Storage:** Use Keychain for sensitive data
```

---

## CLAUDE.md Template

```markdown
# [Project Name]

## Quick Start

```bash
# Build
xcodebuild -scheme ProjectName -configuration Debug build

# Run tests
xcodebuild test -scheme ProjectName
```

## Tech Stack

- Swift 5.9 / SwiftUI
- Minimum: macOS 14.0
- Architecture: MVVM with Actors
- Persistence: JSON files

## Project Structure

```
Sources/
├── Models/          # Pure data structs (Codable, Sendable)
├── Services/        # Business logic (actors)
├── ViewModels/      # UI state (@MainActor, @Observable)
└── Views/           # SwiftUI components
```

## Rules

### Threading
- ViewModels: Always `@MainActor`
- Services: Always `actor`
- Never access shared state from multiple threads without synchronization

### Error Handling
- Never use `try?` to swallow errors
- Log errors with context
- Show user-facing errors appropriately

### State Management
- Use `@Observable` for view models
- Reassign parent when mutating nested structs
- Use `@State` only for view-local state

### Code Style
- Files under 500 lines
- Use `defer` for cleanup
- Document coordinate systems (points vs pixels)

## Critical Rules (Learned the Hard Way)

### Coordinate Systems
NSImage.size returns POINTS, CGImage returns PIXELS.
On Retina: pixels = points × 2.
Always document which you're using.

### @Observable Nested Mutations
@Observable doesn't detect nested property changes.
Must reassign the parent property to trigger updates.

### [Add more as discovered]

## Known Issues

- [Issue 1]: [Description and workaround]

## Current Focus

- [What's being worked on now]
```

---

## SESSION-LOG.md Template

```markdown
# Session Log

## [YYYY-MM-DD] [HH:MM] - [AI Model]

**Goal:** [What we're trying to accomplish]

**Context:** [Current state, any blockers or constraints]

**Actions Taken:**
- [x] Action 1 — outcome
- [x] Action 2 — outcome
- [ ] Action 3 — not completed, reason

**Issues Encountered:**
- Issue: [Description]
  - Cause: [Root cause]
  - Fix: [How it was resolved]

**Commit:** `abc1234` — "Commit message"

**Next Session:**
- [ ] Task 1
- [ ] Task 2

---

## [Previous Date] [Time] - [Model]

[Previous session content...]
```

---

## Usage Tips

1. **Start with README and CLAUDE.md** — Every project needs these
2. **Add CHANGELOG early** — Track changes from the start
3. **Add SECURITY.md if public** — Encourages responsible disclosure
4. **Add PRIVACY.md for user-facing apps** — Builds trust
5. **Keep templates updated** — Add sections as you discover patterns

---

*Copy these templates into your projects and customize as needed.*
