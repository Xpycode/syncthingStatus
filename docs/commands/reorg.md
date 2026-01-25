# Reorganize Project Folder

Reorganize this project to use the standard numbered folder structure.

## Step 1: Scan Current State

Look for:
- `.xcodeproj` or `.xcworkspace` files (Xcode project)
- Swift/source folders (named after the app)
- `Tests` or `UITests` folders
- `.afdesign`, `.af`, `.icon` files (design assets)
- `*Exports/` folders (icon exports)
- `Screenshots/` or loose `.png` files
- `APP/` folder or `.dmg` files (exports)
- Loose `.md` files (documentation)

## Step 2: Show Migration Plan

Present what you found and where it would go:

```
Found:
  - MyApp.xcodeproj → 01_Project/
  - MyApp/ (source) → 01_Project/
  - MyAppTests/ → 01_Project/
  - MyApp-Icon.afdesign → 02_Design/
  - MyApp-Icon Exports/ → 02_Design/Exports/
  - screenshots/ → 03_Screenshots/
  - APP/ → 04_Exports/
  - *.md files → docs/ (review individually)

This will create:
  01_Project/
  02_Design/Exports/
  03_Screenshots/
  04_Exports/
  docs/sessions/
```

## Step 3: Ask for Confirmation

> "Ready to reorganize? This will move files as shown above.
> Note: You may need to update the .xcodeproj paths after moving.
>
> Proceed? (yes/no)"

## Step 4: Execute

If confirmed:
1. Create the numbered folders
2. Move files as planned
3. Create .gitignore if missing
4. Set up docs/ with Directions if not present
5. Report what was done

## Step 5: Post-Migration

Remind user:
> "Done! Next steps:
> 1. Open the .xcodeproj and verify paths are correct
> 2. If paths are broken, you may need to re-add files in Xcode
> 3. Run `git status` to review changes before committing"

## Reference

See `13_folder-structure.md` in Directions for the full structure specification.
