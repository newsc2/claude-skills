# Data Modeling & Schema Design Reference

## Kimball Dimensional Modeling

Star schema: fact table at center surrounded by dimension tables. The pivotal step is **grain definition** — declaring exactly what a single fact row represents BEFORE choosing dimensions or measures.

### Fact Types
- **Transaction facts:** One row per event (order placed, page viewed). Most common.
- **Periodic snapshots:** One row per entity per time period (daily account balance).
- **Accumulating snapshots:** One row per lifecycle with milestone timestamps (order → ship → deliver).

### Key Concepts
- **Conformed dimensions:** Shared dimensions (dim_date, dim_customer) that enable drill-across reports from separate fact tables.
- **Bus matrix:** Maps business processes (rows) against dimensions (columns). Implement one row at a time; columns appearing across multiple rows become conformed.
- **Bridge tables:** Resolve many-to-many relationships between fact and dimension with weighting factors (sum to 1.0).
- **Degenerate dimensions:** Dimension attributes stored directly in the fact table (e.g., order_id).

### Star Schema Example
```sql
CREATE TABLE fct_order_lines (
    order_line_sk   BIGINT PRIMARY KEY,
    order_id        VARCHAR(50),           -- Degenerate dimension
    customer_sk     BIGINT REFERENCES dim_customers,
    product_sk      BIGINT REFERENCES dim_products,
    date_sk         INT REFERENCES dim_date,
    quantity        INT,
    unit_price      DECIMAL(10,2),
    line_total      DECIMAL(10,2)
);

CREATE TABLE dim_date (
    date_sk         INT PRIMARY KEY,       -- YYYYMMDD format
    date_actual     DATE NOT NULL,
    day_of_week     VARCHAR(10),
    month_name      VARCHAR(10),
    quarter_num     INT,
    fiscal_year     INT,
    is_weekend      BOOLEAN,
    is_holiday      BOOLEAN
);
```

---

## Data Vault 2.0

Three table types: **Hubs** (unique business keys), **Links** (relationships), **Satellites** (descriptive attributes with full change history).

```sql
CREATE TABLE hub_customer (
    customer_hash_key   BINARY(32),      -- MD5/SHA of business key
    customer_id         VARCHAR(50),     -- Business key
    load_date           TIMESTAMP,
    record_source       VARCHAR(100)
);

CREATE TABLE sat_customer_details (
    customer_hash_key   BINARY(32),
    effective_date      TIMESTAMP,
    customer_name       VARCHAR(200),
    email               VARCHAR(200),
    hash_diff           BINARY(32),       -- MD5 of all descriptive attributes
    load_date           TIMESTAMP,
    record_source       VARCHAR(100)
);
```

Hash keys (`MD5(UPPER(TRIM(key)))`) enable deterministic surrogates and parallel loading.

**Use Data Vault when:** 5+ source systems, quarterly schema changes, full audit trail required.
**Use Kimball when:** Stable sources, analysts need direct BI access, simpler to implement.
**Data Vault requires:** A Business Vault presentation layer on top — adds development time.

---

## One Big Table (OBT)

Pre-joins everything into a single wide table. Fivetran benchmarks show 10–45% better performance than star schemas on typical BI queries.

**Works for:** Small teams (<5 sources), BI tools without relationship support, ML feature stores, sub-second dashboards.
**Fails for:** Complex many-to-many relationships, multiple business processes, frequently changing dimensions.
**Consensus:** Build OBT on top of a dimensional model, not as a replacement.

---

## Activity Schema

Single time-series table: entity does activity over time. Columns: `ts`, `customer`, `activity`, generic `feature_1/2/3`, `revenue_impact`. Ten temporal join patterns cover ~90% of analytical questions.

Best for product analytics and customer journey analysis. Niche but growing.

---

## Slowly Changing Dimensions

