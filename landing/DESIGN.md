# DESIGN.md — Project Hub / mcpbolt Landing Page
> Transferred from `landing/app/globals.css`. Applies to landing page only.
> The native Swift app (Project Hub) follows macOS HIG — no custom tokens there.

---

### 1. Visual Theme & Atmosphere

Deep charcoal-black dark UI with a golden amber accent. Cinematic and premium — the kind of dark that reads "pro tool" not "dark mode toggle." Backgrounds use near-black with subtle radial warm glow from the golden accent. Cards are nearly invisible against the page until hovered. Depth comes from very subtle border separations, not strong contrast. The golden bolt (accent) is the single point of personality in an otherwise restrained monochrome palette.

---

### 2. Color Palette & Roles

```css
/* Backgrounds */
--bg: #0a0a0b;                              /* page background — deepest dark */
--bg-soft: #121315;                         /* card background, secondary surfaces */
--bg-card: rgba(255, 255, 255, 0.03);       /* tertiary cards, hover states */

/* Borders */
--border: rgba(255, 255, 255, 0.08);        /* default border — barely visible */
--border-strong: rgba(255, 255, 255, 0.14); /* hover/active border — slightly stronger */

/* Foreground */
--fg: #f7f8fa;                              /* primary text */
--fg-dim: rgba(247, 248, 250, 0.64);        /* secondary text, subtitles */
--fg-faint: rgba(247, 248, 250, 0.42);      /* tertiary text, metadata */

/* Accent (golden) */
--accent: #ffd34d;                          /* primary brand color — the "bolt" */
--accent-2: #f4a300;                        /* accent gradient end, darker amber */

/* Graphite (card header backgrounds) */
--graphite-0: #15181c;                      /* graphite dark */
--graphite-1: #30353d;                      /* graphite light */
--graphite-grad: linear-gradient(135deg, #15181c 0%, #30353d 100%); /* gradient for headers, logo */

/* Status */
--ok: #37d67a;                              /* success, connected, green */
--warn: #ffb020;                            /* warning, amber */
--bad: #ff5454;                             /* error, red */
```

---

### 3. Typography Rules

```
Font family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Helvetica Neue", Arial, sans-serif
Mono font:   "SF Mono", "JetBrains Mono", Menlo, Monaco, ui-monospace, monospace
Base size:   16px
Line-height: 1.55 (body), 1.05 (large headings)

Size scale (fluid where applicable):
--fs-xxl: clamp(2.5rem, 5vw, 4.5rem)   /* hero h1 */
--fs-xl:  clamp(1.6rem, 3vw, 2.4rem)   /* section headings */
--fs-lg:  1.25rem                        /* subtitles, large body */
--fs-md:  1rem                           /* body default */
--fs-sm:  0.875rem                       /* secondary text, table cells */
--fs-xs:  0.75rem                        /* labels, metadata, kickers */

Heading weights: 800 (h1, h2), 700 (h3, h4)
Body weight: 400 (default), 600 (emphasis), 700 (strong)
Letter-spacing: -0.03em (h1), -0.02em (h2/h3), +0.08–0.12em (uppercase kickers)
```

---

### 4. Component Stylings

**Buttons:**
- Default: `background: var(--bg-card)`, `border: 1px solid var(--border-strong)`, `border-radius: 10px`, `font-weight: 600`, hover: slight brightness lift
- Primary (CTA): `background: linear-gradient(180deg, var(--accent) 0%, var(--accent-2) 100%)`, `color: #1a1300` (dark text on golden), hover: slightly lighter gradient

**Cards (feature, blog, tool):**
- `background: var(--bg-card)`, `border: 1px solid var(--border)`, `border-radius: 14px`, padding 22–24px
- Hover: `border-color: var(--border-strong)`, `transform: translateY(-2px)`

**Nav:**
- Sticky, `backdrop-filter: saturate(160%) blur(14px)`, `background: rgba(10, 10, 11, 0.72)`, height 62px

**Code blocks (inline):**
- `background: rgba(255, 211, 77, 0.08)`, `color: #ffe38a`, `border: 1px solid rgba(255, 211, 77, 0.15)`, `border-radius: 5px`

