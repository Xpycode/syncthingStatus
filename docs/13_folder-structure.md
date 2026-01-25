# Project Folder Structure

> **Trigger:** New project setup, "where should I put", folder organization, gitignore

A consistent structure keeps projects clean, GitHub-friendly, and easy to navigate.

---

## macOS / iOS Projects

```
MyApp/                              ← Project root (GitHub repo)
│
├── 01_Project/                     ← ALL XCODE STUFF
│   ├── MyApp/                      ← Source code
│   │   ├── Views/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Resources/
│   │   └── Assets.xcassets/
│   ├── MyApp.xcodeproj/
│   ├── MyAppTests/                 ← Unit tests
│   └── MyAppUITests/               ← UI tests
│
├── 02_Design/                      ← Design source files
│   ├── MyApp-Icon.afdesign         ← Affinity Designer source
│   ├── MyApp-Icon.icon             ← Folder icon project
│   └── Exports/                    ← Exported PNGs
│       └── AppIcon.appiconset/
│
├── 03_Screenshots/                 ← App Store / promotional
│   ├── 01-MainView.png
│   ├── 02-Settings.png
│   └── ...
│
├── 04_Exports/                     ← Builds, DMGs, IPAs (gitignored)
│   ├── MyApp-1.0.dmg
│   └── MyApp 1.0/                  ← Unzipped app for testing
│
├── docs/                           ← Directions documentation
│   ├── 00_base.md
│   ├── PROJECT_STATE.md
│   └── sessions/
│
├── old-docs/                       ← Migrated docs (if any)
│
├── .git/
├── .gitignore
├── CLAUDE.md                       ← Project-specific Claude context
├── README.md
├── LICENSE
└── CHANGELOG.md                    ← Optional
```

### iOS with Extensions

```
MyApp/
├── 01_Project/
│   ├── MyApp/                      ← Main iOS app
│   ├── MyAppWidget/                ← Widget extension
│   ├── MyApp Watch Watch App/      ← watchOS companion
│   ├── MyAppTests/
│   ├── MyAppUITests/
│   └── MyApp.xcodeproj/
│
├── 02_Design/
├── 03_Screenshots/
├── 04_Exports/
└── docs/
```

---

## Web Projects

```
MyWebsite/                          ← Project root
│
├── 01_Source/                      ← Source code
│   ├── components/
│   ├── pages/
│   └── styles/
│
├── 02_Frontend/                    ← Built site / app
│   ├── index.html
│   ├── css/
│   ├── js/
│   └── assets/
│
├── 03_Scripts/                     ← Build/utility scripts
│   ├── build.py
│   └── deploy.sh
│
├── 04_Data/                        ← Data files (JSON, CSV)
│   ├── content.json
│   └── backup/
│
├── docs/                           ← Directions
│
├── venv/                           ← Python virtual env (gitignored)
├── node_modules/                   ← Node deps (gitignored)
│
├── .gitignore
├── README.md
├── requirements.txt                ← Python deps
└── package.json                    ← Node deps
```

---

## Folder Numbering Logic

| Number | Purpose | Examples |
|--------|---------|----------|
| 01_ | Source/Project | Xcode project, source code |
| 02_ | Design | Affinity files, icons, mockups |
| 03_ | Screenshots | App Store, promotional |
| 04_ | Exports/Output | DMGs, IPAs, built apps |
| docs/ | Documentation | Directions (has own numbering) |

Numbers keep folders sorted logically in Finder and terminals.

---

## What Goes Where

| Item | Location | Git? |
|------|----------|------|
| Source code | `01_Project/MyApp/` | Yes |
| Xcode project | `01_Project/MyApp.xcodeproj/` | Yes (mostly) |
| Design source (.af, .afdesign) | `02_Design/` | Optional |
| Icon exports | `02_Design/Exports/` | No (generated) |
| Screenshots | `03_Screenshots/` | Yes (if for App Store) |
| Built apps, DMGs | `04_Exports/` | No |
| Documentation | `docs/` | Yes |
| Planning/review MDs | `docs/` or root | No (temporary) |
| Crash logs (.ips) | Delete | No |
| Trace files (.trace) | Delete | No |
| Python venv | `venv/` | No |
| Node modules | `node_modules/` | No |

