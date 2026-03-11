# Styling and Implementation Reference

Read this when writing chart code, styling dashboards, or configuring visualization libraries.

---

## Font Setup (one-time)

The editorial look requires specific fonts. Without them, matplotlib silently falls back to DejaVu Sans — everything looks generic instantly.

### Install on macOS
```bash
# Inter (data labels, axes — best-in-class tabular figures)
# Lora (chart titles — closest free match to FT's Financier Display)
brew install --cask font-inter font-lora

# Clear matplotlib's font cache so it discovers the new fonts
python3 -c "
import matplotlib as mpl
import os, glob
for f in glob.glob(os.path.join(mpl.get_cachedir(), 'fontlist-*.json')):
    os.remove(f)
    print(f'Removed {f}')
print('Restart your notebook kernel.')
"
```

### Fallback chain (if fonts not installed)
| Role | Preferred | macOS fallback | Windows fallback |
|------|-----------|----------------|-----------------|
| Titles (serif) | Lora | Georgia | Georgia |
| Labels (sans) | Inter | Helvetica | Arial |
| Condensed | IBM Plex Sans Condensed | Helvetica Neue | Arial Narrow |
| Mono | IBM Plex Mono | Menlo | Consolas |

Georgia and Helvetica are always available on macOS — acceptable but not ideal.

### Verify fonts are detected
```python
import matplotlib.font_manager as fm
for name in ["Inter", "Lora", "Georgia", "Helvetica"]:
    matches = [f.name for f in fm.fontManager.ttflist if name.lower() in f.name.lower()]
    print(f"{name}: {'✓ ' + matches[0] if matches else '✗ not found'}")
```

---

## Typography

### Font Stack
```
Sans (data labels, axes, body): Inter → IBM Plex Sans → Helvetica → Arial
Serif (chart titles ONLY):      Lora → Georgia → Times New Roman
Condensed (tight spaces):       IBM Plex Sans Condensed → Helvetica Neue Condensed
Mono (exact values):            IBM Plex Mono → Menlo → Consolas
```

### Why serif titles matter (Tufte + FT principle)
The serif/sans split creates **typographic hierarchy** — the most important editorial design pattern. The serif headline commands attention and signals authority. Sans body text recedes. Without this split, everything has the same visual weight and the chart reads as "generic."

### Always Enable Tabular Figures
```css
font-feature-settings: "tnum" 1, "lnum" 1, "zero" 1;
```
Without `tnum`, digits have different widths — columns misalign, axes jitter. Non-negotiable for any data context.

### Type Scale

| Element | Size | Weight | Font | Color |
|---------|------|--------|------|-------|
| KPI / hero number | 40px | 300 (Light) | Sans | `#222222` |
| Chart title | 18px | 700 (Bold) | **Serif** | `#222222` |
| Chart subtitle | 13px | 400 (Regular) | Sans | `#555555` |
| Axis title | 13px | 400 | Sans | `#707071` |
| Tick labels | 11px | 400 | Sans | `#707071` |
| Legend labels | 11px | 400 | Sans | `#555555` |
| Direct data labels | 11px | 600 (SemiBold) | Sans | Series color |
| Annotations | 11px | 400 Italic | Sans | `#707071` |
| Source/credit | 9px | 400 Italic | Sans | `#707071` |

---

## The Editorial Principles (FT, Economist, Tufte, Duarte)

These aren't arbitrary rules — each traces back to a core design principle:

### From Tufte: Maximize the data-ink ratio
- Remove every element that doesn't convey data: borders, fills, redundant labels, gridlines
- The decluttering checklist is pure Tufte — if it's not data, it should justify its existence

### From FT/Economist: Visual hierarchy through restraint
- The accent bar + serif title + muted subtitle creates a clear reading order
- The "highlight vs. context" pattern (one color + gray) focuses attention
- Direct labeling eliminates the cognitive detour of legend → data → back

### From Duarte: Story-driven titles
- Title states the insight, not the topic: "Revenue surged 40% in Q3" not "Revenue by Quarter"
- The chart should be readable without any surrounding text — the title IS the story

### From BBC: Accessible minimalism
- Horizontal gridlines only (the eye tracks along the x-axis naturally)
- High contrast text on clean backgrounds
- Colorblind-safe palette with luminance differentiation

---

## Chart Conventions (12 decisions)

