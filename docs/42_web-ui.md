<!--
TRIGGERS: web UI, HTML element, CSS, web component, website UI, frontend
PHASE: any
LOAD: on-request
-->

# Web UI Design Elements

A reference for discussing web interface components with precision.

## Page Structure

### Viewport
The visible area of a web page in the browser window. Changes with window size.

### Header
Top section of a page, typically containing logo, navigation, and global actions.

```
┌─────────────────────────────────────────────────┐
│  Logo       Nav   Nav   Nav        [Search] [☰] │
└─────────────────────────────────────────────────┘
```

### Footer
Bottom section with secondary navigation, legal links, contact info.

### Hero
A large, prominent banner section, usually at the top of a landing page. Often contains headline, subtext, and CTA.

```
┌─────────────────────────────────────────────────┐
│                                                 │
│           Big Bold Headline Here                │
│         Supporting text underneath              │
│              [ Call to Action ]                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Section
A thematic grouping of content, often full-width with distinct background.

### Container
A centered, max-width wrapper that constrains content width for readability.

```
|         [=== container content ===]            |
              ^--- max-width, centered
```

### Sidebar
A vertical column alongside main content, for navigation or supplementary info.

### Main Content Area
The primary content region of the page.

### Grid
A layout system dividing space into columns and rows.

Common: 12-column grid (Bootstrap), auto-fit/auto-fill (CSS Grid)

### Gutter
The gap between grid columns or elements.

## Navigation Patterns

### Navbar / Navigation Bar
Horizontal navigation, typically in the header.

Types:
- Fixed: stays at top during scroll
- Sticky: becomes fixed after scrolling past
- Static: scrolls with page

### Hamburger Menu
Three-line icon (☰) that toggles a hidden navigation menu. Common on mobile.

```
☰  →  opens slide-out or dropdown nav
```

### Drawer / Slide-out Menu
Navigation panel that slides in from the side (usually left).

```
┌────────┬────────────────────────┐
│ Nav    │                        │
│ Link 1 │     Page Content       │
│ Link 2 │     (dimmed/pushed)    │
│ Link 3 │                        │
└────────┴────────────────────────┘
```

### Mega Menu
A large dropdown menu showing multiple columns of links, often with images.

### Breadcrumbs
A trail showing the user's location in site hierarchy.

```
Home > Products > Electronics > Phones
```

### Tabs
Horizontal navigation between related content panels. Only one panel visible at a time.

```
┌─────┬─────┬─────┐
│ Tab │ Tab │ Tab │ ← active has different style
├─────┴─────┴─────┴────────────────┐
│                                  │
│   Tab content panel              │
│                                  │
└──────────────────────────────────┘
```

### Pagination
Navigation between pages of results.

```
[ ← Prev ]  1  2  [3]  4  5  ...  20  [ Next → ]
```

### Infinite Scroll
Automatically loads more content as user scrolls down.

### Skip Link
Hidden link (visible on focus) to skip navigation and jump to main content. Accessibility feature.

### Anchor Link / Jump Link
Links to a specific section within the same page via ID.

### Back to Top
A button (often bottom-right) that scrolls back to page top.

## Overlay & Modal Patterns

### Modal / Dialog
A centered overlay that blocks page interaction until dismissed.

```
         ┌──────────────────────┐
░░░░░░░░░│   Modal Title    [X] │░░░░░░░░░
░░░░░░░░░├──────────────────────┤░░░░░░░░░
░░░░░░░░░│                      │░░░░░░░░░
░░░░░░░░░│   Content here       │░░░░░░░░░
░░░░░░░░░│                      │░░░░░░░░░
░░░░░░░░░│   [Cancel] [Confirm] │░░░░░░░░░
░░░░░░░░░└──────────────────────┘░░░░░░░░░
            ↑ backdrop/scrim (dimmed)
```

### Lightbox
A modal specifically for displaying images or media, often with prev/next navigation.

### Backdrop / Scrim / Overlay
The dimmed layer behind a modal that blocks the page.

### Drawer (Overlay variant)
Like the nav drawer but for any slide-in panel (cart, filters, settings).

### Popover
A small floating container triggered by clicking an element. Positioned relative to trigger.

```
   [Click me]
       ↓
   ┌────────────┐
   │ Popover    │
   │ content    │
   └────────────┘