---

## Naming Conventions

### Folders
- Numbered: `01_Project/`, `02_Design/`
- Lowercase for non-numbered: `docs/`, `venv/`

### Files
- Screenshots: `01-MainView.png`, `02-Settings.png` (numbered for order)
- Design files: `MyApp-Icon.afdesign` (project name prefix)
- Exports: `MyApp-1.0.dmg` (with version)

---

## Comprehensive .gitignore

```gitignore
# === macOS ===
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# === Xcode ===
*.xcodeproj/project.xcworkspace/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
xcuserdata/
DerivedData/
build/
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
*.xcuserstate
*.xcscmblueprint
*.xccheckout

# === Swift Package Manager ===
.swiftpm/
Packages/
Package.pins
Package.resolved

# === CocoaPods / Carthage ===
Pods/
Carthage/Build/

# === Build Outputs ===
04_Exports/
*.dmg
*.app
*.o
*.a

# === Design Assets (Optional - uncomment if not tracking) ===
# 02_Design/
# *.afdesign
# *.af
# *.icon
# *Exports/

# === Debug / Profiling ===
*.ips
*.trace
*.crash
Instruments/

# === Temporary / Planning Files ===
*PLAN*.md
*CHECKLIST*.md
code-review*.md
SESSION-LOG*.md
fix-plan*.md
*-addition.md
TODO-*.md

# === Claude / AI Tools ===
.claude/
.serena/
.aider*
.gemini*

# === Python ===
venv/
__pycache__/
*.pyc
*.pyo
.env

# === Node ===
node_modules/
npm-debug.log
yarn-error.log

# === IDE ===
.idea/
.vscode/
*.swp
*.swo
*~

# === Secrets ===
*.pem
*.key
.env.local
.env.*.local
credentials.json
secrets.json
```

---

## Cleanup Checklist

When a project gets messy:

1. **Move Xcode stuff** into `01_Project/`
2. **Move design files** to `02_Design/`
3. **Move screenshots** to `03_Screenshots/`
4. **Move builds** to `04_Exports/`
5. **Move loose MDs** to `docs/` or delete if obsolete
6. **Delete debug artifacts** (.ips, .trace, crash logs)
7. **Update .gitignore** if new patterns emerged
8. **Run `git status`** to verify nothing unwanted is tracked

---

## Quick Setup Script

For new projects:

```bash
# Create folder structure
mkdir -p 01_Project 02_Design/Exports 03_Screenshots 04_Exports docs/sessions

# Create minimal .gitignore
cat > .gitignore << 'EOF'
.DS_Store
DerivedData/
build/
04_Exports/
*.dmg
*.ips
*.trace
venv/
node_modules/
.claude/
.serena/
xcuserdata/
*.xcuserstate
EOF

# Create placeholder files
touch docs/PROJECT_STATE.md
touch docs/decisions.md
echo "# Session Index" > docs/sessions/_index.md

echo "Created: 01_Project/ 02_Design/ 03_Screenshots/ 04_Exports/ docs/"
```

---

## Migrating Existing Projects

If you have an existing messy project:

```bash
# Create new structure
mkdir -p 01_Project 02_Design/Exports 03_Screenshots 04_Exports

# Move Xcode stuff (adjust names as needed)
mv MyApp 01_Project/
mv MyApp.xcodeproj 01_Project/
mv MyAppTests 01_Project/

# Move design files
mv *.afdesign 02_Design/
mv *.af 02_Design/
mv *.icon 02_Design/
mv *Exports/ 02_Design/

# Move screenshots
mv Screenshots/* 03_Screenshots/
mv *.png 03_Screenshots/  # be careful with this one

# Move exports
mv APP/* 04_Exports/
mv *.dmg 04_Exports/
```

Then update your `.xcodeproj` paths if needed (or recreate the project).

---

*Keep it clean. Future you will thank present you.*
