---
name: data-analysis
description: "Use this skill for any data analysis task: exploratory analysis, statistical testing, metric design, business analysis, dashboard creation, data storytelling, or analytical deliverables. Triggers include: analyzing datasets, answering business questions with data, building dashboards or visualizations, writing analysis reports/memos, designing KPIs or metrics, A/B test analysis, cohort analysis, funnel analysis, market sizing, forecasting, or any request involving structured analytical thinking. Also use when the user asks to 'look at the data', 'investigate why X changed', 'build a dashboard', 'write up findings', or 'help me think through this analytically'. Do NOT use for pure data engineering (ETL pipelines, schema migrations) or ML model training — those have separate skills."
---

# Data Analysis Skill

This skill enforces structured analytical thinking across all data analysis work. It covers the full lifecycle from problem framing through delivery.

## Architecture

This skill has three reference files for deep guidance. Read the relevant one(s) BEFORE writing code or producing outputs:

| Task | Reference File |
|------|---------------|
| EDA, statistical tests, hypothesis testing, A/B tests, forecasting, causal inference | `references/eda-and-statistics.md` |
| Dashboards, chart selection, KPI design, any visualization | `references/dashboards-and-visualization.md` |
| Analysis write-ups, presentations, memos, communicating findings | `references/communication-and-deliverables.md` |

Many tasks require multiple references (e.g., "analyze this data and present findings" → read eda-and-statistics.md AND communication-and-deliverables.md).

---

## Pre-Flight Checklist (ALWAYS run before any analysis)

Before writing ANY analytical code, answer these questions. If the user hasn't provided enough context, ask — but only ask what changes the approach.

### 1. Problem Framing
- **Business question**: What specific question are we answering? Restate it precisely.
- **Decision**: What decision or action depends on this analysis?
- **Analysis type**: Classify using this logic:
  ```
  "How many / what is the rate / what happened?" → DESCRIPTIVE
  "Why did [metric] change?" → DIAGNOSTIC  
  "What will happen next?" → PREDICTIVE
  "What should we do?" → PRESCRIPTIVE
  ```
  Note: each level requires the one below it. If descriptive analytics aren't solid, start there.

### 2. Hypothesis Formation
- Form an initial hypothesis BEFORE exploring data: "I believe [X] is primarily driven by [Y]."
- Identify 2-4 sub-hypotheses that must be true for the main hypothesis to hold.
- For each sub-hypothesis, identify the specific data needed to test it.
- This is the work plan. Do NOT open-endedly explore.

### 3. Scope Check
- What time period? What segments? What granularity?
- What data sources are available? Known quality issues?
- What deliverable format is expected?
- What precision is needed — directional or exact?

---

## MECE Decomposition (use for any complex question)

When decomposing a business problem, apply MECE (Mutually Exclusive, Collectively Exhaustive):

1. **Define** the problem as a single sentence.
2. **Decompose** using one strategy:
   - Mathematical identity (Revenue = Price × Volume)
   - Binary split (Internal vs External factors)
   - Process steps (Awareness → Consideration → Purchase → Retention)
   - Stakeholder segmentation
   - Standard framework (Porter's 5 Forces, AARRR, etc.)
3. **Validate**: Does any item fit in two buckets? (→ redraw boundaries). Is anything uncovered? (→ add category). If branches sum to a known total, strong confirmation.
4. **Recurse**: Expand high-impact branches, collapse low-impact ones. Stop when branches are directly testable with data.

---

## Hypothesis-Driven Workflow

Follow this cycle for all analytical work beyond simple data pulls:

```
1. FORM hypothesis → "I believe [cause] because [reasoning]"
2. BUILD hypothesis tree → "For this to be true, [A], [B], and [C] must hold"
3. PRIORITIZE → Test highest-impact branches first (80/20)
4. TEST with data → For each branch: Supported / Refuted / Ambiguous
5. ITERATE:
   - IF confirmed → drill deeper into that branch
   - IF refuted → pivot to next hypothesis
   - IF ambiguous → seek additional data or reframe
   - IF ~80% certainty → stop refining, present findings
```

---

## Cognitive Bias Checks (run before finalizing ANY analysis)

Before presenting conclusions, run these checks:

- **Confirmation bias**: Can you build an opposing case with the same data? If not, try harder. Ask: "What evidence would disprove this?"
- **Survivorship bias**: What was excluded from the dataset? (Churned users, failed products, rejected applicants.) Would including them change the conclusion?
- **Simpson's Paradox**: Re-run analysis on major subgroups. If trends reverse → investigate before reporting aggregates.
- **Anchoring**: Did the conclusion match your initial estimate suspiciously closely? Run sensitivity analysis with different starting assumptions.
- **P-hacking**: Did you run multiple tests? Report ALL of them. Apply Benjamini-Hochberg correction. If the result only emerged after trying variations → treat as hypothesis-generating, not confirmatory.
- **Causation vs correlation**: For any causal claim, identify confounders, consider reverse causality, and consider omitted variables.

---

## The "So What" Test

Every finding must answer: "If a stakeholder receives this, what should they do differently?"

Bad: "Conversion rate dropped 2 percentage points."
Good: "Conversion dropped 2pp driven by mobile checkout errors introduced Oct 15. Recommend immediate rollback — estimated $450K/month impact."

Format: **[What happened] + [Why] + [Recommended action] + [Estimated impact]**

---

## Pre-Delivery QA Checklist

Before delivering any analysis:

- [ ] Row counts match expectations
- [ ] Date ranges are correct and consistent
- [ ] No unexpected duplicates
- [ ] Join row counts validated (did joins create or lose rows?)
- [ ] Totals add up; percentages sum correctly where applicable
- [ ] YoY/MoM changes make sense given known business events
- [ ] Units are consistent throughout
- [ ] Edge cases handled (divide-by-zero, zero-count segments)
- [ ] Key metrics cross-checked against existing reports
- [ ] Confidence intervals or uncertainty ranges reported where applicable
- [ ] Assumptions documented
- [ ] Visualizations labeled correctly, not misleading
- [ ] Narrative matches the data
- [ ] Deliverable format matches what was requested

---

## Post-Analysis (when applicable)

For significant analyses, document:
- Did the analysis answer the original question?
- What decision was taken as a result?
- What would you do differently next time?
- Any reusable assets created (queries, templates, frameworks)?