### SCD Type 1 (Overwrite)
```sql
MERGE INTO dim_customer AS target
USING stg_customers AS source ON target.customer_id = source.customer_id
WHEN MATCHED AND (target.city != source.city OR target.segment != source.segment)
THEN UPDATE SET city = source.city, segment = source.segment, updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (customer_id, city, segment, updated_at)
    VALUES (source.customer_id, source.city, source.segment, CURRENT_TIMESTAMP());
```

### SCD Type 2 (Full History)
Three steps: detect changes (hash comparison), expire old current rows, insert new rows.

```sql
-- Step 1: Detect changes via hash_diff
CREATE TEMP TABLE changes AS
WITH source AS (
    SELECT *, MD5(CONCAT(name, city, segment)) AS row_hash FROM stg_customers
), current_dim AS (
    SELECT customer_id, row_hash FROM dim_customer WHERE is_current = TRUE
)
SELECT s.*, CASE
    WHEN d.customer_id IS NULL THEN 'INSERT'
    WHEN d.row_hash != s.row_hash THEN 'UPDATE'
END AS change_type
FROM source s LEFT JOIN current_dim d ON s.customer_id = d.customer_id
WHERE d.customer_id IS NULL OR d.row_hash != s.row_hash;

-- Step 2: Expire old rows
MERGE INTO dim_customer AS t USING changes AS s
ON t.customer_id = s.customer_id AND t.is_current = TRUE AND s.change_type = 'UPDATE'
WHEN MATCHED THEN UPDATE SET effective_to = CURRENT_DATE(), is_current = FALSE;

-- Step 3: Insert new/changed rows
INSERT INTO dim_customer (customer_id, name, city, segment, effective_from, effective_to, is_current, row_hash)
SELECT customer_id, name, city, segment, CURRENT_DATE(), NULL, TRUE, row_hash
FROM changes WHERE change_type IN ('INSERT', 'UPDATE');
```

### SCD Type 3 (Previous Value Only)
Add `previous_city` / `previous_segment` columns. MERGE shifts current → previous before updating.

**Modern alternatives:** dbt snapshots (auto SCD Type 2), Snowflake Streams (native DML tracking).

---

## Partitioning Strategies

### Snowflake
Automatic micro-partitions with clustering keys:
```sql
CREATE TABLE events (...) CLUSTER BY (event_date, event_type);
SELECT SYSTEM$CLUSTERING_INFORMATION('events', '(event_date)');
```

### BigQuery
Explicit time partitioning — always set `require_partition_filter = true`:
```sql
CREATE TABLE `project.dataset.events` (...)
PARTITION BY DATE(event_ts)
CLUSTER BY user_id, event_type
OPTIONS(partition_expiration_days = 365, require_partition_filter = true);
```

### PostgreSQL
Declarative range partitioning:
```sql
CREATE TABLE events (...) PARTITION BY RANGE (event_ts);
CREATE TABLE events_2025_01 PARTITION OF events FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_default PARTITION OF events DEFAULT;
```

### Apache Iceberg
Hidden partitioning — partition evolution is metadata-only:
```sql
CREATE TABLE catalog.db.events (...) USING iceberg PARTITIONED BY (month(event_ts), bucket(16, user_id));
ALTER TABLE catalog.db.events ADD PARTITION FIELD day(event_ts);
ALTER TABLE catalog.db.events DROP PARTITION FIELD month(event_ts);
```

---

## CDC (Change Data Capture)

### Log-Based CDC (Debezium)
Reads database WAL/binlog with zero source impact. Routes to Kafka topics.
```json
{
  "name": "pg-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "db.example.com",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_slot",
    "table.include.list": "public.orders,public.customers",
    "snapshot.mode": "initial"
  }
}
```

### dbt Incremental Microbatch (v1.9+)
```sql
{{ config(materialized='incremental', incremental_strategy='microbatch',
    event_time='event_ts', batch_size='hour', lookback=1, unique_key='event_id') }}
SELECT event_id, event_ts, user_id, event_type FROM {{ ref('stg_events') }}
```
Targeted backfill: `dbt run --event-time-start "2025-01-01" --event-time-end "2025-02-01"`

