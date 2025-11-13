# Quick Start Guide - Xcode Project Organization

This guide helps you quickly set up the organized folder structure for your Xcode projects.

## Option 1: Automated Setup (Recommended)

### For New Projects

```bash
# Navigate to where you want to create the project
cd ~/XcodeProjects

# Run the script
./create-project-structure.sh MyNewProject

# Or with full folder set (includes marketing, design, tests, etc.)
./create-project-structure.sh MyNewProject --full
```

### For Existing Projects

```bash
# Navigate to your existing project
cd ~/XcodeProjects/MyExistingProject

# Run the script (it won't overwrite existing files)
/path/to/create-project-structure.sh

# Move your Xcode project
git mv MyProject.xcodeproj 1_Xcode/
git mv MyProject/ 1_Xcode/

# Commit the reorganization
git add -A
git commit -m "refactor: Reorganize project structure"
git push
```

## Option 2: Manual Setup

### Basic Structure (Minimal)

```bash
mkdir -p 1_Xcode
mkdir -p 2_LLM-Docs/SessionLogs
mkdir -p 3_ScreenshotsCoding/{Bugs,UI-Issues}
mkdir -p 4_AppIcons
mkdir -p 7_EXPORT/Releases
```

### Full Structure (Complete)

```bash
mkdir -p 1_Xcode
mkdir -p 2_LLM-Docs/SessionLogs
mkdir -p 3_ScreenshotsCoding/{Bugs,UI-Issues,Crashes,Performance}
mkdir -p 4_AppIcons/variations
mkdir -p 5_Marketing/{Screenshots,Descriptions,Videos}
mkdir -p 6_Design/{Mockups,Prototypes,ColorSchemes}
mkdir -p 7_EXPORT/{Releases,Beta,Archives}
mkdir -p 8_forGitHub
mkdir -p 9_Tests/{TestPlans,TestResults,Coverage}
mkdir -p 10_Dependencies/{Frameworks,Licenses}
```

## What Goes Where?

| Folder | Description | Examples |
|--------|-------------|----------|
| **1_Xcode/** | Xcode project & source | `*.xcodeproj`, `*.swift`, `Assets.xcassets` |
| **2_LLM-Docs/** | AI sessions & planning | `SessionLog-2025-11-13.md`, `Roadmap.md` |
| **3_ScreenshotsCoding/** | Debug screenshots | Bug screenshots, error messages |
| **4_AppIcons/** | App icons & branding | `app-icon.png`, design source files |
| **5_Marketing/** | App Store materials | Screenshots, descriptions, videos |
| **6_Design/** | UI/UX design files | Figma/Sketch files, mockups |
| **7_EXPORT/** | Built apps & releases | `.dmg`, `.app`, `.ipa` files |
| **8_forGitHub/** | GitHub assets | Social preview, issue templates |
| **9_Tests/** | Testing artifacts | Test plans, results, coverage |
| **10_Dependencies/** | External libraries | Frameworks, licenses |

## .gitignore Setup

Copy this to your `.gitignore`:

```gitignore
# Xcode
xcuserdata/
build/
DerivedData/
*.xcscmblueprint
.build/
*.DS_Store

# Organized folders (local only)
2_LLM-Docs/
3_ScreenshotsCoding/
4_AppIcons/
5_Marketing/
6_Design/
7_EXPORT/
9_Tests/
10_Dependencies/
```

## Daily Workflow

### Starting Work
1. Open Xcode project: `1_Xcode/MyProject.xcodeproj`
2. Code normally - Xcode follows all paths dynamically

### Debugging
1. Take screenshot of bug/error
2. Save to `3_ScreenshotsCoding/Bugs/`
3. Share with Claude or team

### Working with LLMs
1. Export conversation to `2_LLM-Docs/SessionLogs/`
2. Name it: `2025-11-13_feature-name.md`
3. Update `2_LLM-Docs/Roadmap.md` with plans

### Building Releases
1. Archive in Xcode (Product → Archive)
2. Export as `.app` or `.dmg`
3. Copy to `7_EXPORT/Releases/v1.0/`
4. Create GitHub release from there

## Tips

### ✅ DO
- Keep folder names consistent across projects
- Update `2_LLM-Docs/Roadmap.md` regularly
- Backup `7_EXPORT/` folder (has your releases)
- Use the script for new projects (consistency!)

### ❌ DON'T
- Don't rename numbered folders (breaks .gitignore)
- Don't commit large files (images, videos, builds)
- Don't put Xcode project in root after reorganizing
- Don't forget to update README.md references

## Troubleshooting

### "Xcode can't find my files"
- Make sure your `.xcodeproj` and source folder are both in `1_Xcode/`
- Xcode uses relative paths - keep the structure intact

### "Git shows tons of deletions"
- Use `git mv` instead of regular `mv`
- Git will track it as a rename, preserving history

### "Images not showing in README"
- Update README.md image paths:
  - Old: `![Icon](app-icon.png)`
  - New: `![Icon](4_AppIcons/app-icon.png)`

### "I need to add more folders"
- Add to numbered sequence: `11_Legal/`, `12_Analytics/`
- Add to `.gitignore` if it should be local-only
- Update `PROJECT-STRUCTURE-TEMPLATE.md`

## Examples

### New Project from Scratch
```bash
# Create structure
./create-project-structure.sh AwesomeApp --full

# Create Xcode project (in Xcode)
# File → New → Project → Save to: 1_Xcode/

# Initialize git
git init
git add -A
git commit -m "Initial commit with organized structure"
```

### Migrate Existing Project
```bash
# Backup first!
cp -R ~/XcodeProjects/OldProject ~/XcodeProjects/OldProject-backup

# Run script in project directory
cd ~/XcodeProjects/OldProject
./create-project-structure.sh

# Move files
git mv OldProject.xcodeproj 1_Xcode/
git mv OldProject/ 1_Xcode/
git mv screenshots/ 2_LLM-Docs/
git mv *.dmg 7_EXPORT/Releases/

# Commit
git add -A
git commit -m "refactor: Reorganize project structure"
git push
```

## File Organization Checklist

- [ ] Created folder structure (script or manual)
- [ ] Moved Xcode project to `1_Xcode/`
- [ ] Updated `.gitignore`
- [ ] Updated `README.md` image/file references
- [ ] Tested: Open Xcode project from `1_Xcode/` - builds successfully
- [ ] Committed and pushed changes
- [ ] Moved old screenshots to `2_LLM-Docs/Screenshots/`
- [ ] Moved old releases to `7_EXPORT/Releases/`
- [ ] Created `2_LLM-Docs/Roadmap.md` with future plans

## Resources

- [PROJECT-STRUCTURE-TEMPLATE.md](PROJECT-STRUCTURE-TEMPLATE.md) - Full documentation
- [create-project-structure.sh](create-project-structure.sh) - Setup script
- [.gitignore](.gitignore) - Git ignore template

---

**Need help?** Check `PROJECT-STRUCTURE-TEMPLATE.md` for detailed explanations.

**Template Version:** 1.0 | **Last Updated:** 2025-11-13
