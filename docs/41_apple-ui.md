<!--
TRIGGERS: UI element, component name, what is this called, Apple UI, SwiftUI component, UIKit
PHASE: any
LOAD: on-request
-->

# macOS & iOS UI Design Elements

A reference for discussing Apple platform UI components with precision.

## Window & Container Types

### Window (macOS)
The fundamental container for app content. Has a title bar, traffic lights (close/minimize/zoom), and content area.

### Scene (iOS)
A single instance of your app's UI. An app can have multiple scenes (e.g., two Safari windows on iPad).

### Sheet
A modal view that slides down from the top (macOS) or up from the bottom (iOS). Blocks interaction with parent until dismissed.

Use: focused tasks, confirmations, settings that need immediate attention

### Popover
A floating container that points to its source element with an arrow. Dismisses when clicking outside.

Use: contextual controls, inspectors, secondary options

### Alert
A modal dialog demanding user attention. Contains a message and action buttons.

Types: informational, warning, critical/destructive

### Panel (macOS)
A floating auxiliary window. Stays above regular windows but doesn't block interaction.

Examples: Fonts panel, Colors panel, inspector panels

### Inspector
A panel or sidebar showing properties of the current selection.

Position: typically right sidebar (macOS) or popover/sheet (iOS)

## Navigation Structures

### Navigation Bar (iOS)
The bar at the top of a view containing back button, title, and trailing actions.

```
┌─────────────────────────────────┐
│  < Back      Title      Edit    │
└─────────────────────────────────┘
```

### Toolbar
A bar containing actions relevant to the current content.

Position: top of window (macOS), bottom of screen (iOS)

```
macOS toolbar:
┌─────────────────────────────────────┐
│ [◀ ▶] [+] [Share]     🔍 Search     │
└─────────────────────────────────────┘

iOS toolbar:
┌─────────────────────────────────────┐
│  [↩]    [📁]    [✏]    [📤]   [🗑]  │
└─────────────────────────────────────┘
```

### Tab Bar (iOS)
Bottom navigation showing app's main sections. Persists across the app.

```
┌─────────────────────────────────────┐
│   🏠      🔍      📚      ⚙️       │
│  Home   Search  Library  Settings   │
└─────────────────────────────────────┘
```

### Sidebar
A column (usually left) for navigation or filtering. Can collapse.

Standard widths: ~200–300pt (macOS), varies (iPad)

### Source List (macOS)
A sidebar variant with grouped, hierarchical navigation. Often has disclosure triangles.

Example: Finder sidebar, Mail mailboxes

### Outline View
Hierarchical list with expandable/collapsible rows (disclosure triangles).

### Split View
Two or more content panes side by side. Often sidebar + detail or list + detail.

Types: 
- Two-column (sidebar | content)
- Three-column (sidebar | list | detail)

### Tab View
Multiple content views switched via tabs. Only one visible at a time.

## Content Views

### List / Table View
Rows of content, often tappable. Can be plain, grouped, or inset grouped.

```
Plain:              Grouped:             Inset Grouped:
┌───────────┐      ┌───────────┐        ╭───────────╮
│ Item 1    │      │ SECTION A │        │ SECTION A │
├───────────┤      ├───────────┤        ├───────────┤
│ Item 2    │      │ Item 1    │        │ Item 1    │
├───────────┤      │ Item 2    │        │ Item 2    │
│ Item 3    │      └───────────┘        ╰───────────╯
└───────────┘      ┌───────────┐
                   │ SECTION B │
```

### Collection View
Grid or custom layout of items. More flexible than list view.

### Scroll View
A view whose content can be larger than its frame. Scrolls to reveal hidden content.

### Stack View
Arranges subviews in a horizontal or vertical line. Auto-handles spacing and alignment.

Axis: horizontal (HStack) or vertical (VStack)

### Grid
Two-dimensional arrangement of views in rows and columns.

## Controls

### Button
A tappable control that triggers an action.

Styles: 
- Bordered/filled (primary actions)
- Borderless/plain (secondary)
- Destructive (red, for dangerous actions)
- Gray (cancel/neutral)

### Toggle / Switch
A binary on/off control.

```
iOS:     ◯────●  (ON)     ●────◯  (OFF)
macOS:   [✓] Checkbox label
```

### Slider
Selects a value from a continuous range.

```
Min ├────────●──────────┤ Max
```

### Stepper
Increment/decrement a value with +/– buttons.

