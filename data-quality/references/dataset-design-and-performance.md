# Dataset Design and Performance Reference

Read this file when designing tables, choosing grain/types, implementing SCDs, partitioning data, establishing naming conventions, or optimizing data quality checks for performance.

---

## Grain and Table Design

### Getting Grain Right

```
RULE 1: Define grain as a sentence BEFORE writing any DDL or query.
  "One row per order" / "One row per user per day" / "One row per click event"
  IF you cannot state the grain in one sentence → the table is not well-designed.

RULE 2: Enforce grain with a primary key.
  Single column: order_id
  Composite: (user_id, event_date)
  ALWAYS test with unique + not_null (dbt or SQL assertion).

RULE 3: Never mix grains in one fact table.
  BAD: individual items and combo-pack totals in same table → double-counting
  GOOD: separate tables for different grains, aggregate from atomic level

RULE 4: Always start at atomic grain (most detailed level).
  Build aggregated tables FROM atomic tables, not as primary storage.
  Exception: when source only provides aggregates (then document limitation).

RULE 5: Grain determines valid aggregations.
  IF grain is "one row per order item" → SUM(amount) gives order total
  IF grain is "one row per order" → SUM(amount) gives cross-order total
  IF grain is "one row per daily snapshot" → SUM(amount) double-counts
  DOCUMENT which aggregations are valid for every table.
```

### Grain Debugging

```
IF row count doesn't match expectations:
  SELECT grain_columns, COUNT(*) FROM table GROUP BY grain_columns HAVING COUNT(*) > 1
  IF duplicates → grain is finer than assumed or JOIN produced fan-out

IF metric totals don't match between tables:
  Check grain compatibility before blaming data quality
  Most "data quality issues" in analytics are actually grain mismatches
```

---

## Data Types

### SQL Type Selection Rules

```
MONEY / FINANCIAL:
  ALWAYS → DECIMAL(precision, scale), e.g., DECIMAL(10,2) for currency
  NEVER → FLOAT / REAL (approximate: SUM may produce 19.9999998 instead of 20.00)
  STORE cents as INTEGER if precision is always 2 decimal places

TIMESTAMPS:
  ALWAYS → TIMESTAMPTZ (PostgreSQL) / TIMESTAMP_TZ (Snowflake)
  NEVER → TIMESTAMP without timezone (causes implicit cast overhead + ambiguity)
  STORE in UTC, convert at presentation layer
  IF date-only needed → DATE type (no time component)

IDENTIFIERS:
  Use VARCHAR/TEXT, not INTEGER, for IDs unless performance-critical
  Reason: IDs are not numeric — you don't add or average them
  IF source provides integer IDs → VARCHAR still preferred for safety against overflow
  IF performance-critical joins on billions of rows → INTEGER OK, but document

BOOLEANS:
  Use native BOOLEAN type, not INTEGER 0/1 or VARCHAR 'Y'/'N'
  IF source provides 0/1 → cast to BOOLEAN at staging layer
  Name with is_ or has_ prefix: is_active, has_subscription

STRINGS:
  PostgreSQL: TEXT (no performance difference vs VARCHAR(n))
  Snowflake: VARCHAR (default 16MB, no benefit to specifying length)
  IF strict length constraint needed → VARCHAR(n) + CHECK constraint
```

### Python Type Enforcement

```python
# Pandas: enforce types at read time
df = pd.read_csv(path, dtype={
    'order_id': 'string',     # not object — proper string type
    'amount': 'Float64',      # nullable float (capital F)
    'is_active': 'boolean',   # nullable boolean
    'count': 'Int64',         # nullable integer (capital I)
})

# Polars: enforce types at read time
df = pl.read_csv(path, schema={
    'order_id': pl.Utf8,
    'amount': pl.Float64,
    'is_active': pl.Boolean,
    'created_at': pl.Datetime,
})

# DuckDB: enforce via CAST in staging query
SELECT
  CAST(order_id AS VARCHAR) AS order_id,
  CAST(amount AS DECIMAL(10,2)) AS amount,
  CAST(created_at AS TIMESTAMPTZ) AS created_at
FROM read_csv('raw.csv', auto_detect=true)
```

---

## Slowly Changing Dimensions (SCD)

### Type Selection

```
DEFAULT → SCD Type 2 (add row with valid_from/valid_to/is_current):
  Use for any attribute requiring audit trail or trend analysis.
  Implementation: dbt snapshots (preferred). Snapshot at SOURCE level.
    strategy: timestamp (if reliable updated_at exists)
    strategy: check (compares columns, use when no timestamp)

Type 0 → Fixed attributes (birth date, SSN): reject updates.
Type 1 → Overwrite (typo corrections): simple UPDATE. No history.
Type 3 → Previous value only: rare, Type 2 almost always better.
Type 6 → Hybrid (1+2+3): when both point-in-time AND current-state needed. Complex.
```

### Querying SCD Type 2

```sql
-- Point-in-time correct join (CRITICAL — always filter to one version per key per fact row)
SELECT f.metric_date, d.plan_tier, SUM(f.revenue)
FROM fct_transactions f
LEFT JOIN dim_customers d
  ON f.customer_id = d.customer_id
  AND f.metric_date >= d.valid_from
  AND (f.metric_date < d.valid_to OR d.is_current = TRUE)
GROUP BY 1, 2;
-- Joining WITHOUT date range → fans out to multiple versions → double-counting
```

---

## Partitioning and Indexing

### When to Partition

