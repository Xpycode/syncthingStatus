#!/bin/bash

# Create App Store compatible screenshots with 16:10 aspect ratio
# Target size: 2880 x 1800px (highest quality option)

TARGET_WIDTH=2880
TARGET_HEIGHT=1800
OUTPUT_DIR="appstore-screenshots"

# Background color (light gray to match macOS)
BG_COLOR="#F5F5F7"

echo "Creating App Store compatible screenshots..."
echo "Target size: ${TARGET_WIDTH}x${TARGET_HEIGHT}"
echo ""

# Function to create padded screenshot
create_appstore_screenshot() {
    local input_file="$1"
    local output_file="$2"

    if [ ! -f "$input_file" ]; then
        echo "⚠️  Skipping: $input_file (not found)"
        return
    fi

    # Get dimensions of source image
    local src_width=$(sips -g pixelWidth "$input_file" | grep pixelWidth | awk '{print $2}')
    local src_height=$(sips -g pixelHeight "$input_file" | grep pixelHeight | awk '{print $2}')

    echo "Processing: $(basename "$input_file")"
    echo "  Source: ${src_width}x${src_height}"

    # Calculate scaling to fit within target while maintaining aspect ratio
    local scale_w=$(echo "scale=4; $TARGET_WIDTH / $src_width" | bc)
    local scale_h=$(echo "scale=4; $TARGET_HEIGHT / $src_height" | bc)

    # Use the smaller scale to ensure it fits
    local scale=$scale_w
    if (( $(echo "$scale_h < $scale_w" | bc -l) )); then
        scale=$scale_h
    fi

    # Apply 95% of the scale to leave some padding
    scale=$(echo "scale=4; $scale * 0.95" | bc)

    local new_width=$(echo "$src_width * $scale / 1" | bc)
    local new_height=$(echo "$src_height * $scale / 1" | bc)

    echo "  Scaled: ${new_width}x${new_height}"

    # Create temporary scaled image
    local temp_scaled="${output_file}.temp.png"
    sips -z "$new_height" "$new_width" "$input_file" --out "$temp_scaled" >/dev/null 2>&1

    # Calculate padding to center the image
    local pad_x=$(echo "($TARGET_WIDTH - $new_width) / 2" | bc)
    local pad_y=$(echo "($TARGET_HEIGHT - $new_height) / 2" | bc)

    # Create canvas with background color and overlay the scaled image
    sips -z "$TARGET_HEIGHT" "$TARGET_WIDTH" "$temp_scaled" \
         --padColor "$BG_COLOR" \
         --padToHeightWidth "$TARGET_HEIGHT" "$TARGET_WIDTH" \
         --out "$output_file" >/dev/null 2>&1

    # Clean up temp file
    rm "$temp_scaled"

    echo "  ✓ Created: $output_file"
    echo ""
}

# Create the best screenshots for App Store (max 10)

# Screenshot 1: Main Window Overview
create_appstore_screenshot \
    "github/screenshots/MainWindow-1.png" \
    "$OUTPUT_DIR/01-main-window.png"

# Screenshot 2: Popover View (medium or large)
create_appstore_screenshot \
    "github/screenshots/Popover-large.png" \
    "$OUTPUT_DIR/02-popover.png"

# Screenshot 3: Devices Expanded
create_appstore_screenshot \
    "github/screenshots/MainWindow-DevicesExpanded.png" \
    "$OUTPUT_DIR/03-devices-detail.png"

# Screenshot 4: Folders/Services Expanded
create_appstore_screenshot \
    "github/screenshots/MainWindow-ServicesExpanded.png" \
    "$OUTPUT_DIR/04-folders-detail.png"

# Screenshot 5: Activity Charts
create_appstore_screenshot \
    "github/screenshots/MainWindow-Activity.png" \
    "$OUTPUT_DIR/05-activity-charts.png"

# Screenshot 6: Settings Page 1
create_appstore_screenshot \
    "github/screenshots/Settings-1.png" \
    "$OUTPUT_DIR/06-settings-general.png"

# Screenshot 7: Settings Page 2
create_appstore_screenshot \
    "github/screenshots/Settings-2.png" \
    "$OUTPUT_DIR/07-settings-sync.png"

# Screenshot 8: Settings Page 3
create_appstore_screenshot \
    "github/screenshots/Settings-3.png" \
    "$OUTPUT_DIR/08-settings-notifications.png"

# Screenshot 9: Demo Mode
create_appstore_screenshot \
    "github/screenshots/DemoMode-QuickScenarios.png" \
    "$OUTPUT_DIR/09-demo-mode.png"

echo "✅ Done! App Store screenshots created in: $OUTPUT_DIR/"
echo ""
echo "Upload these to App Store Connect:"
ls -lh "$OUTPUT_DIR"/*.png
