# Xcode Project Organization Template

A comprehensive, scalable folder structure for organizing Xcode projects with clear separation between source code, documentation, assets, and distribution files.

## Quick Start

Use the included script to automatically create this structure:

```bash
./create-project-structure.sh YourProjectName
```

Or manually create the folders listed below.

## Folder Structure

```
ProjectName/
├── 1_Xcode/                    # Xcode project & source code (TRACKED in git)
├── 2_LLM-Docs/                 # LLM sessions & planning (IGNORED)
├── 3_ScreenshotsCoding/        # Problem analysis screenshots (IGNORED)
├── 4_AppIcons/                 # Icon design & assets (IGNORED)
├── 5_Marketing/                # Marketing materials (IGNORED)
├── 6_Design/                   # Design assets & mockups (IGNORED)
├── 7_EXPORT/                   # Distribution files & builds (IGNORED)
├── 8_forGitHub/                # Deprecated - use github/ instead (IGNORED)
├── 9_Tests/                    # Test artifacts (OPTIONAL TRACK)
├── 10_Dependencies/            # External dependencies (IGNORED)
├── github/                     # GitHub display files (TRACKED)
│   ├── screenshots/            # Screenshots for README
│   ├── icons/                  # App icons and social preview
│   └── releases/               # DMG files for distribution (optional)
├── docs/                       # GitHub Pages (TRACKED, must be in root)
├── .github/                    # GitHub config (TRACKED)
├── README.md                   # Project README (TRACKED)
├── LICENSE                     # License file (TRACKED)
├── CHANGELOG.md                # Version history (TRACKED, optional)
└── .gitignore                  # Git ignore rules (TRACKED)
```

## Folder Descriptions

### 🔵 1_Xcode/ - Source Code (TRACKED)
**What:** Your Xcode project and all source code
**Contains:**
- `ProjectName.xcodeproj` - Xcode project file
- `ProjectName/` - Source code folder
  - Swift files
  - SwiftUI views
  - Models & ViewModels
  - Assets.xcassets
  - Info.plist
  - Entitlements

**Why tracked:** This is your actual application code that needs version control.

---

### 🔴 2_LLM-Docs/ - LLM Documentation (IGNORED)
**What:** AI/LLM interaction logs, planning, and analysis
**Contains:**
- `SessionLogs/` - Claude/ChatGPT conversation exports
  - `2025-11-13_feature-implementation.md`
  - `2025-11-14_bug-analysis.md`
- `Roadmap.md` - Future features & planning
- `Architecture.md` - System design notes
- `OptimizationAnalysis.md` - Performance improvement notes
- `Screenshots/` - Historical screenshots by version
  - `v1.0/`
  - `v1.1/`
  - `v1.2/`

**Why ignored:** Personal notes and LLM interactions are not part of the codebase.

---

### 🔴 3_ScreenshotsCoding/ - Problem Analysis (IGNORED)
**What:** Screenshots for debugging and sharing with LLMs
**Contains:**
- `Bugs/` - Bug screenshots and error messages
- `UI-Issues/` - UI/UX problems to discuss
- `Crashes/` - Crash reports and stack traces
- `Performance/` - Performance profiling screenshots
- `Console/` - Console output screenshots

**Why ignored:** Temporary debugging materials, not needed in git.

---

### 🔴 4_AppIcons/ - Icon Assets (IGNORED)
**What:** App icons and branding assets
**Contains:**
- `icon-source.sketch` - Original design files
- `icon-source.figma` - Figma design files
- `app-icon.png` - Final app icon (various sizes)
- `repo-social-preview.png` - GitHub social preview image
- `variations/` - Alternative icon designs

**Why ignored:** Design files can be large; keep source files local, use final assets in git.

---

### 🔴 5_Marketing/ - Marketing Materials (IGNORED)
**What:** App Store and promotional materials
**Contains:**
- `Screenshots/` - App Store screenshots
  - `iPhone/`
  - `iPad/`
  - `Mac/`
- `Descriptions/` - App Store text
  - `short-description.txt` (80 chars)
  - `full-description.txt` (4000 chars)
  - `keywords.txt`
  - `whats-new.txt` - Release notes
- `Videos/` - App preview videos and demos
- `Press/` - Press kit materials

**Why ignored:** Marketing assets are typically large and not part of source code.

---

### 🔴 6_Design/ - Design Assets (IGNORED)
**What:** UI/UX design files and mockups
**Contains:**
- `Mockups/` - UI mockups and wireframes
- `Prototypes/` - Interactive prototypes (Figma, Sketch)
- `ColorSchemes/` - Color palettes and brand guidelines
- `Typography/` - Font choices and type samples
- `Components/` - Reusable design components

**Why ignored:** Design source files are often large and updated separately from code.

---

### 🔴 7_EXPORT/ - Distribution Files (IGNORED)
**What:** Built applications and distribution packages
**Contains:**
- `Releases/` - Released versions
  - `v1.0/`
    - `ProjectName-v1.0.dmg`
    - `ProjectName-v1.0.app`
    - `Release-Notes-v1.0.md`
  - `v1.1/`
  - `v1.2/`
- `Beta/` - Beta test builds
- `TestFlight/` - TestFlight builds (iOS)
- `Archives/` - Xcode archives (`.xcarchive`)
- `Notarization/` - Notarization receipts (macOS)

**Why ignored:** Binary files are large and should be distributed via GitHub Releases or other platforms.

---

