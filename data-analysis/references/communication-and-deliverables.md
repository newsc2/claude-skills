# Communication and Deliverables Reference

Read this file when writing analysis reports, structuring presentations, creating memos, or communicating findings to stakeholders.

---

## The Pyramid Principle (use for ALL analytical communication)

Core rule: **Present the answer first, then the supporting arguments.** Research bottom-up; communicate top-down.

### Five-Step Process
1. **Start with the answer**: Identify the single main conclusion. This goes first.
2. **Support with 2-4 MECE arguments**: Each directly supports the conclusion. No overlaps, no gaps.
3. **Back each argument with 2-4 pieces of evidence**: Data points, charts, analysis results.
4. **Order ideas** at each level using: chronological, structural (by component), importance (most impactful first), or deductive (premise → premise → conclusion).
5. **Validate**: Read only top-level points — does conclusion follow? For each grouping, can you write one summary sentence? If not, restructure.

### For analysts who think bottom-up
Gather findings → group into clusters → write summary sentence for each cluster → group summaries into themes → write overarching conclusion → **FLIP and present top-down**.

---

## SCQA Framework (for framing any analysis narrative)

| Component | What it is | How to write it |
|-----------|-----------|----------------|
| **Situation** | Agreed-upon facts, stable context | State the baseline everyone knows. 1-2 sentences. |
| **Complication** | What changed, why action is needed | The tension. What broke, shifted, or surprised. |
| **Question** | The specific, decidable question | Must be within the audience's authority to act on. |
| **Answer** | Your recommendation + evidence | Lead with the action. Support with data. |

**Process**: Start with the Answer, work backward to Question, then Complication, then Situation. Read S→C→Q→A in order — it should flow as a natural story.

**Example**:
- S: "Monthly conversion rate has averaged 3.2% over the past 12 months."
- C: "In October, conversion dropped to 2.1% — a 34% decline — concentrated entirely in mobile users."
- Q: "What is causing the mobile conversion decline, and what should we do?"
- A: "The Oct 15 app update increased page load time by 2.3s on mobile. Recommend rollback. Estimated $450K/month revenue impact."

---

## Analysis Deliverable Templates

### Standard Analysis Write-Up (6 sections)
1. **Executive Summary** (write last, place first): BLUF — conclusion, key finding, recommended action, expected impact. 3-5 sentences.
2. **Business Context**: Why this analysis exists. What decision it informs. Who asked and why now.
3. **Methodology**: Data sources, time period, approach, key assumptions. Enough for someone to reproduce.
4. **Findings**: Insights organized by priority (not chronology). Each finding = statement + supporting evidence + visualization. Apply Pyramid Principle within this section.
5. **Recommendations**: Specific next steps with: owner, timeline, expected impact, and how to measure success.
6. **Appendix**: Detailed tables, sensitivity analyses, code, methodology deep-dives. Reference from main body but don't clutter it.

### Amazon 6-Pager Format (for major analyses)
- Introduction: analytical question + why it matters (~0.5 page)
- Goals: KPIs and success criteria (~0.5 page)
- Tenets: analytical assumptions and principles (~0.5 page)
- State of the Business: current metrics snapshot (~1.5 pages)
- Lessons Learned: key findings, root causes, surprises (~1.5 pages)
- Strategic Priorities: ranked recommendations + implementation roadmap (~1.5 pages)
- Appendix: unlimited

Key principle: narrative prose, no bullet points. Forces deeper thinking about causes and effects.

### A/B Test Report
**Pre-experiment section**: hypothesis, experimental design, sample size calculation, primary + guardrail metrics, pre-committed decision rules.
**Post-experiment section**: SRM check, primary KPI per variant (lift %, CI, p-value), secondary metrics, segment breakdowns, practical significance assessment, decision, learnings.

Critical: Define what outcomes lead to what decisions BEFORE seeing results.

---

## Slide Design for Data Presentations