```
[ − ]  42  [ + ]
```

### Picker
Selects from a list of options.

Styles:
- Wheel (iOS classic)
- Segmented (inline options)
- Menu (dropdown)
- Inline (expanded list)

### Segmented Control
A horizontal set of mutually exclusive options.

```
┌─────┬─────┬─────┐
│ Day │ Week│Month│
└─────┴─────┴─────┘
```

### Text Field
Single-line text input.

### Text Editor / Text View
Multi-line text input.

### Search Field
Text field with search icon, clear button, and optional scope bar.

```
┌─🔍─────────────────────────╳─┐
│   Search...                  │
└──────────────────────────────┘
```

### Menu
A list of actions or options, shown on click/tap.

Types:
- Pull-down menu (toolbar actions)
- Pop-up menu (selection from options)
- Context menu (right-click / long-press)

### Date Picker
Selects date and/or time.

Styles: compact, inline, wheel, graphical (calendar)

### Color Picker
Selects a color.

### Progress Indicator
Shows task progress.

Types:
- Determinate (progress bar with percentage)
- Indeterminate (spinner, no known endpoint)

```
Determinate:   [████████░░░░░░░] 55%
Indeterminate: ⏳ or spinning wheel
```

## Feedback & Status

### Label
Static text displaying information.

### Badge
A small indicator (usually a number) overlaid on an icon.

```
  📬
   3   ← badge
```

### Banner
A temporary message appearing at the top of a view.

### Toast (not Apple-native, but common)
A brief message that appears and auto-dismisses.

### Activity Indicator
A spinner showing ongoing activity.

### Pull to Refresh
Gesture to reload content by pulling down on a scroll view.

## Gestures

| Gesture | Action |
|---------|--------|
| Tap | Primary action |
| Double-tap | Secondary action, zoom |
| Long press | Context menu, drag initiation |
| Swipe | Delete, actions, navigation |
| Pinch | Zoom in/out |
| Rotate | Rotation (maps, images) |
| Pan / Drag | Move content or objects |
| Edge swipe | Back navigation (iOS) |

## Layout Concepts

### Safe Area
The portion of the screen not obscured by system UI (notch, home indicator, status bar).

### Margins
Padding from the edge of the container. System provides "readable content" margins for text.

### Spacing
Distance between elements. Apple uses an 8pt grid system as a baseline.

### Alignment
How items line up: leading, center, trailing, top, bottom, baseline.

### Adaptive Layout
UI that responds to size class, device, or orientation.

Size classes:
- Compact width (iPhone portrait)
- Regular width (iPad, iPhone landscape)
- Compact height (iPhone landscape)
- Regular height (most configurations)

## Visual Styling

### Materials (Blur Effects)
Translucent backgrounds that blur content behind them.

Types: ultra-thin, thin, regular, thick, chrome

### Vibrancy
Text/icons that blend with the blurred material behind them for better readability.

### SF Symbols
Apple's icon system. Vector icons that scale with text and support weights/variants.

### Accent Color / Tint Color
The app's primary interactive color. Applied to buttons, links, selections.

### Semantic Colors
Colors that adapt to light/dark mode and accessibility settings.

Examples: label, secondaryLabel, tertiaryLabel, systemBackground, systemGroupedBackground

### Corner Radius
Rounded corners on containers. Apple uses continuous (squircle) curves, not simple arcs.

Common values: 10pt (buttons), 12pt (cards), 20pt+ (sheets)

## Quick Reference Table

| Element | macOS | iOS | Purpose |
|---------|-------|-----|---------|
| Sheet | Slides from top | Slides from bottom | Modal task |
| Popover | Points to source | Points to source | Contextual UI |
| Sidebar | Left column | iPad only | Navigation |
| Toolbar | Top of window | Bottom of screen | Actions |
| Tab Bar | Less common | Bottom persistent | App sections |
| Navigation Bar | N/A | Top of view | View title + nav |
| Inspector | Right panel/popover | Sheet/popover | Properties |

## Related Terms

- **HIG**: Human Interface Guidelines (Apple's design documentation)
- **UIKit**: iOS/iPadOS UI framework (imperative)
- **AppKit**: macOS UI framework (imperative)
- **SwiftUI**: Declarative UI framework (cross-platform)
- **Catalyst**: Run iPad apps on macOS
- **Size Class**: Categorization of available space (compact/regular)
- **Trait Collection**: Environment info (size class, appearance, accessibility)
