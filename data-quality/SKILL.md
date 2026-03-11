---
name: data-quality
description: "Use this skill for any data quality task: validating datasets, profiling data, cleaning messy or scraped data, detecting anomalies, building validation suites, enforcing schemas, writing data contracts, deduplicating records, standardizing formats, auditing completeness, tracking lineage, or designing well-structured tables. Triggers: 'validate this data', 'check data quality', 'profile this dataset', 'clean this data', 'find duplicates', 'check for nulls', 'detect anomalies', 'schema validation', 'data contract', 'why does this data look wrong', 'audit this table', 'freshness check', 'is this data trustworthy', 'deduplicate', 'data lineage', 'SCD', 'data completeness', or any request involving data validation, cleaning, profiling, or quality assessment. Also use when ingesting unfamiliar datasets or building pipeline quality gates. Do NOT use for analytics/dashboards (use data-analysis), ML model training, or ETL orchestration."
---

# Data Quality Skill

This skill enforces disciplined data quality practice across validation, profiling, cleaning, schema enforcement, and dataset design. It applies to datasets of any scale — from small CSVs to 100M+ row warehouse tables — using a Python + SQL hybrid stack.

## Architecture

Four reference files contain deep guidance. Read the relevant one(s) BEFORE writing code:

| Task | Reference File |
|------|---------------|
| Validating data, building test suites, anomaly detection, freshness/volume monitoring, alert design | `references/validation-and-monitoring.md` |
| Schema enforcement, data contracts, lineage tracking, documentation-as-code | `references/schema-contracts-lineage.md` |
| Profiling unknown data, cleaning messy/scraped data, deduplication, standardization, missing data | `references/profiling-and-cleaning.md` |
| Table design, grain, typing, SCD, partitioning, naming, performance optimization | `references/dataset-design-and-performance.md` |

Many tasks require multiple references (e.g., "ingest and validate this scraped dataset" → read profiling-and-cleaning.md AND validation-and-monitoring.md).

---

## Pre-Flight Checklist (ALWAYS run before any DQ work)

Before writing ANY validation, cleaning, or profiling code, answer these questions:

### 1. Data Context
- **What is this data?** Source system, how it was produced, expected grain (what one row represents).
- **What's the use case?** Analytics, ML features, reporting, operational decisions?
- **How critical is this data?** Tier it:
  ```
  TIER 1 (Critical) → Revenue/compliance/exec reporting → heavyweight validation
  TIER 2 (Important) → Team dashboards, operational metrics → standard validation
  TIER 3 (Exploratory) → Ad-hoc analysis, experimentation → lightweight profiling
  ```

### 2. Data State Assessment
- **Clean or messy?** Classify:
  ```
  API/warehouse extract with known schema → CLEAN path (validate + monitor)
  CSV/Excel from human source → SEMI-MESSY (profile first, then clean + validate)
  Web-scraped / OCR / free-text → MESSY path (heavy profiling + cleaning pipeline)
  Unknown provenance → Treat as MESSY until proven otherwise
  ```
- **Scale?** Determines tooling:
  ```
  < 1M rows → pandas fine, full validation
  1M–50M rows → Polars or DuckDB preferred
  50M+ rows → DuckDB for SQL checks, sample-based profiling, approximate algorithms
  ```

### 3. Scope
- What specific quality concerns exist? (Or is this a general audit?)
- Are there known upstream issues or recent schema changes?
- What's the delivery: a one-time report, ongoing monitoring, or a cleaning pipeline?

---

## Core Workflow: The DQ Loop

Every data quality task follows this pattern:

```
1. PROFILE → Understand what you have (shape, types, distributions, gaps)
2. DEFINE  → Set expectations (schema, ranges, relationships, freshness)
3. VALIDATE → Test data against expectations (automated checks)
4. REMEDIATE → Fix what's broken (clean, impute, deduplicate, quarantine)
5. MONITOR → Detect when things break again (alerts, dashboards, CI/CD)
```

Not every task requires all five steps. Route by task type:
```
"Check this data"          → PROFILE + VALIDATE
"Clean this dataset"       → PROFILE + REMEDIATE + VALIDATE
"Build quality monitoring" → DEFINE + VALIDATE + MONITOR
"Is this data trustworthy" → PROFILE + VALIDATE (report findings)
"Design this table"        → DEFINE (schema + grain + typing)
```

---

