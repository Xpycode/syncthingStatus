#!/bin/bash

# Create App Store screenshots with proper aspect ratio preservation
# Target: 2880x1800 (16:10 ratio)

TARGET_WIDTH=2880
TARGET_HEIGHT=1800
OUTPUT_DIR="appstore-screenshots"
BG_COLOR="F5F5F7"  # Light gray background

echo "Creating App Store screenshots with aspect ratio preservation..."
echo "Target: ${TARGET_WIDTH}x${TARGET_HEIGHT}"
echo ""

create_screenshot() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        echo "⚠️  Skipping: $src (not found)"
        return
    fi

    local output="$OUTPUT_DIR/$dst"
    local temp="${output}.temp.png"

    # Get source dimensions
    local src_width=$(sips -g pixelWidth "$src" 2>/dev/null | tail -1 | awk '{print $2}')
    local src_height=$(sips -g pixelHeight "$src" 2>/dev/null | tail -1 | awk '{print $2}')

    echo "Processing: $(basename "$src")"
    echo "  Source: ${src_width} x ${src_height}"

    # Calculate scaling factor to fit within target (with 5% margin)
    local scale_w=$(awk "BEGIN {printf \"%.4f\", ($TARGET_WIDTH * 0.95) / $src_width}")
    local scale_h=$(awk "BEGIN {printf \"%.4f\", ($TARGET_HEIGHT * 0.95) / $src_height}")

    # Use smaller scale to ensure it fits
    local scale=$scale_w
    if (( $(awk "BEGIN {print ($scale_h < $scale_w)}") )); then
        scale=$scale_h
    fi

    # Calculate new dimensions
    local new_width=$(awk "BEGIN {printf \"%.0f\", $src_width * $scale}")
    local new_height=$(awk "BEGIN {printf \"%.0f\", $src_height * $scale}")

    echo "  Scaled: ${new_width} x ${new_height}"

    # Step 1: Resize to fit within bounds
    sips -z "$new_height" "$new_width" "$src" --out "$temp" >/dev/null 2>&1

    # Step 2: Pad to exact dimensions with background
    sips --padToHeightWidth "$TARGET_HEIGHT" "$TARGET_WIDTH" \
         --padColor "$BG_COLOR" \
         "$temp" --out "$output" >/dev/null 2>&1

    # Clean up
    rm -f "$temp"

    # Verify final dimensions
    local final_w=$(sips -g pixelWidth "$output" 2>/dev/null | tail -1 | awk '{print $2}')
    local final_h=$(sips -g pixelHeight "$output" 2>/dev/null | tail -1 | awk '{print $2}')

    echo "  Final: ${final_w} x ${final_h}"

    if [ "$final_w" = "$TARGET_WIDTH" ] && [ "$final_h" = "$TARGET_HEIGHT" ]; then
        echo "  ✓ Created: $dst"
    else
        echo "  ✗ Failed: dimensions incorrect"
    fi
    echo ""
}

# Create screenshots
create_screenshot "github/screenshots/MainWindow-1.png" "01-main-window.png"
create_screenshot "github/screenshots/Popover-large.png" "02-popover.png"
create_screenshot "github/screenshots/MainWindow-DevicesExpanded.png" "03-devices-detail.png"
create_screenshot "github/screenshots/MainWindow-ServicesExpanded.png" "04-folders-detail.png"
create_screenshot "github/screenshots/MainWindow-Activity.png" "05-activity-charts.png"
create_screenshot "github/screenshots/Settings-1.png" "06-settings-general.png"
create_screenshot "github/screenshots/Settings-2.png" "07-settings-sync.png"
create_screenshot "github/screenshots/Settings-3.png" "08-settings-notifications.png"
create_screenshot "github/screenshots/DemoMode-QuickScenarios.png" "09-demo-mode.png"

echo "✅ All screenshots created!"
echo ""
ls -lh "$OUTPUT_DIR"/*.png