```

### Tooltip
A small text hint that appears on hover/focus. For brief explanations only.

```
   [?] ← hover
    ↓
  ┌─────────────┐
  │ Helper text │
  └─────────────┘
```

### Dropdown
A menu that appears below a trigger button, showing options or actions.

```
  [ Options ▼ ]
  ┌────────────┐
  │ Edit       │
  │ Duplicate  │
  │ Delete     │
  └────────────┘
```

### Flyout
A submenu that appears to the side of a parent menu item.

### Toast / Snackbar
A brief, auto-dismissing message. Usually bottom or top of screen.

```
┌─────────────────────────────────────┐
│                                     │
│              Page                   │
│                                     │
│  ┌────────────────────────┐         │
│  │ ✓ Saved successfully   │         │
│  └────────────────────────┘         │
└─────────────────────────────────────┘
```

### Banner / Alert Bar
A message bar, often full-width at the top, for announcements or warnings.

```
┌─────────────────────────────────────┐
│ ⚠ Your trial expires in 3 days [X] │
├─────────────────────────────────────┤
│           Rest of page              │
```

### Notification Badge
A small indicator (often a number or dot) showing updates.

```
  🔔
   3  ← badge
```

## Forms & Input

### Text Input / Text Field
Single-line text entry.

```
┌──────────────────────────┐
│ Placeholder text         │
└──────────────────────────┘

Label
┌──────────────────────────┐
│ User input here          │
└──────────────────────────┘
Helper text or error message
```

### Textarea
Multi-line text entry.

### Select / Dropdown Select
Choose one option from a list.

```
┌─────────────────────────▼┐
│ Select an option...      │
└──────────────────────────┘
```

### Multi-select
Choose multiple options. Can be checkboxes, tags, or a searchable list.

### Combobox / Autocomplete
Text input with suggestions dropdown. User can type or select.

```
┌──────────────────────────┐
│ New Y                    │
├──────────────────────────┤
│ New York                 │
│ New York City            │
│ New Jersey               │
└──────────────────────────┘
```

### Checkbox
Toggle one or more options on/off.

```
[✓] Option A
[ ] Option B
[✓] Option C
```

### Radio Button
Select one option from a mutually exclusive group.

```
(●) Option A
( ) Option B
( ) Option C
```

### Toggle / Switch
Binary on/off control, styled as a sliding switch.

```
OFF ○────●  ON
```

### Slider / Range Input
Select a value from a continuous range.

```
Min ├────────●──────────┤ Max
```

### Range Slider (dual handles)
Select a range with min and max values.

```
├────●━━━━━━●────────┤
    $100    $500
```

### Date Picker
Input for selecting dates, often with calendar popup.

### Time Picker
Input for selecting time.

### Color Picker
Input for selecting colors.

### File Input / Upload
Control for selecting files to upload.

Types:
- Native file input
- Drag-and-drop zone
- Click-to-upload area

```
┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐
│                         │
│   Drag files here or    │
│   [Browse Files]        │
│                         │
└─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘
```

### Stepper / Number Input
Numeric input with increment/decrement buttons.

```
[ − ]  5  [ + ]
```

### OTP / Verification Code Input
Segmented input for one-time passwords.

```
┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
│ 4 │ │ 8 │ │ 2 │ │ 9 │ │   │ │   │
└───┘ └───┘ └───┘ └───┘ └───┘ └───┘
```

### Input Group
An input combined with buttons or labels.

```
┌────────┬────────────────────┬────────┐
│ https: │ example.com        │ [Copy] │
└────────┴────────────────────┴────────┘
```

### Floating Label
Label that sits inside input, then floats above when focused/filled.

```
Unfocused:              Focused:
┌──────────────────┐    Email
│ Email            │    ┌──────────────────┐
└──────────────────┘    │ user@example.com │
                        └──────────────────┘