### 1. Accent Bar (recommended, not mandatory)
- Small rectangle positioned above the headline, in the project's primary/theme color
- Defaults to `cat_1` (#0D7680 teal). Override via `accent_color` param.
- ~4% of chart width, ~0.6% of chart height
- Signals "editorial data viz" — differentiates from generic matplotlib
- Skip with `accent=False` for quick exploratory plots
- Handled automatically by `editorial_finish()`

### 2. Gridlines
- Horizontal only. Remove ALL vertical gridlines.
- Color: `#E4D9D0` on warm bg, `#D4D4D4` on white
- Weight: 0.5px, solid (not dashed)

### 3. Spines
- Remove top, right, and left spines
- Bottom x-axis: `#BBBBBB`, 1px
- X-axis ticks: 4px outside, `#BBBBBB` — or none

### 4. Title Hierarchy
- **Accent bar** → **serif bold title** → **sans muted subtitle** → chart
- Left-aligned, flush with chart edge — never centered
- Title: insight-driven, may wrap to 2 lines
- Subtitle: data description (units, time period, geography)
- Do NOT use `ax.set_title()` — use `editorial_finish()` for proper hierarchy

### 5. Legends
- Prefer direct labeling over legends in EVERY case
- Use `label_lines()` for line charts — labels at right endpoints in matching color
- IF legend unavoidable: horizontal, above chart, left-aligned, frameless

### 6. Color Restraint (Tufte's data-ink ratio applied to color)
- Default: focal series in `cat_1` (#0D7680), everything else in `#9B9B9B`
- Only use multiple categorical colors when comparison between series IS the story
- Never use color just because you have more series — gray out context

### 7. Background
- Chart background = page background (no separate panel fill, no box border)
- White (#FFFFFF) for notebooks/PDF, warm (#FFF1E5) for dashboards

### 8. Whitespace (Tufte: let the data breathe)
- Generous internal margins
- Title to chart: ~16px gap
- Chart to source: ~16px gap
- Spacing on 8px grid (8, 16, 24, 32, 40, 48px)
- Default aspect ratio: ~5:3 for line/bar, 4:3 for scatter

### 9. Number Formatting
- Abbreviate: K (thousands), M (millions), B (billions)
- State unit once in subtitle, drop from tick labels
- One decimal place maximum
- Right-align numbers in tables
- Remove redundant symbols (don't show % on ticks AND in axis title)

### 10. Line Charts
- 2.5px line width
- No markers unless marking specific callout points
- Direct-label at endpoints via `label_lines()`

### 11. Bar Charts
- No bar outlines (`marker_line_width=0`)
- Horizontal bars if > 5 categories
- Sort by value (not alphabetical) unless natural order exists
- Value labels via `label_bars()` or `ax.bar_label()`

### 12. Annotations (Duarte: guide the viewer)
- Annotate the ONE thing the viewer must notice
- Thin leader lines (0.5px, `#9B9B9B`)
- Annotation text: 11px italic, `#707071`

---

## Plotly Template

```python
import plotly.graph_objects as go
import plotly.io as pio

pio.templates["editorial"] = go.layout.Template(
    layout={
        "font": {"family": "Inter, IBM Plex Sans, Helvetica, sans-serif",
                 "size": 14, "color": "#222222"},
        "title": {"font": {"family": "Lora, Georgia, serif",
                           "size": 22, "color": "#222222"},
                  "x": 0, "xanchor": "left", "y": 0.95},
        "paper_bgcolor": "#FFFFFF",
        "plot_bgcolor": "#FFFFFF",
        "colorway": ["#0D7680", "#E6522C", "#2E6E9E",
                      "#AD6CAA", "#E9B237", "#379A8B"],
        "xaxis": {"showgrid": False, "showline": True,
                  "linecolor": "#BBBBBB", "linewidth": 1,
                  "tickfont": {"size": 12, "color": "#707071"},
                  "zeroline": False, "ticks": "outside",
                  "ticklen": 4, "tickcolor": "#BBBBBB"},
        "yaxis": {"showgrid": True, "gridcolor": "#D4D4D4",
                  "gridwidth": 0.5, "showline": False,
                  "tickfont": {"size": 12, "color": "#707071"},
                  "zeroline": False, "ticks": ""},
        "legend": {"orientation": "h", "yanchor": "bottom",
                   "y": 1.02, "xanchor": "left", "x": 0,
                   "font": {"size": 12}},
        "margin": {"l": 60, "r": 24, "t": 100, "b": 56},
        "hovermode": "x unified",
    },
    data={
        "bar": [go.Bar(marker_line_width=0,
                       textposition="outside",
                       textfont_size=12)],
        "scatter": [go.Scatter(line_width=2.5)],
    }
)
# Apply: pio.templates.default = "editorial"
```

### Plotly accent bar and title hierarchy

Plotly doesn't support mixed serif/sans in layout.title. Add the accent bar and subtitle as annotations:

```python
fig.add_annotation(
    x=0, y=1.12, xref="paper", yref="paper",
    text="<b>Serif headline stating the insight</b>",
    font=dict(family="Lora, Georgia, serif", size=20, color="#222222"),
    showarrow=False, xanchor="left"
)
fig.add_annotation(
    x=0, y=1.05, xref="paper", yref="paper",
    text="Data description, units, period",
    font=dict(family="Inter, Helvetica, sans-serif", size=14, color="#555555"),
    showarrow=False, xanchor="left"
)
# Accent bar as a shape (use project theme color)
fig.add_shape(
    type="line", x0=0, x1=0.06, y0=1.15, y1=1.15,
    xref="paper", yref="paper",
    line=dict(color="#0D7680", width=4)  # default teal; override per project
)
```

---

## CSS Custom Properties (D3, Observable, React)

```css
:root {
  --viz-bg:          #FFF1E5;
  --viz-accent:      var(--viz-cat-1);  /* project theme color */
  --viz-text:        #222222;
  --viz-text-muted:  #555555;
  --viz-text-light:  #707071;
  --viz-grid:        #E4D9D0;
  --viz-axis:        #BBBBBB;
  --viz-cat-1:       #0D7680;
  --viz-cat-2:       #E6522C;
  --viz-cat-3:       #2E6E9E;
  --viz-cat-4:       #AD6CAA;
  --viz-cat-5:       #E9B237;
  --viz-cat-6:       #379A8B;
  --viz-muted:       #9B9B9B;
  --viz-positive:    #2A8636;
  --viz-negative:    #CC3232;
  --viz-font-sans:   'Inter', 'IBM Plex Sans', system-ui, sans-serif;
  --viz-font-serif:  'Lora', 'Georgia', 'Times New Roman', serif;
  --viz-font-mono:   'IBM Plex Mono', monospace;
}

/* Accent bar — add to chart container ::before */
.chart-header::before {
  content: '';
  display: block;
  width: 40px;
  height: 4px;
  background: var(--viz-accent);
  margin-bottom: 8px;
}

.chart-title {
  font-family: var(--viz-font-serif);
  font-size: 20px;
  font-weight: 700;
  color: var(--viz-text);
  line-height: 1.2;
}

.chart-subtitle {
  font-family: var(--viz-font-sans);
  font-size: 14px;
  color: var(--viz-text-muted);
  margin-top: 4px;
}
```

---

## Cross-Library Notes

### Font size conversion
- matplotlib uses **points**, Plotly and CSS use **pixels**
- 1pt ≈ 1.333px at 96 DPI
- The token system standardizes on **pixels**

### Switching to warm background (dashboards)
```python
# matplotlib
plt.rcParams.update({
    "figure.facecolor": "#FFF1E5",
    "axes.facecolor": "#FFF1E5",
})
# editorial_finish() auto-detects warm bg and adjusts grid color

# plotly
fig.update_layout(paper_bgcolor="#FFF1E5", plot_bgcolor="#FFF1E5",
                  yaxis_gridcolor="#E4D9D0")
```

### Useful reference packages
- **`morethemes`**: Pre-built FT/WSJ/Economist matplotlib themes
- **`dufte`**: Tufte-inspired minimalism with inline legend labels
- **`SciencePlots`**: Composable journal-style themes

Building from your own tokens gives cross-library consistency, but these are good references.

---

## Export Settings

| Destination | DPI | Background | Notes |
|-------------|-----|------------|-------|
| Screen / notebook | 150 | #FFFFFF | Default |
| Print / PDF | 300 | #FFFFFF | Set `pdf.fonttype: 42` for TrueType embedding |
| SVG | — | #FFFFFF | Set `svg.fonttype: "none"` to keep text editable |
| Dashboard | 150 | #FFF1E5 | Warm background |
