---
name: data-design
description: "Use this skill whenever creating any data visualization, chart, dashboard, or graphical data output. Triggers include: any matplotlib, plotly, seaborn, altair, D3, or Observable chart creation; Streamlit dashboard styling; React/HTML data artifacts; chart styling or theming requests; KPI displays; any request mentioning 'make it look good', 'editorial style', 'FT style', 'clean charts', or 'professional visualization'. Also trigger when the user asks to style, theme, format, or improve the appearance of any data output. Apply this design system by default to ALL chart and visualization code unless the user specifies a different style."
---

# Editorial Data Visualization Design System

Enforces editorial-quality output (FT, Economist, Tufte, Duarte) across all charts and data graphics. Apply by default.

## Architecture

| Task | Reference File |
|------|---------------|
| Color deep-dive (palettes, ramps, accessibility) | `references/color-system.md` |
| Plotly/CSS templates, font setup, cross-library notes | `references/styling-and-implementation.md` |

The **composition helpers** below are the core of this skill. They MUST be used.

---

## CRITICAL: Why Charts Look Amateur Without Composition

Applying tokens (nice colors, font sizes) is necessary but NOT sufficient. Editorial quality comes from **structural elements working as a complete composition**. Without them, charts look like "matplotlib with nice colors" — not editorial.

### Chart Anatomy

```
 ▬▬▬▬                                              ← 1. ACCENT BAR (project theme color)
 Bold serif headline that                           ← 2. TITLE (serif, bold, 18pt)
 states the insight clearly                            insight-driven, not descriptive

 What the data shows, units, period                 ← 3. SUBTITLE (sans, 13pt, #555555)

 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  40
                            ____  Series A          ← 4. DATA AREA
 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  20                  (h-gridlines only, #D4D4D4)
              ______________  Series B                 (direct labels, no legend box)
 ──────────────────────────────────                    (bottom spine only)
  2018    2019    2020    2021    2022

 Source: Data provider                   Your Name  ← 5+6. SOURCE left, CREDIT right
```

**For matplotlib**: Call `editorial_finish()` on every chart (defined below).
**For Plotly**: Use editorial template + annotations (see `references/styling-and-implementation.md`).

---

## 11 Non-Negotiable Defaults

1. **Accent bar** (recommended): Small rectangle above headline in the project's primary color (`cat_1` by default). Adds editorial polish — use on most charts, skip for quick exploratory plots.
2. **Title font**: SERIF (Lora → Georgia), bold, left-aligned — NEVER sans-serif for headlines
3. **Title content**: States the INSIGHT ("Revenue surged 40%"), not topic ("Revenue by Quarter")
4. **Subtitle**: Sans-serif, regular weight, `#555555` — data description (units, period, geography)
5. **Background**: `#FFFFFF` for notebooks/PDF; `#FFF1E5` for dashboards/web
6. **Text color**: `#222222` titles, `#707071` labels — never pure `#000000`
7. **First series**: `#0D7680` (teal), always
8. **Gridlines**: horizontal only, `#D4D4D4` (or `#E4D9D0` on warm bg), 0.5px
9. **Spines**: bottom only, `#BBBBBB`, 1px — remove top, right, left
10. **Legend**: Direct-label at endpoints. Remove legend box whenever possible.
11. **Source**: 9px, `#707071`, italic, bottom-left. Optional credit bottom-right.

---

## Matplotlib: Base rcParams (apply once per notebook)

```python
import matplotlib.pyplot as plt
from cycler import cycler

EDITORIAL_RCPARAMS = {
    # Font stacks — serif stack is critical for title rendering
    "font.family": "sans-serif",
    "font.sans-serif": ["Inter", "IBM Plex Sans", "Helvetica", "Arial"],
    "font.serif": ["Lora", "Georgia", "Times New Roman", "serif"],
    "font.size": 12,
    "text.color": "#222222",
    # Background (white for notebooks — override to #FFF1E5 for dashboards)
    "figure.facecolor": "#FFFFFF",
    "axes.facecolor": "#FFFFFF",
    "savefig.facecolor": "#FFFFFF",
    # Grid — minimal by default; editorial_finish fine-tunes per axis
    "axes.grid": False,
    # Spines
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.spines.left": False,
    "axes.edgecolor": "#BBBBBB",
    "axes.linewidth": 1.0,
    # Color cycle
    "axes.prop_cycle": cycler("color", [
        "#0D7680", "#E6522C", "#2E6E9E", "#AD6CAA", "#E9B237", "#379A8B"
    ]),
    # Lines
    "lines.linewidth": 2.5,
    # Figure
    "figure.figsize": (10, 6),
    "figure.dpi": 150,
    "savefig.dpi": 300,
    # Export
    "pdf.fonttype": 42,
    "svg.fonttype": "none",
    # Legend (fallback if direct labeling not possible)
    "legend.frameon": False,
}

plt.rcParams.update(EDITORIAL_RCPARAMS)
```

