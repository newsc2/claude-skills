# Dashboards and Visualization Reference

Read this file when building dashboards, choosing chart types, designing KPIs, or creating any data visualization.

---

## Chart Selection Decision Tree

Start with: "What do I want to show?"

### Comparison
```
IF comparing items at a point in time:
  ≤ 5 categories → Vertical bar chart
  > 5 categories → Horizontal bar chart (labels read naturally)
  Comparing to a target → Bullet chart (Few's design)

IF comparing over time:
  ≤ 12 time periods → Column chart (grouped or stacked)
  > 12 time periods → Line chart
  Multiple series + need to compare levels → Line chart
  Multiple series + need to compare composition → Stacked area
```

### Distribution
```
Single variable → Histogram (continuous) or bar chart (categorical)
Two variables → Scatter plot
Three variables → Bubble chart (3rd variable = size)
Distribution comparison across groups → Box plot or violin plot
```

### Composition (parts of a whole)
```
Static snapshot:
  ≤ 5 parts → Pie chart (only acceptable use case) or donut
  > 5 parts → Treemap
  Showing accumulation/waterfall → Waterfall chart

Over time:
  Relative shares → 100% stacked area
  Absolute values → Stacked area chart
```

### Relationship
```
Two variables → Scatter plot
Three variables → Bubble chart
Correlation matrix → Heatmap
```

### Flow & Change
```
Movement between states → Sankey diagram
Rank changes over time → Slope chart / bump chart
Variance from reference point → Diverging bar chart
Geographic patterns → Choropleth map
```

### Single KPI Display
```
Current value vs target → Big number + comparison indicator
Current value + trend → Big number + sparkline
Value on a scale → Gauge (use sparingly) or bullet chart
```

### Universal Anti-Patterns — NEVER use:
- **3D charts** — universally condemned, distort perception
- **Pie charts with > 5 slices** — human eyes compare angles poorly
- **Dual-axis charts** — imply false correlations. Use two aligned charts instead.
- **Truncated y-axes on bar charts** — exaggerates differences. (Acceptable on line charts if clearly labeled.)
- **Rainbow color schemes** — not perceptually uniform, unreadable in B&W

---

## Dashboard Layout

### Layout by Audience
```
IF audience = executive/C-suite:
  → Z-Pattern: KPIs top-left to top-right, detail bottom
  → Single screen, no scrolling
  → 5-7 metrics maximum
  → KPI cards at top, sparklines for trend context

IF audience = operational managers:
  → F-Pattern: horizontal scan top, then vertical left column
  → Scrollable with clear sections
  → Real-time data with alert thresholds
  → Filters for their scope (region, team, product)

IF audience = analysts:
  → Grid layout with tabs/pages
  → Heavy interactivity: filters, brushing, drill-down
  → Access to underlying data tables
  → Cross-filtering between charts
```

### Progressive Disclosure (apply to ALL dashboards)
- **Level 1** (always visible): KPI cards, sparklines, status indicators. User gets the headline in 5 seconds.
- **Level 2** (hover/click): Tooltips with exact values, period comparisons, % change.
- **Level 3** (drill-down): Full chart views, data tables, segment breakdowns.

### Visual Hierarchy Principles
- Place most important information **top-left** (Z-pattern eye tracking)
- Use **pre-attentive attributes** sparingly: color hue, size, spatial position, orientation. Brain processes these in <250ms. Limit to ~5 distinct pieces.
- Apply **Gestalt principles**: proximity (group related charts), similarity (consistent colors for same metric), enclosure (borders/backgrounds to create sections).
- **5-second rule**: Main message identifiable within 5 seconds of viewing.
- Tufte's **data-ink ratio**: maximize proportion of ink devoted to actual data. Remove chartjunk, redundant labels, decorative elements.

---

## KPI Design Checklist

Before defining any KPI, it must pass these checks:

1. **What business question does it answer?**
2. **Who uses it and what decision does it inform?**
3. **What action follows if it goes up? Goes down?** (If no action → it's not a KPI, it's a vanity metric.)
4. **Is it a rate/ratio or a raw count?** (Prefer rates — they're more actionable and comparable.)
5. **Is it a leading or lagging indicator?** Every lagging indicator (revenue, churn) needs 1-2 paired leading indicators (activation rate, NPS) that predict it.
6. **What is the baseline?** What does "normal" look like?
7. **What threshold = danger?** Define red/yellow/green.
8. **Does it have a counter-metric?** (Optimizing conversion? Watch customer satisfaction. Optimizing speed? Watch quality. This prevents the "squeeze toy effect.")
9. **Can it be gamed?** Run a Goodhart's Law pre-mortem: "If someone optimized only this number, what bad behavior would result?"
10. **Limit to 5-9 primary KPIs per dashboard.**

### Good Metric Properties (from Lean Analytics)
A good metric is: comparative (shows change), understandable (people recall its definition), a ratio or rate (not an absolute number), and behavior-changing (seeing it triggers action).

---

## Self-Serve vs. Curated Decision

```
IF questions are well-defined + recurring + stable → CURATED dashboard
IF questions vary frequently + exploratory → SELF-SERVICE
IF audience = C-suite → CURATED (headlines, not exploration)
IF audience = analysts → SELF-SERVICE (ad-hoc exploration)
IF no semantic layer / metric governance → CURATED only
  (Self-service without governance = everyone defines "revenue" differently)
IF semantic layer + documented warehouse + trained users → SELF-SERVICE viable
```

Most orgs need both: curated KPI dashboards for monitoring + self-service layer for exploration. Prerequisite for self-service: governed semantic layer with centralized metric definitions.

---

## Dashboard Build Process

1. **Clarify purpose**: Monitoring, analysis, or communication? Who's the audience?
2. **Define metrics**: Apply KPI checklist above. Get stakeholder sign-off on metric definitions.
3. **Wireframe on paper/whiteboard**: Layout, information hierarchy, interaction model. Get feedback BEFORE building.
4. **Data model**: Ensure data sources support all needed aggregations, filters, time ranges. Validate joins and grain.
5. **Build MVP**: Core metrics only. No polish. Validate data accuracy against known benchmarks.
6. **Iterate with users**: Show real data. Gather feedback on what's missing, confusing, or unused.
7. **Polish**: Color, typography, spacing, labels, tooltips, mobile responsiveness.
8. **Document**: Data sources, refresh schedule, metric definitions, known limitations, owner.

---

## Tool-Agnostic Implementation Notes

When building visualizations in code (Python, JS, etc.):

### Color
- Use sequential palettes for ordered data (light → dark)
- Use diverging palettes for data with meaningful midpoint
- Use categorical palettes for unordered groups (limit to ~7 distinct colors)
- Always check colorblind accessibility (use Viridis, Cividis, or ColorBrewer palettes)
- Use color strategically to highlight — not decorate. Gray everything except what matters.

### Typography
- Dashboard titles: 16-20px, bold
- Section headers: 14-16px, semibold
- Chart titles: 12-14px, should state the insight not the topic ("Revenue grew 12% QoQ" not "Revenue")
- Labels and axes: 10-12px
- Consistent font throughout

### Spacing
- Consistent padding between charts (16-24px)
- White space is not wasted space — it creates visual grouping
- Align charts to a grid
