#!/usr/bin/env python3
"""
Create App Store compatible screenshots by resizing to 2880x1800 with letterboxing
"""

import subprocess
import os
import shutil

TARGET_WIDTH = 2880
TARGET_HEIGHT = 1800
OUTPUT_DIR = "appstore-screenshots"

# Create output directory
os.makedirs(OUTPUT_DIR, exist_ok=True)

screenshots = [
    ("github/screenshots/MainWindow-1.png", "01-main-window.png"),
    ("github/screenshots/Popover-large.png", "02-popover.png"),
    ("github/screenshots/MainWindow-DevicesExpanded.png", "03-devices-detail.png"),
    ("github/screenshots/MainWindow-ServicesExpanded.png", "04-folders-detail.png"),
    ("github/screenshots/MainWindow-Activity.png", "05-activity-charts.png"),
    ("github/screenshots/Settings-1.png", "06-settings-general.png"),
    ("github/screenshots/Settings-2.png", "07-settings-sync.png"),
    ("github/screenshots/Settings-3.png", "08-settings-notifications.png"),
    ("github/screenshots/DemoMode-QuickScenarios.png", "09-demo-mode.png"),
]

print(f"Creating App Store screenshots ({TARGET_WIDTH}x{TARGET_HEIGHT})...\n")

for src, dst in screenshots:
    if not os.path.exists(src):
        print(f"⚠️  Skipping {src} (not found)")
        continue

    output_path = os.path.join(OUTPUT_DIR, dst)

    # Use sips to resize with letterboxing (fit mode)
    # This will scale the image to fit within the bounds while maintaining aspect ratio
    cmd = [
        'sips',
        '-z', str(TARGET_HEIGHT), str(TARGET_WIDTH),
        src,
        '--out', output_path
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"✓ Created: {output_path}")
    else:
        print(f"✗ Failed: {dst}")
        if result.stderr:
            print(f"  Error: {result.stderr.strip()}")

print(f"\n✅ Done! Screenshots created in: {OUTPUT_DIR}/")
print("\nFiles created:")
subprocess.run(['ls', '-lh', OUTPUT_DIR])
