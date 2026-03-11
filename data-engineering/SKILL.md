---
name: data-engineering
description: "Use for any data engineering task: building ETL/ELT pipelines, API ingestion, data modeling (star schema, Data Vault, SCD), schema design and evolution, database migrations, orchestration setup (Airflow, Dagster, Prefect), incremental loading, CDC, partitioning, backfills, pipeline testing, error handling and retries, structured logging, CI/CD for data projects, or selecting data tools (DuckDB, Polars, Spark, Iceberg, dbt). Triggers: 'build a pipeline', 'ingest this API', 'design a schema', 'set up orchestration', 'incremental load', 'backfill', 'CDC', 'data modeling', 'star schema', 'SCD Type 2', 'partition this table', 'retry logic', 'idempotent', 'MERGE/UPSERT', 'dbt model', 'structured logging', 'Pydantic validation', 'connect to this database', 'migrate schema', 'deploy pipeline', 'Docker for data'. Do NOT use for pure analytics/dashboards (data-analysis skill), ML model training (data-science skill), or data quality checks (data-quality skill)."
---

# Data Engineering Skill

This skill enforces production-grade data engineering practices across pipeline construction, data modeling, API ingestion, schema design, and infrastructure. It is Python-centric (3.11+) and opinionated — defaults are chosen, deviations require justification.

## Architecture

Five reference files contain deep guidance. Read the relevant one(s) BEFORE writing code:

| Task | Reference File |
|------|---------------|
| Medallion architecture, lakehouse formats (Iceberg/Delta), ELT vs ETL, batch vs streaming, Lambda vs Kappa, data mesh | `references/architecture-patterns.md` |
| Pydantic v2 validation, typing, Protocols, idempotency (MERGE/UPSERT/partition overwrite), error handling, retries (tenacity), circuit breakers, DLQ, exception hierarchies | `references/python-patterns.md` |
| API pagination (cursor/keyset/offset), rate limiting, OAuth2 token rotation, incremental loading (high-water mark), backfill strategies, async ingestion, httpx patterns | `references/ingestion-patterns.md` |
| CTEs, dbt naming conventions (stg_/int_/fct_/dim_), query optimization, SQL anti-patterns, formatting standards, dbt CTE import pattern | `references/sql-conventions.md` |
| Kimball star schema, Data Vault 2.0, SCD Type 1/2/3, partitioning (Snowflake/BigQuery/Postgres/Iceberg), CDC (Debezium), schema evolution, schema registries, data contracts, bi-temporal modeling, surrogate keys | `references/modeling-and-schema.md` |

Many tasks require multiple references (e.g., "build an API ingestion pipeline" → read ingestion-patterns.md AND python-patterns.md).

---

## Pre-Flight Checklist (ALWAYS run before any DE work)

### 1. Task Classification
```
"Ingest data from [source]"          → INGESTION (read ingestion-patterns.md)
"Build a pipeline for [process]"     → PIPELINE (read python-patterns.md + architecture-patterns.md)
"Design tables / model data"         → MODELING (read modeling-and-schema.md + sql-conventions.md)
"Write dbt models / SQL transforms"  → TRANSFORMATION (read sql-conventions.md)
"Set up orchestration / scheduling"  → ORCHESTRATION (read architecture-patterns.md)
"Deploy / containerize pipeline"     → DEPLOYMENT (read python-patterns.md)
"Fix / debug a broken pipeline"      → DEBUGGING (read python-patterns.md)
```

### 2. Scale Assessment
```
< 1M rows     → pandas fine, PostgreSQL, simple tooling
1M–50M rows   → Polars (lazy) or DuckDB preferred
50M–500M rows → DuckDB for SQL, Polars for DataFrames
500M+ rows    → Spark or warehouse-native processing
```

### 3. Tool Selection Defaults
```
Processing:    DuckDB (SQL on files) | Polars (DataFrame ETL) | Spark (distributed only)
Orchestration: Dagster (data-first teams) | Prefect (Python-first, small teams) | Airflow (enterprise)
Transformation: dbt Core (standard) | SQLMesh (compute-sensitive)
Ingestion:     Airbyte OSS (managed connectors) | Custom Python (unique APIs)
File format:   Parquet + ZSTD compression (always, unless streaming → Avro)
Table format:  Apache Iceberg (default for lakehouse) | Delta Lake (Databricks shops)
Validation:    Pydantic v2 at boundaries | Pandera for DataFrames | dbt tests for SQL
HTTP client:   httpx (default) | aiohttp (100+ concurrent connections)
Retries:       tenacity (always) with TransientError/PermanentError split
Logging:       structlog (JSON in prod, colorized in dev)
Packaging:     uv (replaces pip/Poetry/pyenv)
Linting:       ruff (replaces Black/Flake8/isort) + mypy strict + sqlfluff
```

