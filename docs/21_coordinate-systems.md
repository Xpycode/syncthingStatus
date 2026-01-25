<!--
TRIGGERS: image, crop, position wrong, offset, pixels, points, Retina, CGImage, NSImage, coordinates
PHASE: implementation
LOAD: full
-->

# Coordinate Systems Guide

*The #1 source of image/video processing bugs.*

---

## The Core Problem

macOS and iOS have **multiple coordinate systems** that represent the same image differently:

| System | Origin | Units | Source |
|--------|--------|-------|--------|
| **NSImage.size** | N/A | Points | High-level Cocoa |
| **CGImage** | Top-left | Pixels | Core Graphics |
| **Core Graphics context** | Bottom-left | Points | Drawing context |
| **SwiftUI** | Top-left | Points | Layout system |
| **EXIF orientation** | Varies | Pixels | Camera metadata |

**The Bug Pattern:**
```swift
// BROKEN: Mixing points and pixels
let cropRect = CGRect(x: 100, y: 100, width: 200, height: 200)  // Points?
cgImage.cropping(to: cropRect)  // Expects pixels!
```

---

## Points vs Pixels (Retina Scaling)

### The Rule

| Property | Returns | Scale on Retina |
|----------|---------|-----------------|
| `nsImage.size` | Points | Display size |
| `cgImage.width` | Pixels | 2x on Retina |
| `cgImage.height` | Pixels | 2x on Retina |

**Conversion:**
```swift
// Points to Pixels
let pixelWidth = Int(nsImage.size.width * scaleFactor)
let pixelHeight = Int(nsImage.size.height * scaleFactor)

// Pixels to Points
let pointWidth = CGFloat(cgImage.width) / scaleFactor
let pointHeight = CGFloat(cgImage.height) / scaleFactor

// Get scale factor from NSImage
let scaleFactor = nsImage.representations.first?.pixelsWide ?? 1
                  / Int(nsImage.size.width)
// Or assume 2x for Retina
let scaleFactor: CGFloat = 2.0
```

### Real Bug Example (CropBatch)

**Symptom:** Crop position off by 2x on Retina displays.

**Root Cause:**
```swift
// BROKEN
let originalSize = nsImage.size  // Returns POINTS (e.g., 1000x1000)
// But CGImage is PIXELS (e.g., 2000x2000 on Retina)
cgImage.cropping(to: cropRectInPoints)  // Off by 2x!
```

**Fix:**
```swift
// CORRECT
let pixelWidth = cgImage.width   // Use PIXELS
let pixelHeight = cgImage.height
let cropRectInPixels = CGRect(
    x: cropRectInPoints.x * scaleFactor,
    y: cropRectInPoints.y * scaleFactor,
    width: cropRectInPoints.width * scaleFactor,
    height: cropRectInPoints.height * scaleFactor
)
cgImage.cropping(to: cropRectInPixels)
```

---

## Origin Systems (Top-Left vs Bottom-Left)

### The Confusion

| Context | Y-Origin | Y increases... |
|---------|----------|----------------|
| **CGImage** | Top-left | Downward |
| **Core Graphics (CGContext)** | Bottom-left | Upward |
| **SwiftUI / UIKit** | Top-left | Downward |
| **AppKit (NSView)** | Bottom-left | Upward (flippable) |

### Converting Between Origins

```swift
// Top-left to Bottom-left (for CGContext drawing)
let flippedY = imageHeight - topLeftY - rectHeight

// Bottom-left to Top-left (for CGImage operations)
let topLeftY = imageHeight - bottomLeftY - rectHeight
```

### Real Bug Example

**Symptom:** Crop appears vertically mirrored.

**Root Cause:** Using top-left coordinates in a bottom-left context (or vice versa).

**Fix:** Always document which origin system you're using:
```swift
// Coordinate system: Top-left origin, PIXELS (CGImage convention)
let cropRect = CGRect(x: pixelX, y: pixelY, width: w, height: h)
```

---

## EXIF Orientation

### The 8 EXIF Orientations

