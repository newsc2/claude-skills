# Color System Reference

Read this when selecting colors for any visualization, building palettes, or configuring color scales.

---

## Categorical Palette (strict ordering)

Always use colors in this order. Never skip. Never reorder.

| Order | Token | Hex | Role |
|-------|-------|-----|------|
| 1 | `cat_1` | `#0D7680` | Teal — primary, always first |
| 2 | `cat_2` | `#E6522C` | Warm red-orange — high contrast with teal |
| 3 | `cat_3` | `#2E6E9E` | Steel blue |
| 4 | `cat_4` | `#AD6CAA` | Muted purple — distinct in all CVD types |
| 5 | `cat_5` | `#E9B237` | Gold/amber |
| 6 | `cat_6` | `#379A8B` | Sage green — lower saturation, final resort |
| — | `cat_muted` | `#9B9B9B` | Gray — context/de-emphasized series |

### Usage Rules
- For 1 series: `cat_1` only.
- For 2 series: `cat_1` + `cat_2`.
- For highlight-vs-context: `cat_1` for focal + `cat_muted` for all others. This is the FT's core pattern — minimize distraction, maximize contrast.
- For > 6 series: reconsider the chart. Use small multiples, grouping, or top-N with "Other."

### Colorblind Safety
This palette is tested across deuteranopia, protanopia, and tritanopia. The teal-to-red-orange primary pair differentiates on the luminance channel (not red-green), so it remains distinguishable under all common CVD types. Always verify via Coblis or Viz Palette tool before publishing.

---

## Sequential Ramps (5 steps each)

Use for magnitude, density, intensity. Generated in OKLCH for perceptual uniformity.

### Teal Sequential (default)
```
#E0F0F1 → #9DD4D7 → #4FAFB4 → #0D7680 → #064044
```
Use for: heatmaps, choropleths, density, any single-variable intensity.

### Blue Sequential
```
#DCE8F1 → #9CC2DB → #5C9CC5 → #2E6E9E → #163A55
```

### Warm Sequential (red-orange)
```
#FBEADF → #F2BFA0 → #EC8D5B → #E6522C → #7A2B17
```
Use for: urgency, risk, heat.

### Selection Logic
```
IF data = count/magnitude/density → Teal sequential
IF data = financial/monetary → Blue sequential
IF data = risk/urgency/negative intensity → Warm sequential
IF data needs to match a categorical highlight → use that category's sequential ramp
```

---

## Diverging Ramp (7 steps)

Teal-to-red through warm neutral midpoint:

```
#0D7680 → #5EA5A0 → #AFD4C0 → #F0ECE8 → #F2BFA0 → #EC8D5B → #E6522C
```

- Midpoint `#F0ECE8` is warm neutral — works on both white and cream backgrounds.
- Relies on blue-orange luminance channel (not red-green) — colorblind safe.

### When to Use
```
IF data has meaningful zero/center point → diverging
IF showing deviation from target/average → diverging
IF showing positive-to-negative range → diverging
IF data is purely magnitude (no meaningful center) → sequential, NOT diverging
```

---

## Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `positive` | `#2A8636` | Growth, increase, success, on-target |
| `negative` | `#CC3232` | Decline, decrease, failure, off-target |
| `neutral` | `#9B9B9B` | Unchanged, baseline, no change |
| `highlight` | `#E9B237` | Callout, annotation accent, alert |

### Rules
- Use semantic colors ONLY when the data carries inherent positive/negative meaning. Don't use red for any arbitrary category.
- For financial data: green = growth, red = decline is the universal convention. Don't subvert it.
- Never use semantic colors as categorical series colors — they carry meaning that will confuse.

---

## Background and Surface Colors

| Token | Hex | When |
|-------|-----|------|
| `bg_warm` | `#FFF1E5` | Default for dashboards and web — the FT's signature |
| `bg_white` | `#FFFFFF` | PDF, slides, notebooks, print |
| `bg_neutral` | `#FAFAFA` | Alternative light gray |
| `surface` | `#F2EDEB` | Card/panel on warm background |
| `surface_neutral` | `#F0F0F0` | Card/panel on white/neutral background |

### Gridline Color by Background
```
IF bg = warm (#FFF1E5) → grid = #E4D9D0
IF bg = white (#FFFFFF) → grid = #D4D4D4
IF bg = neutral (#FAFAFA) → grid = #D4D4D4
```

---

## Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `text_primary` | `#222222` | Chart titles, KPI numbers |
| `text_secondary` | `#555555` | Axis titles, legend labels |
| `text_tertiary` | `#707071` | Tick labels, source lines, annotations |

Never use `#000000`. Pure black against warm/light backgrounds creates harsh contrast. `#222222` reads as black but is gentler.

---

## Accessibility Checklist

- [ ] All categorical colors have minimum 3:1 contrast ratio against background (WCAG AA for non-text)
- [ ] Text colors meet 4.5:1 contrast ratio against background (WCAG AA for text)
- [ ] Palette tested in Coblis (colorblind simulator) for deutan, protan, tritan
- [ ] Sequential ramps are perceptually uniform (even steps in perceived lightness)
- [ ] Critical information not conveyed by color alone (use pattern, label, or position as redundant channel)
