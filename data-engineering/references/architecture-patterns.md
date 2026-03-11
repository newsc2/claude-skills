# Architecture Patterns Reference

## Medallion Architecture (Bronze / Silver / Gold)

**Bronze** — Raw landing zone. Append-only, preserve original fidelity. Store fields as strings/VARIANT to absorb schema drift. Add metadata: `_loaded_at`, `_source_file`, `_batch_id`.

**Silver** — Validated, deduplicated, standardized. Type enforcement, null handling, business key dedup via `ROW_NUMBER()`. This is where schema-on-write begins.

**Gold** — Business-level aggregates, star schemas, feature tables. Optimized for specific consumers (BI, ML, reporting).

**When to use:** Any project with 3+ data sources or where data will be consumed by multiple teams. Skip for single-source, single-consumer prototypes.

**Key tradeoff:** The silver layer is the least clearly defined — define its purpose explicitly per project (e.g., "silver = deduplicated + typed + business keys resolved").

**Implementation:**
- Use logical separation (schemas/prefixes) for simplicity: `raw.events`, `staging.events`, `marts.fct_events`
- Use physical separation (separate databases/environments) when security or compliance demands it
- Define SLAs per layer: hourly Bronze, daily Silver, nightly Gold

---

## Lakehouse Table Formats

### Apache Iceberg (default recommendation)
- 78.6% exclusive adoption among open table format users (2025 survey)
- Native support: AWS S3 Tables, Snowflake Iceberg Tables, BigQuery managed Iceberg
- Hidden partitioning decouples queries from physical layout
- Schema evolution via unique column IDs — all changes are metadata-only
- Partition evolution without data rewrite
- V3 (2025): deletion vectors, geospatial types, nanosecond timestamps

### Delta Lake
- Best for Spark-centric, Databricks-native workloads
- Deep Unity Catalog integration
- Schema enforcement ON by default (rejects mismatched writes)
- UniForm produces Iceberg-compatible metadata automatically

### Apache Hudi
- Best for streaming-heavy workloads with frequent updates/deletes
- Uber runs 5,000+ Flink-Hudi pipelines (600 TB daily)
- Record-level indexing for fast upserts

**Decision:** Default to Iceberg. Stay with Delta if Databricks-native. Consider Hudi for streaming CDC.

**Interoperability:** Apache XTable and Delta UniForm allow cross-format reads — the format choice is less critical than it was.

---

## ELT vs ETL

**ELT (default for cloud-native):** Extract → Load raw → Transform in warehouse. Uses warehouse compute for transformations (dbt/SQLMesh). ~66.8% market share.

**ETL (specific scenarios only):** Transform before loading when:
- GDPR/compliance requires PII masking before data reaches warehouse
- Complex transforms exceed target system capabilities
- Legacy on-premise destinations lack transformation compute

Most organizations implement a hybrid. Start with ELT unless you have a specific reason for ETL.

---

## Lambda vs Kappa

**Kappa (preferred for new systems):** Single streaming pipeline treating all data as streams. Simpler codebase, one path to maintain. Disney, Shopify, Uber, Twitter have documented migrations to Kappa.

**Lambda (still valid):** When you need both deep historical analysis AND real-time insights with different accuracy requirements (e.g., financial reporting batch layer + operational streaming layer).

**Practical reality:** Most systems are hybrid — streaming for operational signals, batch for deep retrospective analytics.

---

## Data Mesh Reality Check

Data mesh (Dehghani, 2019) has hit Gartner's Trough of Disillusionment. The full framework (domain ownership, data as product, self-serve infrastructure, federated governance) makes sense for large orgs (hundreds of data engineers) with clear domain boundaries.

**What's universally valuable:** Treating data as a product with SLAs, documentation, quality guarantees, and discoverability.

**What fails:** Re-badging teams without genuine ownership, expecting domains to build infrastructure, tooling fragmentation.

**For most teams:** Hybrid approach — centralized platform + distributed delivery.

---

## Batch vs Streaming Decision

