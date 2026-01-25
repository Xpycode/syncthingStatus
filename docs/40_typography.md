<!--
TRIGGERS: font, typography, tracking, kerning, leading, spacing, text, typeface
PHASE: any
LOAD: on-request
-->

# Typography Spacing & Measurement Terms

A reference for discussing font metrics and text spacing with precision.

## Core Spacing Controls

### Tracking
Uniform letter-spacing applied across an entire text block or selection. Affects all characters equally.

```
Normal:    HELLO WORLD
Tight:     HELLOWORLD
Loose:     H E L L O   W O R L D
```

Also called: letter-spacing (CSS), character spacing

### Kerning
Adjustment of space between specific letter pairs to correct optical imbalances. Targets problem pairs where letter shapes create awkward gaps.

```
Without kerning:  T o d a y   W A T E R
                  ^ gap      ^   ^ gaps look weird

With kerning:     Today   WATER
                  ^ tighter  ^ letters nestle together
```

Common kerning pairs: AV, AW, To, Ty, Ta, VA, WA, LT, LY, PA, AT

### Leading
Vertical space between lines of text. Measured baseline to baseline. Name derives from lead strips used in letterpress printing.

Pronunciation: "ledding" (rhymes with "wedding")

```
Tight leading:
The quick brown fox
jumps over the lazy
dog near the river.

Loose leading:
The quick brown fox

jumps over the lazy

dog near the river.
```

Also called: line-height (CSS), line spacing

### Word Spacing
Horizontal space between words.

```
Tight:    The quick brown fox jumps
Normal:   The quick brown fox jumps
Loose:    The  quick  brown  fox  jumps
```

## Anatomical Measurements

### Baseline
The invisible line that letters sit on. Most letters rest here; descenders drop below it.

### X-height
Height of lowercase letters without ascenders or descenders (like x, a, e, o, n, m). A major factor in perceived font size and readability.

### Cap Height
Height of capital letters, measured from baseline to top of flat capitals like H or E.

### Ascenders
Parts of lowercase letters that extend above the x-height: b, d, f, h, k, l, t

### Descenders
Parts of lowercase letters that drop below the baseline: g, j, p, q, y

### Baseline Shift
Moving individual characters above or below the baseline.

```
Normal:      H2O    x^2
With shift:  H₂O    x²
```

## Paragraph & Block Controls

### Measure
Line length, typically counted in characters or ems. Optimal measure for readability is often cited as 45–75 characters.

```
Short measure (~30 chars):       Long measure (~80 chars):
The quick brown fox              The quick brown fox jumps over the lazy dog near the river bank
jumps over the lazy              where the water flows gently between the rocks and reeds.
dog near the river.
```

### Indent
Horizontal offset at the start of paragraphs or lines.

```
No indent:                       First-line indent:
Lorem ipsum dolor sit                Lorem ipsum dolor sit
amet consectetur. New            amet consectetur. New
paragraph starts here.               paragraph starts here.
```

Types: first-line indent, hanging indent (first line outdented), block indent

### Hanging Punctuation
Punctuation marks placed outside the text margin to create a cleaner visual edge.

```
Normal alignment:               Hanging punctuation:
"Hello," she said.              "Hello," she said.
"Goodbye," he replied.          "Goodbye," he replied.
|← text block edge              |← visually cleaner edge
```

### Optical Margin Alignment
Similar to hanging punctuation but for letters with angled or curved edges (A, T, V, W, O) that are nudged slightly past the margin so the visual edge appears straighter.

## Quick Reference Table

| Term | What it controls | Axis |
|------|------------------|------|
| Tracking | All letter spacing uniformly | Horizontal |
| Kerning | Specific letter pair spacing | Horizontal |
| Leading | Line spacing | Vertical |
| Word spacing | Space between words | Horizontal |
| Measure | Line length | Horizontal |
| Baseline shift | Individual character vertical position | Vertical |
| Indent | Paragraph/line offset | Horizontal |

## Related Terms

- **Em**: A unit equal to the current font size (12pt font = 12pt em)
- **En**: Half an em
- **Point (pt)**: Traditional unit; 72 points = 1 inch
- **Glyph**: A single character shape in a font
- **Font metrics**: The complete set of measurements defining a font's spacing behavior
