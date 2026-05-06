# FUNDAMENTALS.md — Design Principles
> Global. Read before any UI work. Same content on every project.

---

## The 6 Levels (in order of importance)

Build in this order. Do not skip levels.

### Level 1 — Space

Consistent spacing is more important than any color, gradient, or animation.
Use a scale based on multiples of 4px: 4, 8, 12, 16, 24, 32, 48, 64.
Never mix arbitrary values. Random gaps make UIs feel amateurish even when the colors are good.

### Level 2 — Hierarchy

Every screen must answer: what do I look at first? Second? Third?
Hierarchy is created through size, weight, and color contrast — nothing else.
If everything is the same visual weight, the eye has nowhere to go.

### Level 3 — Color Foundation

For dark UIs, you need at least 4 distinct dark values:
- Page background (darkest)
- Card background (slightly lighter)
- Elevated card / hover state (slightly lighter again)
- Border (just barely visible)

Do not use the same dark value everywhere. Depth comes from these separations.
Accent/brand color is separate from these foundation levels.

### Level 4 — Typography

One font family. Two weights (regular + medium, or medium + semibold).
Maximum 5 size steps. Consistent line-height throughout.
Typography problems make everything else look worse — fix them early.

### Level 5 — Depth and Elevation

Use shadows, borders, or background-lightness to show z-axis hierarchy:
background → cards → elevated cards → modals → tooltips.
Elements should feel like they exist on different layers, not a flat plane.

### Level 6 — Decoration (last, earned, rare)

Gradients, glows, animations, blur effects, grain textures.
Only add decoration after Levels 1–5 are solid.
Decoration amplifies whatever is underneath — good foundation + decoration = premium, weak foundation + decoration = noise.

---

## The Ratio Rule

90% of the screen should be plain. 10% can have decoration.
Decoration earns its impact by being rare. One gradient in a sea of plain = striking. Gradients everywhere = wallpaper.
Vercel, Linear, and every premium product follow this ratio intentionally. Their plain moments create contrast for the moments that aren't.

---

## Motion Principles

1. **Purpose-driven only** — animation informs, it does not decorate
2. **Ease-out** for entering elements (feels like they arrived from somewhere)
3. **Ease-in** for exiting elements (feels like they're leaving)
4. **150–300ms** for most interactions (faster = snappy, slower = sluggish)

---

## The Token Rule

Every visual value must have a name. No exceptions.

```css
/* WRONG — hardcoded, invisible to your design system */
background: #1a1a1a;
border-radius: 12px;

/* CORRECT — named, inheritable, changeable in one place */
background: var(--card);
border-radius: var(--radius);
```

When you see a component you want to add:
1. Does it use CSS variables or hardcoded values?
2. If CSS variables → import it, it inherits your tokens automatically. Nothing to do.
3. If hardcoded → find the 2–3 hardcoded values, replace with your tokens. Five minutes.

### The 3 types of "different" (when adding a component you like)

- **Type 1 — Token difference**: component uses tokens, your values differ → your tokens override automatically
- **Type 2 — Missing token**: gradient, glow, blur not in your token set → add it as a new named token, now it's inside your system
- **Type 3 — Structural intention**: sharp corners vs rounded — decide once: update your whole token, or document as a named exception with a reason

---

## Quality Questions (ask before finishing any UI work)

1. **Does this decoration earn its place?** Is it rare enough to have impact?
2. **Is the visual hierarchy immediately clear?** Can someone tell in 2 seconds what's most important?

If either answer is no, fix the foundation before adding more.