```
"What's the cost of a 15-minute delay?"
  → "That's fine"     → Micro-batch (and save complexity/cost)
  → "Unacceptable"    → True streaming (and accept the cost)
```

**Batch:** Cheapest, simplest, easiest to test and recover.
**Micro-batch (1–15 min):** Dashboards, marketing attribution, CDC syncs. 80% of "real-time" requirements.
**True streaming:** Fraud detection, safety systems, real-time pricing. Only ~5–10% of use cases.

**Streaming technology stack:**
- Kafka = distributed event store / message bus
- Flink = stream processing gold standard (sub-millisecond latency, stateful)
- Spark Structured Streaming = batch+stream unified for Spark shops

**Common hybrid:** Stream to Bronze (low-latency ingestion) → batch to Silver/Gold (correctness + analytics).

---

## Orchestration Selection

| Criteria | Airflow | Dagster | Prefect |
|----------|---------|---------|---------|
| GitHub stars | ~38K | ~12-13K | ~15K |
| Best for | Enterprise, complex batch | Data-first teams, dbt integration | Small Python-first teams |
| Pricing | Self-hosted free; Astronomer $0.35/hr+ | Solo $10/mo; can escalate unpredictably | Hobby free; Starter ~$75-100/mo |
| Learning curve | Steep | Moderate | Low |
| dbt integration | Via Cosmos | Best-in-class (native asset mapping) | Good |

**Solo/homelab:** Prefect (free Hobby tier, minimal DevOps).
**Production team:** Dagster (asset-centric, best dbt integration).
**Enterprise/legacy:** Airflow (ecosystem breadth, hiring pool).

---

## Tool Landscape Quick Reference

### Processing Engines
- **DuckDB** (~36K stars, MIT): In-process OLAP, ~5MB footprint, ~10x price-performance vs cloud warehouses for sub-TB. Default for local dev and moderate-scale analytics.
- **Polars** (~32K stars, MIT, Rust): Pandas replacement. 3-30x faster. Use LazyFrame for >100MB.
- **Spark** (~40K stars): Distributed only. Don't use for <100GB unless already in ecosystem.

### Transformation
- **dbt Core** (free, ~12.3K stars, 50K+ teams): SQL-first, modular, testing built-in. Industry standard.
- **SQLMesh** (~2.5-3K stars): Virtual data environments, ~9x faster than dbt Core on benchmarks. Worth evaluating for compute-heavy pipelines.

### Ingestion
- **Airbyte OSS** (~16K stars): Default open-source. Self-hosted free; Cloud $10/GB.
- **Fivetran** (700+ connectors): Highest reliability. $500/M MAR minimum, $12K/yr floor.
- **Custom Python:** Last resort. Maximum flexibility, highest maintenance.

### Cloud Warehouses
- **Snowflake:** Default for SQL/BI. Credits $2-4. Auto-suspend at 60s.
- **BigQuery:** Simplest operations. Best free tier (1TB queries/month). Enforce partition filters.
- **Redshift:** Most cost-effective for steady AWS workloads. Reserved instances save 76%.
- **Databricks:** Best for unified DE + ML. DBUs $0.07-0.75. Use Jobs Compute (30-50% cheaper).

### File Formats
- **Parquet + ZSTD:** Default for everything analytical. Columnar, self-describing, universal support.
- **Avro:** Row-based, best schema evolution. Standard for Kafka streaming.
- **CSV:** Human inspection only. Never for production pipelines.
- Pattern: Avro (Kafka ingestion) → Parquet+ZSTD (analytics storage).

### Data Quality
- **dbt tests:** Zero-cost baseline (unique, not_null, accepted_values, relationships).
- **Pandera** (~4.2K stars, MIT): Lightweight DataFrame validation. Supports pandas, Polars, PySpark.
- **Soda Core:** YAML-based monitoring. Free for 3 datasets.
- **Great Expectations** (~11.1K stars): Most expressive. Steeper learning curve.

### Metadata Catalogs
- **OpenMetadata** (~6.2K stars): Simplest architecture, built-in DQ testing. Best starting point.
- **DataHub** (~10.5K stars): Largest community. Complex deployment (Kafka + graph DB).