### 🔵 github/ - GitHub Display Files (TRACKED)
**What:** All files needed for GitHub repository display
**Contains:**
- `screenshots/` - Screenshots for README (all app screenshots)
- `icons/` - App icons and branding
  - `app-icon.png` - Main app icon for README
  - `repo-social-preview.png` - GitHub social preview (1280x640)
- `releases/` - DMG distribution files (optional)
  - `ProjectName-v1.0.dmg`
  - `ProjectName-v1.1.dmg`
  - `ProjectName-v1.2.dmg`

**Why tracked:** These files are displayed on GitHub - screenshots in README, icons for branding, and optionally DMG files for easy access (though GitHub Releases is recommended for large binaries).

**Note:** This replaces the old `8_forGitHub/` folder and scattered `screenshots/` + `app-icon.png` in root. Everything GitHub needs is now in one organized location.

---

### 🟡 9_Tests/ - Test Artifacts (OPTIONAL TRACK)
**What:** Testing documentation and results
**Contains:**
- `TestPlans/` - Manual test plans and checklists
- `TestResults/` - Test output screenshots
- `Coverage/` - Code coverage reports
- `Performance/` - Performance benchmarks
- `UnitTests/` - Unit test documentation (if not in Xcode)

**Why optional:** Depends on team preference; some track test plans, others don't.

---

### 🔴 10_Dependencies/ - External Dependencies (IGNORED)
**What:** Third-party frameworks and documentation
**Contains:**
- `Frameworks/` - Local copies of frameworks
- `Licenses/` - Dependency licenses
- `Documentation/` - External library documentation
- `SPM-Packages/` - Swift Package Manager packages (if not using default location)

**Why ignored:** Dependencies managed by SPM/CocoaPods are typically ignored; keep documentation local.

---

### 🔵 docs/ - GitHub Pages (TRACKED, ROOT REQUIRED)
**What:** GitHub Pages website (if used)
**Contains:**
- `index.html` - Main website page
- `css/` - Stylesheets
- `images/` - Website images
- `js/` - JavaScript files

**Why in root:** GitHub Pages requires `docs/` folder to be in the repository root.

---

### 🔵 .github/ - GitHub Configuration (TRACKED)
**What:** GitHub-specific automation and templates
**Contains:**
- `ISSUE_TEMPLATE/` - Issue templates
  - `bug_report.md`
  - `feature_request.md`
- `workflows/` - GitHub Actions CI/CD
- `FUNDING.yml` - Sponsorship information
- `CODEOWNERS` - Code ownership assignments

**Why tracked:** Essential for GitHub repository automation.

---

## .gitignore Template

```gitignore
# Xcode
xcuserdata/
*.xcscmblueprint
*.xccheckout
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
*.hmap
*.ipa
*.dSYM.zip
*.dSYM
timeline.xctimeline
playground.xcworkspace
.build/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Organized folders (local only)
2_LLM-Docs/
3_ScreenshotsCoding/
4_AppIcons/
5_Marketing/
6_Design/
7_EXPORT/
8_forGitHub/
9_Tests/
10_Dependencies/

# Optional: Uncomment if you want to ignore specific files
# 1_Xcode/*/xcuserdata/
# *.xcworkspace/xcuserdata/
```

## Usage Guide

### For New Projects

1. Create your Xcode project normally
2. Run the setup script: `./create-project-structure.sh YourProjectName`
3. Move your `.xcodeproj` into `1_Xcode/`
4. Open from `1_Xcode/YourProjectName.xcodeproj`

### For Existing Projects

1. Create the numbered folders manually or with the script
2. Use `git mv` to move files:
   ```bash
   git mv YourProject.xcodeproj 1_Xcode/
   git mv YourProject/ 1_Xcode/
   ```
3. Update any file references in README if needed
4. Update .gitignore with the template above

### Daily Workflow

- **Coding:** Open project from `1_Xcode/ProjectName.xcodeproj`
- **Debugging:** Save screenshots to `3_ScreenshotsCoding/`
- **LLM Sessions:** Export conversations to `2_LLM-Docs/SessionLogs/`
- **Releases:** Copy builds to `7_EXPORT/Releases/vX.X/`
- **Design:** Keep design files in `6_Design/`

## Benefits

✅ **Clean Separation** - Source code vs. documentation vs. distribution
✅ **Git-Friendly** - Only essential files tracked
✅ **Xcode Compatible** - Works seamlessly with Xcode
✅ **Scalable** - Easy to add more organizational folders
✅ **Consistent** - Same structure across all projects
✅ **LLM-Friendly** - Organized documentation for AI assistance
✅ **Professional** - Follows software engineering best practices

## Tips

1. **Consistency:** Use the same structure for all projects
2. **README References:** Update README.md to reference organized folders (e.g., `4_AppIcons/app-icon.png`)
3. **Backup:** Regularly backup ignored folders (especially `7_EXPORT/` and `6_Design/`)
4. **Automation:** Use the script to maintain consistency across projects
5. **Documentation:** Keep `2_LLM-Docs/Roadmap.md` updated with your plans

## Optional Additions

### For Commercial Apps
- `11_Legal/` - Privacy policies, terms, EULA
- `12_Analytics/` - Usage reports, metrics

### For Multi-Language Apps
- `13_Localization/` - Translation files, region-specific assets

### For Team Projects
- `14_Team/` - Meeting notes, team documentation

---

**Template Version:** 1.0
**Last Updated:** 2025-11-13
**Maintained by:** [Your Name]