### The Consulting Slide Anatomy
Every analytical slide has three parts:
1. **Action title** (top): A complete sentence stating the conclusion. NOT a topic label.
   - Bad: "Revenue Analysis"
   - Good: "Revenue grew 15% YoY driven by digital channel expansion"
2. **Visual evidence** (body): One chart or table proving the action title.
3. **Source footer**: Data source, date range, methodology notes.

**Acid test**: Read only the action titles across the full deck. They should tell the complete story.

### The Ghost Deck Method
1. Write all action titles as a text outline.
2. Read titles in sequence — does the argument flow logically?
3. Rearrange until the storyline works.
4. Only THEN design individual slides with supporting visuals.

### Slide Types
- **Assertion slide**: Action title + single chart proving it. Most common.
- **Comparison slide**: Side-by-side charts or tables. Use for before/after, option A vs B.
- **Framework slide**: Conceptual diagram (2x2 matrix, process flow, issue tree). Use to structure thinking.
- **Data table slide**: When exact numbers matter more than visual patterns. Keep to ≤ 7 rows × 5 columns.
- **Executive summary slide**: 3-5 bullet points, each a complete sentence (action title format). Opening or closing slide.

### Slidedocs vs Presentations
- **Slidedocs** (~100 words/slide): Designed to be READ. Detailed, self-contained. Send ahead of meetings.
- **Presentation slides** (~30 words/slide): Designed to ACCOMPANY a speaker. Visual, minimal text.
- Never present a Slidedoc live. Never distribute a presentation slide without context.

---

## Communicating Uncertainty

### Calibrated Language
| Confidence | Language |
|-----------|---------|
| > 95% | "The data clearly shows..." / "We are confident that..." |
| 80-95% | "The evidence strongly suggests..." / "It is likely that..." |
| 60-80% | "The data suggests..." / "It appears that..." |
| 40-60% | "Preliminary indications suggest..." / "It is possible that..." |
| < 40% | "There is limited evidence..." / "We cannot rule out..." |

### Techniques for Non-Technical Audiences
- **Scenario tables**: Pessimistic / Base / Optimistic columns showing key assumptions, outputs, and implied actions for each.
- **Tornado charts**: Horizontal bars showing sensitivity of output to each input, ordered most → least impactful. Focuses discussion on what matters.
- **Ranges over point estimates**: "$3-5 million" not "$4,237,891." False precision erodes trust.
- **Natural language**: "range of likely values" not "confidence interval." "High confidence" not "p < 0.05."
- **Visual uncertainty**: Error bars, shaded confidence bands on time series, fan charts for forecasts.

---

## Narrative Frameworks

### ABT (And, But, Therefore)
The simplest story structure for data:
- **And** (context): "Revenue has been growing steadily, AND we launched in 3 new markets..."
- **But** (tension): "BUT customer acquisition cost has doubled in Q3..."
- **Therefore** (resolution): "THEREFORE we recommend pausing expansion and optimizing existing markets first."

The anti-pattern is "And, And, And" — just listing facts with no narrative tension. This is the most common failure mode in data presentations.

### Data Storytelling Formula
**Data + Narrative + Visuals** combined for maximum impact. Any two without the third is weaker:
- Data + Visuals (no narrative) = dashboards that inform but don't persuade
- Narrative + Visuals (no data) = anecdotes that persuade but aren't credible
- Data + Narrative (no visuals) = reports that inform but don't engage

---

## Writing Style for Analysis

- **BLUF** (Bottom Line Up Front): Conclusion first, evidence second. Always.
- **Active voice**: "Revenue dropped 12%" not "A 12% drop in revenue was observed."
- **Specific over vague**: "Mobile conversion fell 34% after the Oct 15 deploy" not "There were some issues with conversion."
- **Quantify everything**: "Significant" means nothing without a number. "Large" means nothing without context.
- **One idea per paragraph/slide**: If you need a transition word ("however", "additionally"), you likely need a new section.
- **Assume the reader will only read the first sentence of each section.** Make those sentences count.