| Value | Transform Needed | Common Source |
|-------|------------------|---------------|
| 1 | None (normal) | Landscape, home right |
| 2 | Flip horizontal | Mirror |
| 3 | Rotate 180° | Upside down |
| 4 | Flip vertical | Mirror + upside down |
| 5 | Rotate 90° CW + flip horizontal | Portrait, home top, mirrored |
| 6 | Rotate 90° CW | Portrait, home right |
| 7 | Rotate 90° CCW + flip horizontal | Portrait, home bottom, mirrored |
| 8 | Rotate 90° CCW | Portrait, home left |

### The Problem

```swift
// BROKEN: CGImage ignores EXIF, gives raw pixels
let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
// This may be rotated 90° from what you expect!
```

### The Solution

```swift
// CORRECT: Apply EXIF orientation before processing
func normalizedCGImage(from nsImage: NSImage) -> CGImage? {
    // Create a bitmap context with the correct orientation
    let rect = CGRect(origin: .zero, size: nsImage.size)
    return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    // Or use CIImage which handles orientation:
    // CIImage(cgImage: cgImage).oriented(forExifOrientation: orientation)
}
```

### Always Check Orientation

```swift
// Read EXIF orientation from image
if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
   let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
   let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
    print("EXIF orientation: \(orientation)")
}
```

---

## Coordinate Mapping Table Pattern

When debugging coordinate issues, create a mapping table:

```swift
// DEBUG: Log all coordinate systems for this image
print("""
COORDINATE DEBUG for: \(filename)
================================
NSImage.size:       \(nsImage.size) (points)
CGImage dimensions: \(cgImage.width) x \(cgImage.height) (pixels)
Scale factor:       \(scaleFactor)
EXIF orientation:   \(exifOrientation)

Crop rect (UI):     \(uiCropRect) (points, top-left origin)
Crop rect (pixels): \(pixelCropRect) (pixels, top-left origin)
Expected output:    \(expectedWidth) x \(expectedHeight) pixels
""")
```

This pattern helped diagnose 3 separate crop bugs in the CropBatch project.

---

## Framework-Specific Notes

### AVFoundation (Video)

```swift
// Video dimensions are in pixels
let videoSize = track.naturalSize  // CGSize in pixels

// But video transforms can rotate
let transform = track.preferredTransform
// Check if width/height should be swapped based on transform
```

### SwiftUI Image Display

```swift
// SwiftUI uses points
Image(nsImage: nsImage)
    .resizable()
    .frame(width: 200, height: 200)  // Points, not pixels
```

### Core Graphics Drawing

```swift
// CGContext uses bottom-left origin by default
let context = CGContext(...)

// Flip to top-left if needed
context.translateBy(x: 0, y: height)
context.scaleBy(x: 1.0, y: -1.0)
```

---

## Debugging Checklist

When something appears in the wrong position or size:

- [ ] Are you mixing points and pixels?
- [ ] What's the scale factor? (1x, 2x, 3x)
- [ ] Which origin system? (top-left vs bottom-left)
- [ ] Is EXIF orientation being applied?
- [ ] Add coordinate mapping table logging
- [ ] Test on both Retina and non-Retina displays

---

## Code Comments Pattern

Always document coordinate systems in code:

```swift
// WARNING: Coordinate system documentation
// - originalSize: PIXELS from CGImage (not NSImage.size which is POINTS)
// - cropRect: PIXELS, top-left origin (matching CGImage convention)
// - On Retina displays, NSImage.size is 0.5x of CGImage dimensions
// - EXIF orientation has already been applied at this point
//
// See: CropBatch-BUGFIX-retina-crop-position.md for the bug this fixed
let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
```

---

## Quick Reference

| I have... | I need... | Multiply by... |
|-----------|-----------|----------------|
| Points | Pixels | scaleFactor (usually 2.0) |
| Pixels | Points | 1/scaleFactor |
| Top-left Y | Bottom-left Y | imageHeight - y - height |
| Bottom-left Y | Top-left Y | imageHeight - y - height |

---

*When in doubt: print all coordinate values, compare expected vs actual, create a mapping table.*