```
IF table < 1GB → don't partition (overhead exceeds benefit)
IF table > 1GB AND queries filter on a column → partition on that column

Time-series → range partition by date (PostgreSQL PARTITION BY RANGE, BigQuery PARTITION BY DATE)
DuckDB → Hive-style partitioned Parquet (year=2024/month=01/*.parquet)
BigQuery → partition by date + cluster by up to 4 columns (most-filtered first)
```

### Indexing (PostgreSQL)

```
B-tree (default): equality + range. CREATE INDEX idx ON table (column);
Partial: only matching rows. CREATE INDEX idx ON table (id) WHERE amount IS NULL;
  → Perfect for DQ: fast null-scan on specific columns
BRIN: time-series with physical ordering. Tiny index, fast range scans.
GIN: JSONB, arrays, full-text search.
```

---

## Naming Conventions

### Table Naming (dbt standard)

```
Layer prefixes:
  stg_   → staging (1:1 with source, minimal transforms: rename, cast, dedupe)
  int_   → intermediate (business logic joins, no direct consumption)
  fct_   → fact table (events, transactions — measures)
  dim_   → dimension table (entities, attributes — descriptors)
  rpt_   → report table (pre-aggregated for specific dashboard/report)

Rules:
  snake_case everywhere (no camelCase, no spaces, no special characters)
  Pluralize table names: fct_orders, dim_customers, stg_payments
  Include source in staging: stg_stripe__payments, stg_salesforce__accounts
```

### Column Naming

```
Suffixes:
  _id     → keys and identifiers: order_id, customer_id
  _at     → timestamps: created_at, updated_at, deleted_at
  _date   → date-only: order_date, birth_date
  _amount → money: order_amount, refund_amount (always document currency)
  _count  → integer counts: item_count, login_count
  _rate   → ratios/percentages: conversion_rate, churn_rate (document if 0-1 or 0-100)
  _flag   → quality indicators: is_missing_flag, is_outlier_flag

Prefixes:
  is_     → boolean: is_active, is_deleted, is_test
  has_    → boolean: has_subscription, has_address

NEVER:
  - date, value, data, info, type alone (too generic)
  - Abbreviations without documentation (what is cust_grp_cd?)
  - Mixed conventions in same project
```

---

## Performance Optimization for Quality Checks

### Engine Selection by Scale

```
< 1M rows → pandas:
  Familiar API, best ecosystem (scikit-learn, matplotlib)
  Adequate performance for small data

1M–50M rows → Polars (preferred) or DuckDB:
  Polars: lazy mode with streaming for memory-efficient processing
    df = pl.scan_csv("big.csv")
    result = df.filter(...).group_by(...).agg(...).collect(streaming=True)
  DuckDB: SQL interface, queries files directly
    duckdb.sql("SELECT * FROM 'big.csv' WHERE amount < 0")
  Both: ~5× faster than pandas, ~80% less memory

50M+ rows → DuckDB:
  Auto spill-to-disk (300MB memory for 9GB file)
  Vectorized execution with cost-based optimizer
  Direct Parquet/CSV querying without loading into memory
  SUMMARIZE command for instant profiling
```

### Sampling Strategies

```
IF full validation too slow:
  Random sample: df.sample(frac=0.01) or TABLESAMPLE BERNOULLI(1) in SQL
  Stratified: df.groupby('category').sample(n=100)
  Time-based: validate only last 7 days for trend checks

IF exact count needed on large data:
  Use APPROX_COUNT_DISTINCT() (HyperLogLog, ~2% error, 12KB memory)
  Available in DuckDB, BigQuery, Presto, Snowflake

IF distribution check needed on large data:
  Use t-digest for approximate percentiles
  DuckDB: APPROX_QUANTILE(column, [0.25, 0.5, 0.75])
```

### SQL Performance for Validation

```
Use CTEs for readability. IF CTE is slow (scanned multiple times):
  → Materialize into temp table (gets its own statistics + can be indexed)

Window functions for anomaly detection:
  LAG/LEAD → temporal change detection
  AVG/STDDEV OVER (ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING) → rolling baseline
  ROW_NUMBER OVER (PARTITION BY key ORDER BY updated_at DESC) → deduplication
  PERCENTILE_CONT WITHIN GROUP → distribution checks

Avoid full table scans:
  Add WHERE clause to limit validation to recent data when appropriate
  Use partial indexes for null-scanning (PostgreSQL)
  Use INFORMATION_SCHEMA for column-level metadata without scanning data
```

### Code Organization Pattern

```
data_quality/
├── config/                 # Validation rules as data, not code
│   ├── schemas/           # YAML schema definitions per table
│   └── thresholds.yml     # Alert thresholds (freshness SLAs, volume bounds)
├── validators/            # Check implementations
│   ├── schema.py          # Schema drift detection
│   ├── completeness.py    # Null rate, coverage checks
│   ├── uniqueness.py      # Duplicate detection
│   ├── freshness.py       # Timestamp recency checks
│   └── distribution.py    # Anomaly detection, drift
├── engines/               # Backend-specific execution
│   ├── pandas_engine.py
│   ├── polars_engine.py
│   └── sql_engine.py
├── reporting/             # Output formatting
│   ├── logger.py          # Structured logging (structlog)
│   └── alerter.py         # Slack/email/PagerDuty routing by severity
└── runner.py              # Orchestrator: load config → run validators → report

PRINCIPLE: Separate WHAT to check (config) from HOW to check (engine).
  Adding a new table's checks should require only a new YAML file, not new code.
```