## Universal Quality Checks (run on EVERY dataset interaction)

These five checks are mandatory before any downstream use of data. They catch >80% of quality issues:

### The Essential Five
```
1. FRESHNESS  → MAX(updated_at) within expected window?
   IF no timestamp column → skip, but flag as risk

2. VOLUME     → Row count within expected range?
   IF first encounter → record baseline
   IF known baseline → |actual - expected| / expected < 0.20

3. PRIMARY KEY → Identified key columns are unique + not null?
   SQL: SELECT pk, COUNT(*) FROM table GROUP BY pk HAVING COUNT(*) > 1
   IF duplicates found → STOP. Diagnose before proceeding.

4. NULL RATES  → Critical columns have acceptable null rates?
   IF null rate changed >5pp from baseline → investigate
   IF key column (IDs, amounts, dates) has ANY nulls → flag critical

5. SCHEMA     → Column names, types, count match expectations?
   IF new columns appeared → investigate (upstream schema change?)
   IF columns disappeared → CRITICAL alert
   IF types changed → CRITICAL alert
```

### When to Go Beyond the Five
```
IF Tier 1 data → add: referential integrity, value range checks, cross-source reconciliation
IF time-series data → add: distribution drift, seasonal pattern checks
IF financial data → add: balance reconciliation, sign checks, currency consistency
IF user-facing data → add: format validation, encoding checks
IF ML features → add: feature drift, target leakage scan, cardinality checks
```

---

## Tool Selection Defaults

Use these defaults. Deviate only with reason.

### Python Validation
```
DataFrame validation → Pandera (type-hint API, supports pandas + Polars + PySpark)
Record/JSON validation → Pydantic v2 (Rust-core, use Annotated constraints over @field_validator)
Heavy production suites → Great Expectations (300+ expectations, auto-docs)
Quick profiling → ydata-profiling (one-line reports) or df.describe() + custom checks
```

### SQL Validation
```
dbt project exists → dbt tests (unique, not_null, accepted_values, relationships)
  + dbt-expectations for advanced checks
  + Elementary for anomaly detection
No dbt → write raw SQL assertions (query should return 0 rows on pass)
Schema enforcement → dbt model contracts (enforced: true) or DDL CHECK constraints
```

### Processing Engine (by data size)
```
< 1M rows → pandas
1M–50M rows → Polars (lazy mode) or DuckDB
50M+ rows → DuckDB (SQL on files, auto spill-to-disk)
Any size, SQL preferred → DuckDB
Interop needed → DuckDB queries Polars DataFrames via Arrow, zero-copy
```

---

## Alert Severity Framework

When building monitoring, classify every check:

```
CRITICAL (page immediately, blocks pipeline):
  - Zero rows in production table
  - Primary key duplicates
  - Schema breaking change (dropped columns, type changes)
  - Freshness SLA breach on Tier 1 data

WARNING (Slack alert, 4-hour response):
  - Volume deviation > 20%
  - Null rate spike > 5 percentage points
  - Distribution drift (PSI > 0.2)
  - New unexpected values in categorical columns

INFO (log only, review weekly):
  - Minor volume fluctuations (< 10%)
  - Slight distribution shifts (PSI 0.1–0.2)
  - New columns detected (may be intentional)
```

### Anti-Fatigue Rule
Before creating ANY alert, answer: **"If this fires at 3am, what specific action does someone take?"**
- IF clear action → create the alert
- IF "investigate" → make it WARNING, not CRITICAL
- IF no action → make it INFO or don't create it

---

## Pre-Delivery QA Checklist

Before delivering any data quality work:

- [ ] All checks produce clear PASS/FAIL with severity levels
- [ ] Failures include enough context to diagnose (table, column, sample bad values, timestamp)
- [ ] No hardcoded thresholds that should be dynamic (use rolling baselines for metrics with natural variation)
- [ ] Schema expectations stored as config (YAML/JSON), not buried in code
- [ ] Cleaning steps are idempotent (running twice produces same result)
- [ ] Original data preserved (quarantine bad records, don't silently drop)
- [ ] Results logged with structured metadata (pipeline_id, table, check_name, severity, timestamp)
- [ ] Edge cases handled (empty DataFrames, single-row tables, all-null columns)
- [ ] Performance acceptable at actual data scale (not just tested on sample)
- [ ] Documentation matches implementation (schema files, README, inline comments)