```

### Password Reveal
Eye icon to toggle password visibility.

```
┌────────────────────────[👁]┐
│ ••••••••                   │
└────────────────────────────┘
```

### Form Validation
Visual feedback for input correctness.

States: valid (green), invalid (red), warning (yellow)

## Buttons & Actions

### Button
A clickable element that triggers an action.

Types by importance:
- Primary: main action, prominent styling
- Secondary: alternative action, less prominent
- Tertiary / Ghost: minimal styling, text-like
- Destructive: dangerous actions (delete), often red

```
[  Primary  ]  [ Secondary ]  Tertiary
```

### Icon Button
Button with only an icon, no text.

```
[🔍] [⚙️] [🗑️]
```

### Floating Action Button (FAB)
A circular button that floats above content, usually for primary action.

Position: typically bottom-right

```
                    ┌───┐
                    │ + │
                    └───┘
```

### Split Button
Button with main action and dropdown for alternatives.

```
┌──────────┬───┐
│  Save    │ ▼ │  → Save as Draft
└──────────┴───┘    Save & Close
                    Save as Template
```

### Button Group
Multiple related buttons joined together.

```
┌──────┬──────┬──────┐
│ Left │Center│Right │
└──────┴──────┴──────┘
```

### Link
Text that navigates to another page or resource.

### CTA (Call to Action)
A prominent button or link urging user action. Key conversion element.

## Content Display

### Card
A contained unit of content with defined boundaries. Often has image, title, text, actions.

```
┌───────────────────────┐
│ ▓▓▓▓▓▓▓ Image ▓▓▓▓▓▓▓ │
├───────────────────────┤
│ Title                 │
│ Description text here │
│ [Action]    [Action]  │
└───────────────────────┘
```

### List
Vertical sequence of items.

Types: simple, with icons, with avatars, interactive

### Table
Data in rows and columns.

Features: sortable columns, selectable rows, inline actions

```
┌──────────┬───────────┬─────────┐
│ Name     │ Email     │ Actions │
├──────────┼───────────┼─────────┤
│ Alice    │ a@e.com   │ [Edit]  │
│ Bob      │ b@e.com   │ [Edit]  │
└──────────┴───────────┴─────────┘
```

### Data Grid
An advanced table with features like virtual scrolling, cell editing, column resizing.

### Accordion
Vertically stacked headers that expand/collapse to reveal content.

```
┌───────────────────────────┐
│ ▶ Section 1               │
├───────────────────────────┤
│ ▼ Section 2               │
│   Expanded content here   │
│   More content            │
├───────────────────────────┤
│ ▶ Section 3               │
└───────────────────────────┘
```

### Collapse / Expandable
A section that can be toggled open/closed.

### Carousel / Slider
Horizontally scrolling content with prev/next controls.

```
     ←  [ ][■][ ][ ]  →
         ● ○ ○ ○  ← indicators
```

### Gallery
Grid of images, often clickable to open lightbox.

### Avatar
A small image representing a user, often circular.

```
 ┌───┐
 │ 👤│  or initials: (JD)
 └───┘
```

### Chip / Tag / Badge
A small, pill-shaped element for labels, filters, or status.

```
[ React ]  [ JavaScript ]  [ ✓ Completed ]
```

### Pill
Rounded-end container, often for counts or status.

### Empty State
Placeholder UI shown when there's no data.

```
┌─────────────────────────────┐
│                             │
│           📭               │
│     No messages yet         │
│   [ Compose Message ]       │
│                             │
└─────────────────────────────┘
```

### Skeleton / Shimmer
A placeholder shape shown while content loads.

```
┌─────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ ← animated shimmer
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓             │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │
└─────────────────────────────┘
```

### Placeholder
Generic term for loading or empty content stand-in.

## Progress & Loading

### Spinner
Animated icon indicating loading/processing.

```
  ⠋ ⠙ ⠸ ⠴ ⠦ ⠇  (animated rotation)
```

### Progress Bar
Horizontal bar showing completion percentage.

```
Determinate:    [████████░░░░░░░] 55%
Indeterminate:  [▓▓░░░░░░░░▓▓▓░░] (animated)
```

### Progress Circle / Ring
Circular progress indicator.

### Loading Overlay
Full-screen or section overlay with spinner while loading.

### Step Indicator / Stepper
Shows progress through a multi-step process.

```
  (1)────(2)────(●)────( )────( )
 Info   Address Payment Review  Done