NOTE: Do NOT use `ax.set_title()` — the composition helper handles all text placement with proper serif/sans hierarchy. The rcParams `font.family` is sans-serif (correct for labels/ticks); title uses serif via explicit `fontfamily="serif"` in `fig.text()`.

---

## Matplotlib: Composition Helpers (MUST USE)

### `editorial_finish()` — the core function

Call on EVERY chart after plotting data, before `plt.show()` or `savefig()`.
Do NOT use `tight_layout()` or `constrained_layout` — this function manages spacing.

```python
def editorial_finish(fig, ax, title, subtitle=None, source=None,
                     credit=None, accent_color="#0D7680", accent=True):
    """Apply editorial-style composition to a matplotlib chart.
    accent_color: defaults to cat_1 (teal). Set to project theme color.
    accent: set False to skip the accent bar (e.g. quick exploratory plots).
    """
    left, right = 0.10, 0.92

    # ── Dynamic title block positioning ──
    n_title_lines = title.count('\n') + 1
    accent_y = 0.96
    title_y = (accent_y - 0.018) if accent else accent_y
    subtitle_y = title_y - (n_title_lines * 0.05) - 0.012
    if subtitle:
        axes_top = subtitle_y - 0.05
    else:
        axes_top = title_y - (n_title_lines * 0.05) - 0.03
    fig.subplots_adjust(top=axes_top, bottom=0.10, left=left, right=right)

    # ── Detect background for grid color ──
    bg = fig.get_facecolor()
    is_warm = bg[0] > 0.95 and bg[1] < 0.96 and bg[2] < 0.92
    grid_color = "#E4D9D0" if is_warm else "#D4D4D4"

    # ── Accent bar (project theme color) ──
    if accent:
        fig.add_artist(plt.Rectangle(
            (left, accent_y), 0.04, 0.006,
            transform=fig.transFigure,
            facecolor=accent_color, edgecolor="none", clip_on=False
        ))

    # ── Title: serif, bold ──
    fig.text(left, title_y, title,
             fontsize=18, fontweight="bold", fontfamily="serif",
             color="#222222", ha="left", va="top", linespacing=1.2)

    # ── Subtitle: sans, muted ──
    if subtitle:
        fig.text(left, subtitle_y, subtitle,
                 fontsize=13, fontfamily="sans-serif",
                 color="#555555", ha="left", va="top")

    # ── Source + credit ──
    if source:
        fig.text(left, 0.025, f"Source: {source}",
                 fontsize=9, color="#707071", fontfamily="sans-serif",
                 fontstyle="italic", ha="left", va="bottom")
    if credit:
        fig.text(right, 0.025, credit,
                 fontsize=9, color="#707071", fontfamily="sans-serif",
                 fontstyle="italic", ha="right", va="bottom")

    # ── Declutter axes ──
    for spine in ["top", "right", "left"]:
        ax.spines[spine].set_visible(False)
    ax.spines["bottom"].set_color("#BBBBBB")
    ax.spines["bottom"].set_linewidth(1)
    ax.tick_params(axis="y", left=False, labelcolor="#707071", labelsize=11)
    ax.tick_params(axis="x", direction="out", length=4, color="#BBBBBB",
                   labelcolor="#707071", labelsize=11)
    ax.yaxis.grid(True, color=grid_color, linewidth=0.5)
    ax.xaxis.grid(False)
    ax.set_axisbelow(True)
    ax.set_title("")
    ax.set_xlabel("")
    ax.set_ylabel("")
```

### `label_lines()` — direct labeling at endpoints

The single most impactful editorial technique. Eliminates legend boxes entirely.

```python
def label_lines(ax, offset_x=8, fontsize=11, fontweight="semibold"):
    """Direct-label every line at its right endpoint. Hides the legend."""
    for line in ax.get_lines():
        label = line.get_label()
        if label.startswith("_"):
            continue
        xd, yd = line.get_xdata(), line.get_ydata()
        ax.annotate(label, xy=(xd[-1], yd[-1]),
                    xytext=(offset_x, 0), textcoords="offset points",
                    fontsize=fontsize, fontweight=fontweight,
                    color=line.get_color(), va="center",
                    annotation_clip=False)
    leg = ax.get_legend()
    if leg:
        leg.set_visible(False)
```