---

## Core Workflow: Pipeline Development

Every pipeline follows this pattern:

```
1. DEFINE   → What data, from where, to where, at what frequency, at what grain
2. EXTRACT  → Ingest from source (API, database, files) with retry + rate limiting
3. VALIDATE → Schema check at entry (Pydantic) — route failures to DLQ
4. TRANSFORM → Pure functions, no I/O — composable via df.pipe()
5. LOAD     → Idempotent write (MERGE, partition overwrite, or truncate+insert)
6. TEST     → Unit tests on transforms, integration tests with testcontainers
7. OBSERVE  → Structured logging, metrics, correlation IDs
```

### Idempotency is non-negotiable
Every pipeline must produce identical results whether run once or ten times:
```
Time-partitioned facts  → Partition overwrite (DELETE partition + INSERT, in transaction)
Dimension tables        → MERGE/UPSERT on business key
Full refresh (small)    → Truncate + reload (< 10M rows)
File outputs            → Deterministic paths derived from input params, not timestamps
```
See `references/python-patterns.md` for MERGE syntax across PostgreSQL, Snowflake, and BigQuery.

### Error handling splits transient from permanent
```python
# ALWAYS define this hierarchy
class PipelineError(Exception): pass
class TransientError(PipelineError): pass   # → retry (timeout, rate limit, connection)
class PermanentError(PipelineError): pass   # → DLQ (bad schema, invalid data, business rule)
```
- Catch TransientError → let tenacity retry with exponential backoff + jitter
- Catch PermanentError → log + send to dead letter queue + continue processing
- Unknown errors → let them bubble up (don't catch bare Exception to suppress)

---

## Project Structure Template

```
my_pipeline/
├── src/my_pipeline/
│   ├── __init__.py
│   ├── config/
│   │   └── settings.py          # pydantic-settings with env var binding
│   ├── models/
│   │   ├── raw.py               # Pydantic models for source data
│   │   └── processed.py         # Pydantic models for output data
│   ├── extractors/
│   │   ├── base.py              # Protocol definitions
│   │   └── api_extractor.py     # Concrete implementations
│   ├── transformers/            # Pure functions only, no I/O
│   ├── loaders/                 # Database/file writers
│   ├── pipelines/
│   │   └── orchestrator.py      # Composes E → T → L
│   └── utils/
│       ├── logging.py           # structlog config
│       └── retry.py             # tenacity wrappers
├── tests/
│   ├── conftest.py              # Shared fixtures
│   ├── test_transformers/       # Pure function tests (fast, no I/O)
│   └── test_integration/        # testcontainers-based (slow, real DB)
├── sql/                         # Raw SQL or dbt models
├── pyproject.toml               # Single source of truth (deps + tool config)
├── uv.lock                      # Deterministic lockfile
├── Dockerfile                   # Multi-stage with uv
└── .pre-commit-config.yaml      # ruff + mypy + sqlfluff + gitleaks
```

---

## Data Modeling Quick Router

```
Stable sources, BI-focused       → Kimball star schema (fct_ + dim_)
5+ sources, audit requirements   → Data Vault 2.0 (hub + link + satellite)
Small team, < 5 sources          → One Big Table on top of dimensional model
Product analytics, event streams → Activity Schema
```

### Naming conventions (dbt standard)
```
stg_{source}__{entity}   → Staging (1:1 with source, views, only layer using source())
int_{description}        → Intermediate transforms
fct_{entity}             → Fact tables (immutable events)
dim_{entity}             → Dimension tables (mutable entities)
```
Column suffixes: `_id` (identifiers), `_sk` (surrogates), `_at` (timestamps, UTC), `_date`, `is_`/`has_` (booleans), `_count`, `_amount_usd`. Everything `snake_case`.

### SCD selection
```
History doesn't matter              → SCD Type 1 (overwrite via MERGE)
Full history needed                 → SCD Type 2 (effective_from/to + is_current)
Only need before/after              → SCD Type 3 (previous_* columns)
dbt project                        → Use dbt snapshots (auto SCD Type 2)
```

---

## SQL Defaults

- **CTEs over subqueries** — always, unless simple `WHERE ... IN (SELECT ...)`
- **Trailing commas** — cleaner git diffs, fewer syntax errors
- **4-space indent**, lowercase keywords, explicit `AS` for aliases
- **`GROUP BY 1, 2`** over column names
- **Aggregate early, join late** — prevents row explosion
- **`QUALIFY ROW_NUMBER()`** over self-joins for dedup and "latest per group"
- **Never `SELECT *`** in columnar warehouses — specify columns explicitly
- **Push predicates into CTEs** rather than filtering after joins

---

## Memory & Processing Decision Framework

| Data Size | Tool | Why |
|-----------|------|-----|
| < 100 MB | pandas | Switching overhead not worth it |
| 100 MB – 1 GB | Polars (lazy) | 2–5x faster, lower memory |
| 1 – 10 GB | Polars streaming or DuckDB | Both handle larger-than-memory |
| 10 – 100 GB | DuckDB | Streaming execution, disk spilling |
| > 100 GB | DuckDB (to ~2 TB) or Spark | Only distribute when you must |

All three interoperate via Apache Arrow with near-zero-copy.

---

## Ingestion Quick Reference

### Pagination
```
Large/changing datasets → Cursor-based or keyset (stable, index-friendly)
Small admin UIs         → Offset (simple, supports page numbers)
Time-series logs        → Keyset on (timestamp, id) composite
```

### Incremental loading
```
Source has updated_at   → High-water mark (track max timestamp between runs)
Source has CDC/WAL      → Log-based CDC (Debezium → Kafka)
Source has no change tracking → Full refresh (truncate + reload)
```

### Backfills
- Same code path as production runs, parameterized by date range
- Partition overwrite for idempotency
- Throttle with sleep between chunks to protect source systems
- Shadow table pattern for zero-downtime: create copy → populate → validate → swap

---

## CI/CD Defaults

### On every PR
```
ruff check + format, mypy strict, sqlfluff lint, pytest tests/unit/
```

### On merge to main
```
Integration tests with real Postgres (testcontainers or GitHub Actions services)
Alembic migration check (alembic check)
Deploy pipeline
```

### Pre-commit hooks (mandatory)
```
ruff (lint + format), mypy, sqlfluff (lint + fix), gitleaks (secret scanning)
```

---

## Anti-Pattern Watchlist

Flag and correct immediately:

- **Non-idempotent writes** → blind INSERT without dedup creates duplicates on retry
- **Bare `except Exception`** → suppresses bugs you need to see
- **`datetime.now()` in pipeline logic** → use parameterized execution dates
- **No retry on API calls** → all external calls need tenacity
- **Mocking the database in tests** → use testcontainers for real behavior
- **`SELECT *` in production SQL** → specify columns in columnar warehouses
- **Unbounded retries** → always set `stop_after_attempt()`
- **Streaming when batch suffices** → only 5–10% of use cases need real-time
- **Building before baseline** → start with the simplest tool that works
- **Hardcoded credentials** → use pydantic-settings SecretStr + env vars

---

## Pre-Delivery QA Checklist

Before delivering any data engineering work:

- [ ] Pipeline is idempotent (re-running produces same result)
- [ ] Error handling separates transient from permanent failures
- [ ] All external calls wrapped in retry with backoff
- [ ] Structured logging emits: input rows, output rows, errors, duration per stage
- [ ] Schema validated at pipeline boundaries (Pydantic or Pandera)
- [ ] Unit tests cover transformation logic (pure functions)
- [ ] Integration test confirms end-to-end with real database
- [ ] SQL follows dbt naming conventions and style guide
- [ ] Configuration via environment variables (no hardcoded secrets)
- [ ] Deterministic outputs (file paths, partition keys derived from inputs)
- [ ] Dependencies locked (uv.lock or requirements.txt pinned)
- [ ] Dockerfile uses multi-stage build if containerized
- [ ] Documentation: README with setup, architecture, and data flow
