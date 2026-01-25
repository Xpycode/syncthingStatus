<!--
TRIGGERS: web, website, HTML, CSS, JavaScript, responsive, layout broken, styling issue, frontend
PHASE: implementation
LOAD: full
-->

# Web Development Gotchas

**Common web issues and how to fix them.**

*The problems you'll encounter when building websites with AI assistance.*

---

## The Big Five Web Issues

### 1. CSS Specificity Wars

**Symptom:** Your styles don't apply, or wrong styles win.

**Why it happens:** CSS has specificity rules. More specific selectors override less specific ones.

```css
/* This loses (less specific) */
.button { color: blue; }

/* This wins (more specific) */
div.container .button { color: red; }

/* This always wins (avoid!) */
.button { color: green !important; }
```

**What to tell Claude:**
```
The button color isn't changing. Check CSS specificity.
Don't use !important - fix the specificity properly.
```

**Prevention:** Use consistent, simple selectors. Avoid deep nesting.

---

### 2. Flexbox/Grid Not Behaving

**Symptom:** Elements aren't aligning, layout breaks on resize.

**Common causes:**
- Missing `display: flex` or `display: grid` on parent
- Forgetting `flex-wrap: wrap` for responsive
- Using `width: 100%` when you need `flex: 1`

**What to tell Claude:**
```
This layout should be [describe desired layout].
Currently it [describe what's wrong].
Use flexbox/grid - show me the container AND children styles.
```

**Quick fixes:**
```css
/* Center anything */
.container {
  display: flex;
  justify-content: center;
  align-items: center;
}

/* Equal columns */
.container {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}
```

---

### 3. Responsive Breakage

**Symptom:** Looks good on desktop, broken on mobile (or vice versa).

**Common causes:**
- Fixed pixel widths instead of relative units
- Missing viewport meta tag
- Not testing at different sizes

**Required in HTML head:**
```html
<meta name="viewport" content="width=device-width, initial-scale=1">
```

**What to tell Claude:**
```
This needs to work on mobile and desktop.
Use relative units (rem, %, vw) not fixed pixels.
Add media queries for breakpoints.
Test at 375px, 768px, and 1200px widths.
```

**Mobile-first pattern:**
```css
/* Base styles (mobile) */
.container { padding: 1rem; }

/* Tablet and up */
@media (min-width: 768px) {
  .container { padding: 2rem; }
}

/* Desktop */
@media (min-width: 1200px) {
  .container { max-width: 1200px; margin: 0 auto; }
}
```

---

### 4. Z-Index Chaos

**Symptom:** Modal appears behind other elements, dropdowns hidden.

**Why it happens:** z-index only works on positioned elements, and creates "stacking contexts."

**What to tell Claude:**
```
The modal should appear above everything.
Check that it has position: fixed/absolute/relative.
What z-index values are other elements using?
```

**Pattern for z-index:**
```css
:root {
  --z-dropdown: 100;
  --z-modal: 200;
  --z-tooltip: 300;
  --z-toast: 400;
}

.modal {
  position: fixed;
  z-index: var(--z-modal);
}
```

---

### 5. JavaScript Not Running

**Symptom:** Click handlers don't work, dynamic content doesn't appear.

**Common causes:**
- Script loaded before DOM exists
- Script error stopping execution
- Wrong event listener setup

**What to tell Claude:**
```
The button click isn't doing anything.
Check the browser console for errors.
Is the script loading after the DOM?
```

**Fix: Load script properly:**
```html
<!-- At end of body (recommended) -->
<body>
  ...content...
  <script src="app.js"></script>
</body>

<!-- Or with defer -->
<head>
  <script src="app.js" defer></script>
</head>
```

**Fix: Wait for DOM:**
```javascript
document.addEventListener('DOMContentLoaded', () => {
  // Your code here - DOM is ready
});
```

---

## More Common Issues

### Form Submission Refreshes Page

**Problem:** Form submits, page reloads, data lost.

**Fix:**
```javascript
form.addEventListener('submit', (e) => {
  e.preventDefault(); // Stop the reload
  // Handle form data here
});
```

### Images Not Loading

**Checklist:**
- [ ] Path is correct (relative vs absolute)
- [ ] File extension matches actual file
- [ ] File exists in the right location
- [ ] No typos in filename (case-sensitive on servers)

### CORS Errors

**Symptom:** "Access-Control-Allow-Origin" error in console.

**What it means:** Browser blocking request to different domain.

**What to tell Claude:**
```
Getting CORS error when fetching from [API].
Is this a backend issue or do I need a proxy?
```

### Content Flashes/Jumps on Load

**Causes:**
- CSS loading after content
- Fonts loading late (FOUT/FOIT)
- Images without dimensions

**Prevention:**
```html
<!-- Always specify image dimensions -->
<img src="photo.jpg" width="800" height="600" alt="...">
```

```css
/* Reserve space for images */
.image-container {
  aspect-ratio: 16/9;
}
```

---

## Quick Diagnostic Questions

| Symptom | Ask Claude |
|---------|-----------|
| Styles not applying | "Check CSS specificity and selector accuracy" |
| Layout broken | "Show me the flexbox/grid container setup" |
| Works on desktop only | "Are we using responsive units and media queries?" |
| Click does nothing | "Check browser console for JavaScript errors" |
| Content hidden | "Check z-index and overflow properties" |

---

## Browser DevTools Checks

Tell Claude to check:

```
Open browser DevTools (F12) and:
1. Console tab - any red errors?
2. Elements tab - is the element actually there?
3. Styles panel - are styles being applied/overridden?
4. Network tab - are all resources loading?
```

---

## Prevention Rules for CLAUDE.md

```markdown
## Web Development Rules
- Mobile-first: base styles for mobile, media queries for larger
- Use relative units (rem, %, vw/vh) not fixed px for layout
- Always include viewport meta tag
- Test at 375px, 768px, 1200px minimum
- Keep z-index organized with CSS variables
- Scripts at end of body or with defer
- Check browser console before saying "it works"
```

---

*Web development has many moving parts. When something breaks, check the browser console first.*
