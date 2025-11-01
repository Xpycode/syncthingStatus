#!/usr/bin/env python3
from PIL import Image, ImageFilter, ImageDraw
import sys

def blur_region(image_path, output_path, regions):
    """Blur specific regions of an image"""
    img = Image.open(image_path)

    # Create a copy to work with
    result = img.copy()

    for region in regions:
        x1, y1, x2, y2, blur_radius = region

        # Extract the region
        region_img = img.crop((x1, y1, x2, y2))

        # Apply blur
        blurred_region = region_img.filter(ImageFilter.GaussianBlur(radius=blur_radius))

        # Paste back
        result.paste(blurred_region, (x1, y1))

    result.save(output_path)
    print(f"Saved blurred image to {output_path}")

if __name__ == "__main__":
    # Window screenshot (first image - 13-48-31)
    # Blur folder names and paths in "Folder Sync Status" section
    window_regions = [
        # Xcode Projects name and path
        (100, 440, 225, 470, 15),
        # SYNCsim name and path
        (100, 483, 200, 513, 15),
        # DWsync name and path
        (100, 527, 195, 557, 15),
    ]

    blur_region(
        "SHOTTR--2025-10-31--13-48-31.png",
        "SHOTTR--2025-10-31--13-48-31-blurred.png",
        window_regions
    )

    # Menu bar screenshot (second image - 13-52-01)
    # Blur folder names and paths in "Folder Sync Status" section
    menubar_regions = [
        # Xcode Projects name and path
        (48, 408, 225, 438, 15),
        # SYNCsim name and path
        (48, 451, 200, 481, 15),
        # DWsync name and path
        (48, 495, 195, 525, 15),
    ]

    blur_region(
        "SHOTTR--2025-10-31--13-52-01.png",
        "SHOTTR--2025-10-31--13-52-01-blurred.png",
        menubar_regions
    )
