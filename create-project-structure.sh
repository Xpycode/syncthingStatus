#!/bin/bash

# Xcode Project Structure Generator
# Creates a comprehensive organizational structure for Xcode projects
# Usage: ./create-project-structure.sh [ProjectName] [--full]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default mode: basic (only essential folders)
MODE="basic"

# Parse arguments
PROJECT_NAME=""
for arg in "$@"; do
    case $arg in
        --full)
            MODE="full"
            shift
            ;;
        *)
            if [ -z "$PROJECT_NAME" ]; then
                PROJECT_NAME="$arg"
            fi
            ;;
    esac
done

# If no project name provided, use current directory name
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$PWD")
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Xcode Project Structure Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📁 Project Name: ${GREEN}$PROJECT_NAME${NC}"
echo -e "🔧 Mode: ${YELLOW}$MODE${NC}"
echo ""

# Function to create directory and print status
create_dir() {
    local dir=$1
    local description=$2

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✓${NC} Created: ${BLUE}$dir${NC} - $description"
    else
        echo -e "${YELLOW}○${NC} Exists:  ${BLUE}$dir${NC} - $description"
    fi
}

# Function to create a placeholder README in a directory
create_readme() {
    local dir=$1
    local title=$2
    local description=$3

    if [ ! -f "$dir/README.md" ]; then
        cat > "$dir/README.md" << EOF
# $title

$description

## Contents

(Add notes about what goes in this folder)

---
Created: $(date +"%Y-%m-%d")
EOF
        echo -e "   ${GREEN}+${NC} Added README.md"
    fi
}

echo -e "${YELLOW}Creating folder structure...${NC}"
echo ""

# Essential folders (always created)
echo -e "${BLUE}Essential Folders:${NC}"
create_dir "1_Xcode" "Xcode project & source code (TRACKED)"

create_dir "2_LLM-Docs" "LLM sessions & planning (IGNORED)"
create_dir "2_LLM-Docs/SessionLogs" "Conversation logs with AI"
create_readme "2_LLM-Docs" "LLM Documentation" "This folder contains AI interaction logs, planning documents, and analysis."

create_dir "3_ScreenshotsCoding" "Problem analysis screenshots (IGNORED)"
create_dir "3_ScreenshotsCoding/Bugs" "Bug screenshots"
create_dir "3_ScreenshotsCoding/UI-Issues" "UI/UX issues"
create_readme "3_ScreenshotsCoding" "Coding Screenshots" "Screenshots for debugging and sharing with LLMs or team members."

create_dir "4_AppIcons" "Icon design & assets (IGNORED)"
create_readme "4_AppIcons" "App Icons & Branding" "App icons, logo files, and branding assets."

create_dir "7_EXPORT" "Distribution files & builds (IGNORED)"
create_dir "7_EXPORT/Releases" "Released versions"
create_readme "7_EXPORT" "Distribution Files" "Built applications, DMGs, and distribution packages."

echo ""

# Full mode - additional folders
if [ "$MODE" == "full" ]; then
    echo -e "${BLUE}Additional Folders (Full Mode):${NC}"

    create_dir "5_Marketing" "Marketing materials (IGNORED)"
    create_dir "5_Marketing/Screenshots" "App Store screenshots"
    create_dir "5_Marketing/Descriptions" "App Store descriptions"
    create_readme "5_Marketing" "Marketing Materials" "App Store screenshots, descriptions, and promotional content."

    create_dir "6_Design" "Design assets & mockups (IGNORED)"
    create_dir "6_Design/Mockups" "UI mockups"
    create_dir "6_Design/Prototypes" "Interactive prototypes"
    create_readme "6_Design" "Design Assets" "UI/UX design files, mockups, and prototypes."

    create_dir "8_forGitHub" "GitHub-specific files (TRACKED)"
    create_readme "8_forGitHub" "GitHub Assets" "Files for GitHub repository display (social previews, templates)."

    create_dir "9_Tests" "Test artifacts (OPTIONAL TRACK)"
    create_dir "9_Tests/TestPlans" "Manual test plans"
    create_readme "9_Tests" "Test Artifacts" "Testing documentation, results, and coverage reports."

    create_dir "10_Dependencies" "External dependencies (IGNORED)"
    create_readme "10_Dependencies" "Dependencies" "Third-party frameworks, licenses, and documentation."

    echo ""
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    echo -e "${BLUE}Creating .gitignore...${NC}"
    cat > .gitignore << 'EOF'
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
9_Tests/
10_Dependencies/
EOF
    echo -e "${GREEN}✓${NC} Created .gitignore"
else
    echo -e "${YELLOW}○${NC} .gitignore already exists (not modified)"
fi

echo ""

# Create a basic README if it doesn't exist
if [ ! -f "README.md" ]; then
    echo -e "${BLUE}Creating README.md...${NC}"
    cat > README.md << EOF
# $PROJECT_NAME

A brief description of your project.

## Features

- Feature 1
- Feature 2
- Feature 3

## Requirements

- macOS 15.5 or later
- Xcode 16.4+

## Installation

### Build from Source

1. Clone this repository:
   \`\`\`bash
   git clone https://github.com/yourusername/$PROJECT_NAME.git
   cd $PROJECT_NAME
   \`\`\`

2. Open \`1_Xcode/$PROJECT_NAME.xcodeproj\` in Xcode

3. Build and run (⌘R)

## Project Structure

This project uses an organized folder structure:

- \`1_Xcode/\` - Xcode project and source code
- \`2_LLM-Docs/\` - LLM interaction logs and planning
- \`3_ScreenshotsCoding/\` - Debug screenshots
- \`4_AppIcons/\` - App icons and branding
- \`7_EXPORT/\` - Built applications and releases

See [PROJECT-STRUCTURE-TEMPLATE.md](PROJECT-STRUCTURE-TEMPLATE.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Created: $(date +"%Y-%m-%d")
EOF
    echo -e "${GREEN}✓${NC} Created README.md"
else
    echo -e "${YELLOW}○${NC} README.md already exists (not modified)"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Project structure created successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Move your Xcode project to: ${GREEN}1_Xcode/$PROJECT_NAME.xcodeproj${NC}"
echo "2. Open project from: ${GREEN}1_Xcode/$PROJECT_NAME.xcodeproj${NC}"
echo "3. Review and customize: ${GREEN}README.md${NC}"
echo "4. Review structure guide: ${GREEN}PROJECT-STRUCTURE-TEMPLATE.md${NC}"
echo ""
echo -e "${YELLOW}Tip:${NC} Run with ${GREEN}--full${NC} flag to create additional folders for marketing, design, and testing."
echo ""