**Code blocks (pre):**
- `background: #0e1013`, `border: 1px solid var(--border)`, `border-radius: 10px`, `color: #d8dde4`

**Callouts:** 4 variants — info (blue tint), warn (amber tint), tip (green tint), danger (red tint) — each with matching border + background at 0.06 opacity.

---

### 5. Layout Principles

```
Spacing scale (4px base): 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72
Max content width: 1120px (.container)
Prose max width: 740px
Padding horizontal: 24px (container sides)

Grid patterns:
- Feature grid: auto-fill, minmax(280px, 1fr), gap 16px
- Compat row: auto-fit, minmax(140px, 1fr), gap 12px
- Docs sidebar + main: 240px + 1fr, gap 48px
- Footer: 1.5fr + 5×1fr (collapses at 1080px → 1.5fr + 3×1fr, at 880px → 2-column)
```

---

### 6. Depth & Elevation

```
z-axis layers:
1. Page:    background radial gradients on body (rgba yellow + rgba graphite glow)
2. Cards:   bg-card (rgba white 0.03) + border (rgba white 0.08)
3. Elevated: bg-soft (#121315) + strong border + box-shadow
4. Nav:     sticky + backdrop-blur — floats above content
5. Popover / modal: [VERIFY — not in globals.css]
6. Tooltips: [VERIFY — not in globals.css]

Shot card depth: 0 30px 60px rgba(0,0,0,0.45) + inset 0 0 0 1px rgba(255,255,255,0.02)
Logo mark depth: 0 4px 12px rgba(0,0,0,0.4) + inset ring rgba(255,255,255,0.08)
```

---

### 7. Do's and Don'ts

**Do:**
- Use `var(--accent)` for any golden highlight, icon background, or active state
- Use `var(--fg-dim)` for body text — `var(--fg)` is for headings and labels only
- Use `border-radius: 14px` for large cards, `10px` for inputs/panels, `999px` for pills/chips
- Use `transform: translateY(-2px)` for hover lift on cards
- Use uppercase + letter-spacing for section kickers (not headings)

**Don't:**
- Don't hardcode `#ffd34d` — always use `var(--accent)`
- Don't use pure black (`#000`) — use `var(--bg)` (#0a0a0b)
- Don't use white text on golden buttons — use `#1a1300` (dark amber) for legibility
- Don't add box shadows to cards — lift uses transform only
- Don't use more than 2 font weights in one component

---

### 8. Responsive Behavior

Mobile-first breakpoints:
- `640px`: hide non-CTA nav links
- `860px`: converter shell from 2-column to 1-column
- `880px`: footer grid from 6-column to 2-column (brand spans full width)
- `900px`: docs sidebar stacks above content (no longer sticky)
- `1080px`: footer grid from 6-column to 4-column

---

### 9. Agent Prompt Guide

> Copy-paste this block at the top of any landing page UI task.

"This is a dark premium landing page. Background is near-black (`--bg: #0a0a0b`). Cards use `--bg-card` (rgba white 0.03) with `--border` (rgba white 0.08). The single accent color is golden amber (`--accent: #ffd34d`). Primary text is `--fg` (#f7f8fa); secondary is `--fg-dim` (64% opacity); tertiary is `--fg-faint` (42%). All spacing is multiples of 4px. Card border-radius is 14px; buttons 10px; pills 999px. Hover lifts cards with `translateY(-2px)` and stronger border. No hardcoded color values — all must use CSS variables. Decoration is rare: radial gradients only on hero and CTA sections. Typography uses SF Pro Display / Inter; mono uses SF Mono. Heading weights are 800; font-size is fluid via clamp(). No box-shadows on cards."

---

### Native App (Project Hub)

Project Hub is a native Swift/SwiftUI app. It does **not** use this CSS design system. It follows macOS HIG:
- Light/dark mode via system appearance
- `NSStatusItem` popover (480×680 fixed)
- Standard SwiftUI components (List, NavigationStack, Button, etc.)
- For UI work inside `projecthub/`, match the existing SwiftUI code style — no custom tokens