```

## Media

### Image
Static visual content. Consider lazy loading for performance.

### Video Player
Embedded video with controls (play, pause, scrub, volume, fullscreen).

### Audio Player
Controls for audio playback.

### Embed / iFrame
External content embedded in the page (maps, videos, widgets).

### Figure / Caption
Image or media with descriptive text.

```
┌─────────────────┐
│     Image       │
└─────────────────┘
  Figure 1: Caption
```

## Accessibility Concepts

### Focus Ring / Outline
Visual indicator showing which element has keyboard focus.

### ARIA Labels
Attributes that provide accessible names and descriptions for screen readers.

### Skip Navigation
Link to bypass repetitive navigation and jump to main content.

### Alt Text
Descriptive text for images, read by screen readers.

### Landmark Regions
Semantic regions (header, main, nav, aside, footer) that help screen readers navigate.

### Focus Trap
Keeping keyboard focus within a modal or component until dismissed.

### Live Region
An area that announces dynamic content changes to screen readers.

## Responsive Design

### Breakpoints
Screen widths where layout changes.

Common breakpoints:
- Mobile: < 640px
- Tablet: 640px – 1024px
- Desktop: > 1024px

### Media Query
CSS rules that apply at specific viewport sizes.

### Mobile-first
Designing for mobile, then adding complexity for larger screens.

### Fluid Layout
Layout that stretches/shrinks with viewport width.

### Fixed Layout
Layout with a set pixel width.

### Responsive Images
Images that load different sizes based on screen/device.

### Aspect Ratio
The proportional relationship between width and height.

Common: 16:9 (video), 4:3 (classic), 1:1 (square)

## Spacing & Layout

### Padding
Space inside an element, between content and border.

### Margin
Space outside an element, between it and adjacent elements.

### Gap
Space between flex or grid items (CSS gap property).

### Whitespace
Empty space used intentionally for clarity and visual hierarchy.

### Z-index
Stacking order of overlapping elements. Higher values appear on top.

```
z-index: 10   ← on top
z-index: 5
z-index: 1    ← behind
```

## Quick Reference Table

| Pattern | Use Case | Notes |
|---------|----------|-------|
| Modal | Focused task, confirmation | Blocks page, needs close action |
| Popover | Contextual info/controls | Dismisses on outside click |
| Tooltip | Brief helper text | Hover/focus triggered, no interaction |
| Toast | Status messages | Auto-dismisses, non-blocking |
| Drawer | Navigation, side panels | Slides in from edge |
| Dropdown | Action menus, selection | Triggered by click |
| Accordion | Collapsible sections | Good for FAQs, dense info |
| Tabs | Related content switching | One panel visible at a time |
| Carousel | Browsing multiple items | Prev/next or auto-advance |

## CSS Layout Methods

| Method | Best For |
|--------|----------|
| Flexbox | One-dimensional layouts (row or column) |
| CSS Grid | Two-dimensional layouts (rows and columns) |
| Float | Legacy, text wrapping around images |
| Position | Overlays, fixed elements, precise placement |

## Related Terms

- **Component Library**: Pre-built UI components (Material UI, Chakra, shadcn)
- **Design System**: Complete set of design standards and components
- **Atomic Design**: Methodology: atoms → molecules → organisms → templates → pages
- **BEM**: CSS naming convention (Block__Element--Modifier)
- **Semantic HTML**: Using correct HTML elements for meaning (nav, article, aside)
- **Progressive Enhancement**: Building basic functionality first, enhancing for capable browsers
- **Graceful Degradation**: Building for modern browsers, ensuring older ones still work
- **Responsive**: Adapts to different screen sizes
- **Adaptive**: Serves different layouts for specific breakpoints
- **SPA**: Single Page Application (loads once, updates dynamically)
- **SSR**: Server-Side Rendering (HTML generated on server)
- **CSR**: Client-Side Rendering (HTML generated in browser)
- **Hydration**: Making server-rendered HTML interactive with JavaScript
