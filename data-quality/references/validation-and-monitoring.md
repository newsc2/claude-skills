# Validation and Monitoring Reference

Read this file when building validation suites, anomaly detection, freshness/volume monitoring, data tests, or alert systems.

---

## Building a Validation Suite

### Step 1: Inventory Critical Tables
Rank tables by blast radius (number of downstream consumers × business impact). Start with top 3–5 tables.

### Step 2: Apply the Check Hierarchy
For each table, add checks in this order. Stop when ROI diminishes:

```
LAYER 1 — Existence (does it exist, is it fresh, does it have data):
  - Table exists and is queryable
  - Row count > 0
  - MAX(timestamp_col) within freshness SLA
  - Row count within ±20% of rolling 7-day average

LAYER 2 — Structure (is the shape right):
  - Primary key unique + not null
  - Expected columns present with correct types
  - No unexpected new columns (schema drift)

LAYER 3 — Completeness (are values populated):
  - Null rate per column within threshold
  - Required fields have zero nulls
  - Foreign keys reference valid parent records

LAYER 4 — Validity (are values reasonable):
  - Values within expected ranges (amounts > 0, dates not in future)
  - Categorical columns contain only accepted values
  - Format checks (email regex, phone patterns, URL structure)
  - Cross-column consistency (end_date >= start_date)

LAYER 5 — Accuracy (does it match reality):
  - Aggregates reconcile with source system totals
  - Known invariants hold (debits = credits, parts sum to whole)
  - Spot-check samples against manual verification
```

### Step 3: Choose Framework

```
IF dbt project → implement as dbt tests in schema.yml:
  Layer 1–2: built-in tests (unique, not_null) + dbt-utils (equal_rowcount)
  Layer 3: custom generic tests or dbt-expectations
  Layer 4: dbt-expectations (expect_column_values_to_be_between, etc.)
  Layer 5: singular tests (custom SQL assertions)
  Anomaly detection: Elementary package
  Schema enforcement: model contracts (contract.enforced: true)

IF Python pipeline → implement with Pandera:
  Define DataFrameModel with column types, Check decorators, nullable flags
  Use @check_types decorator on transform functions
  strict=True to reject extra columns
  Coerce=True for automatic type casting (use cautiously)

IF lightweight / ad-hoc → build a check runner:
  Each check = SQL query expected to return 0 rows on success
  Chain checks with severity levels
  Output structured JSON results
```

---

## Anomaly Detection for Metrics

### Choosing a Detection Method

```
IF metric is stable with clear bounds → static thresholds
  Example: "order amounts must be $0.01–$50,000"

IF metric has natural variation but no seasonality → rolling Z-score
  z = (value - rolling_mean) / rolling_std
  Window: 14–30 days. Alert threshold: |z| > 3.
  Use modified Z-score (MAD-based) if outliers are common.

IF metric has weekly/monthly seasonality → STL decomposition
  Decompose with statsmodels STL(period=7 for daily data)
  Alert on residual > 3σ
  Handles holidays and trend changes better than raw Z-score

IF metric is a proportion or rate → use beta distribution bounds
  Model rate as Beta(successes, failures)
  Alert if outside 99% credible interval

IF multivariate anomaly needed → Isolation Forest
  scikit-learn IsolationForest(contamination=0.01–0.05)
  Feed multiple related metrics as features
  Good for catching subtle multi-dimensional shifts

IF you need adaptive baselines → Prophet
  Set interval_width=0.99 for anomaly bounds
  Best for metrics with multiple seasonality + holidays
  Overkill for simple checks; reserve for high-value metrics
```

### Distribution Drift Detection

```
USE CASE: detecting if a column's distribution changed between periods

PSI (Population Stability Index):
  < 0.1 → no significant drift
  0.1–0.2 → moderate drift, investigate
  > 0.2 → significant drift, alert
  Best for: production monitoring of feature distributions

KS test (Kolmogorov-Smirnov):
  p < 0.05 → distributions differ significantly
  Sensitive with large samples (will flag trivial differences)
  Best for: comparing two specific dataset versions

Jensen-Shannon divergence:
  Symmetric, bounded [0, 1], interpretable
  Best for: comparing categorical distributions
```