---

## Schema Evolution

Safest strategy: **only add columns, never remove or rename.** For renames, use expand-and-contract: add new column → backfill → create compatibility view → migrate consumers → drop old column.

Safe type widenings: `INT → BIGINT`, `FLOAT → DOUBLE`, `VARCHAR(50) → VARCHAR(100)`.

**Iceberg:** Tracks columns by unique ID — all changes are metadata-only.
**Delta Lake:** Schema enforcement ON by default. Enable `mergeSchema` deliberately.
**dbt:** `on_schema_change: 'append_new_columns'` for incremental models.

---

## Schema Registries

**Confluent Schema Registry:** Versioned Avro/Protobuf/JSON Schema definitions for Kafka.
- BACKWARD (default): delete fields, add optional with defaults. Consumers upgraded first.
- FORWARD: add fields, delete optional. Producers upgraded first.
- FULL: add/delete optional only. Independent upgrades.
- FULL_TRANSITIVE: same as FULL against all versions. Regulated systems.

**AWS Glue Schema Registry:** Same capabilities, serverless, IAM auth, no extra cost.

---

## Data Contracts

Formal agreements specifying column types, quality rules, SLAs, ownership, PII classification.

**dbt contracts** (`contract: enforced: true`): Enforce at build time — removing columns triggers build failure.
**Soda / Great Expectations:** Validate at runtime in the pipeline.

Pattern: consumers define expectations → producers implement and enforce → governance sets standards.

---

## Surrogate Keys (2025 Consensus)

Hash-based surrogates (MD5/SHA256 of business keys) are deterministic and idempotent:
```sql
{{ dbt_utils.generate_surrogate_key(['user_id', 'product_id']) }} AS sk
```
Same inputs = same key → enables parallel, coordination-free loading. Use natural keys when source provides stable, globally unique identifiers.

---

## Semi-Structured Data

**Snowflake VARIANT:** Dot notation + `LATERAL FLATTEN`:
```sql
SELECT e.event_id, f.value:product_id::STRING AS product_id
FROM events e, LATERAL FLATTEN(input => e.event_data:items) f;
```

**BigQuery STRUCT/ARRAY:** `UNNEST` (logical operation, no shuffle):
```sql
SELECT o.order_id, item.product_id, item.quantity
FROM orders o, UNNEST(o.items) AS item;
```

Promote stable, frequently-queried fields to first-class columns. Keep volatile attributes nested.

---

## Bi-Temporal Modeling

Two time dimensions: valid time (when fact is true in reality) + transaction time (when recorded in system).

```sql
CREATE TABLE employee_salary_bitemporal (
    employee_id INT, salary_amount DECIMAL(10,2),
    valid_from DATE, valid_to DATE DEFAULT '9999-12-31',
    system_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    system_to TIMESTAMP DEFAULT '9999-12-31 23:59:59',
    PRIMARY KEY (employee_id, valid_from, system_from)
);
```

Start with unitemporal (SCD Type 2). Upgrade to bi-temporal only with concrete audit/regulatory requirements. Snowflake Time Travel covers transaction-time for up to 90 days; BigQuery offers 7 days.

---

## Connection Pooling

### SQLAlchemy
```python
engine = create_engine(
    "postgresql+psycopg2://user:pass@host/db",
    pool_size=10, max_overflow=20,
    pool_recycle=1800,    # Prevent stale connections
    pool_pre_ping=True    # Eliminate "connection closed" errors
)
```

With PgBouncer: use `NullPool` (avoid double-pooling). PgBouncer `pool_mode=transaction` for ETL, `session` for long queries.

### asyncpg
~5x faster than psycopg3 for async. Through PgBouncer: set `statement_cache_size=0`.