### `label_bars()` — value labels on bar charts

```python
def label_bars(ax, fmt="{:.0f}", padding=4, fontsize=11, color="#555555"):
    """Add value labels to the end of each bar. Works with barh and bar."""
    for container in ax.containers:
        ax.bar_label(container, fmt=fmt, padding=padding,
                     fontsize=fontsize, color=color)
```

---

## Design Tokens (quick reference)

```python
COLORS = {
    "bg_warm": "#FFF1E5", "bg_white": "#FFFFFF",
    "accent": "#0D7680",  # same as cat_1; override per project
    "text": "#222222", "text_muted": "#555555", "text_light": "#707071",
    "grid": "#D4D4D4", "grid_warm": "#E4D9D0", "axis": "#BBBBBB",
    "cat_1": "#0D7680", "cat_2": "#E6522C", "cat_3": "#2E6E9E",
    "cat_4": "#AD6CAA", "cat_5": "#E9B237", "cat_6": "#379A8B",
    "muted": "#9B9B9B",
    "positive": "#2A8636", "negative": "#CC3232", "highlight": "#E9B237",
}

SEQUENTIAL_TEAL = ["#E0F0F1", "#9DD4D7", "#4FAFB4", "#0D7680", "#064044"]
SEQUENTIAL_WARM = ["#FBEADF", "#F2BFA0", "#EC8D5B", "#E6522C", "#7A2B17"]
DIVERGING = ["#0D7680", "#5EA5A0", "#AFD4C0", "#F0ECE8", "#F2BFA0", "#EC8D5B", "#E6522C"]
```

---

## Decision Logic

### Color
```
1 series           → cat_1 (teal)
2 series           → cat_1 + cat_2
Highlight vs rest  → cat_1 focus + #9B9B9B for context (THE key FT pattern)
3-6 series         → cat_1 through cat_N in order
>6 series          → reconsider (small multiples, top-N + "Other")
Positive/negative  → #2A8636 / #CC3232
Magnitude/density  → teal sequential ramp
Divergence         → teal-to-red diverging ramp
```

### Chart type
```
Line    → 2.5px, no markers, label_lines() at endpoints, remove legend
Bar     → no outlines, sort by value, horizontal if >5 categories, label_bars()
Scatter → 6px markers, 70% opacity, 4:3 aspect ratio
Table   → right-align numbers, tabular figures (tnum), alternating #F2EDEB rows
```

### Background
```
Jupyter notebook  → #FFFFFF
Streamlit / web   → #FFF1E5
PDF / slides      → #FFFFFF
```

---

## Complete Example (copy-paste into a notebook)

```python
import matplotlib.pyplot as plt
from cycler import cycler

# ── 1. Apply rcParams (once per notebook) ──
plt.rcParams.update(EDITORIAL_RCPARAMS)  # from above

# ── 2. Plot data ──
fig, ax = plt.subplots()
years = range(2018, 2024)
growth = [2.1, 1.8, 2.3, -3.4, 5.9, 2.1]
trend  = [2.0, 2.0, 2.0,  2.0, 2.0, 2.0]

ax.plot(years, growth, color="#0D7680", label="GDP growth")
ax.plot(years, trend,  color="#9B9B9B", label="2% target", linestyle="--")
ax.axhline(0, color="#BBBBBB", linewidth=0.5, zorder=0)

# ── 3. Direct-label lines ──
label_lines(ax)

# ── 4. Apply editorial composition ──
editorial_finish(fig, ax,
    title="The post-pandemic recovery has\nsettled into modest growth",
    subtitle="US GDP growth, annual %, seasonally adjusted",
    source="Bureau of Economic Analysis")

plt.show()
```

---

## Decluttering Checklist

Automated by `editorial_finish()`. Verify manually only for custom builds:

1. Top/right/left spines removed
2. Vertical gridlines removed
3. No markers on lines (unless specific callout)
4. Tick frequency reduced if crowded (every 2nd/5th label)
5. Axis titles removed (subtitle explains units)
6. Legend replaced with direct labels
7. Non-focal series grayed (`#9B9B9B`)
8. No redundant unit labels (% on ticks AND axis title)
9. Numbers abbreviated (K/M/B), unit stated once in subtitle
10. Title states the insight, not just the variables