---

## Freshness Monitoring

### Implementation Pattern

```sql
-- Generic freshness check
WITH freshness AS (
  SELECT
    MAX(updated_at) AS last_update,
    CURRENT_TIMESTAMP - MAX(updated_at) AS staleness,
    COUNT(*) AS row_count
  FROM target_table
)
SELECT *
FROM freshness
WHERE staleness > INTERVAL '2 hours'  -- adjust per table SLA
   OR row_count = 0;
```

### Setting Freshness SLAs

```
Real-time operational data → < 15 minutes
Daily batch pipelines → < 4 hours after expected completion
Weekly aggregations → < 24 hours after expected completion
Reference/dimension data → < 7 days

ALWAYS set freshness relative to expected update schedule, not wall clock.
IF table updates daily at 6am → alert if MAX(updated_at) < today 10am (4hr buffer).
```

---

## Volume Monitoring

### Detecting Volume Anomalies

```
SIMPLE: Compare to yesterday / last week same day
  IF |today - yesterday| / yesterday > 0.20 → WARNING
  IF today = 0 → CRITICAL

ROBUST: Compare to rolling baseline with day-of-week adjustment
  expected = AVG(same_weekday, last 4 weeks)
  IF |actual - expected| / expected > 0.25 → WARNING
  IF |actual - expected| / expected > 0.50 → CRITICAL

SQL pattern:
  WITH daily_counts AS (
    SELECT DATE(created_at) AS dt, COUNT(*) AS n
    FROM table
    GROUP BY 1
  ),
  baselines AS (
    SELECT dt, n,
      AVG(n) OVER (
        ORDER BY dt
        ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING
      ) AS rolling_avg
    FROM daily_counts
  )
  SELECT dt, n, rolling_avg,
    ABS(n - rolling_avg) / NULLIF(rolling_avg, 0) AS pct_deviation
  FROM baselines
  WHERE ABS(n - rolling_avg) / NULLIF(rolling_avg, 0) > 0.25;
```

---

## dbt Test Configuration Patterns

### Severity and Conditional Execution

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: amount
        tests:
          - not_null:
              severity: error
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100000
              severity: warn
              # Graduated: warn on range violations, error on nulls
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'completed', 'cancelled', 'refunded']
              config:
                where: "created_at >= CURRENT_DATE - INTERVAL '90 days'"
                # Only check recent data — old data may have legacy values
```

### Unit Tests for Transform Logic (dbt 1.8+)

```yaml
unit_tests:
  - name: test_revenue_calculation
    model: fct_orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, subtotal: 100.00, tax_rate: 0.08, discount: 10.00}
    expect:
      rows:
        - {order_id: 1, revenue: 98.00}  # (100 - 10) * 1.08 = 97.20? Catches logic errors
```

---

## Anti-Fatigue Practices

```
RULE 1: Start with ≤10 checks per table. Add only when justified by incidents.

RULE 2: Group related checks into a single alert.
  BAD: 15 separate "null rate increased" alerts for 15 columns
  GOOD: 1 alert: "Null rates spiked in fct_orders: user_id (12%), amount (8%), status (3%)"

RULE 3: Auto-mute after acknowledgment. If someone clicks "investigating," suppress
  follow-up alerts for that check for 4 hours.

RULE 4: Monthly cleanup. Review all checks that fired in the past 30 days:
  - Never fired → is it still relevant? Remove or lower severity.
  - Fired but nobody acted → remove or reclassify as INFO.
  - Fired and was useful → keep.
  - Been in WARN state for >7 days unfixed → escalate or remove.

RULE 5: Track alert-to-action ratio. Target: >50% of alerts lead to action.
  Below 30% → you have a fatigue problem. Cull aggressively.
```
