# Schema, Contracts, and Lineage Reference

Read this file when enforcing schemas, writing data contracts, tracking lineage, or building documentation-as-code.

---

## Schema Enforcement

### Choosing an Enforcement Level

```
LEVEL 1 — Detect (log schema mismatches, don't block):
  Compare incoming columns/types against expected schema YAML
  Alert on drift, quarantine unexpected fields
  USE WHEN: exploring new sources, low-trust but non-critical data

LEVEL 2 — Warn (validate and flag, allow pipeline to continue):
  Pandera schema with coerce=False, raise_warning=True
  dbt tests with severity: warn
  USE WHEN: medium-criticality data, transitional period

LEVEL 3 — Enforce (reject data that violates schema):
  Pandera with strict=True (rejects extra columns) + raise on failure
  dbt model contracts (contract.enforced: true)
  PostgreSQL CHECK constraints + NOT NULL
  USE WHEN: Tier 1 production data, financial systems, ML feature stores
```

### Pandera Schema Patterns

```python
# Class-based (preferred — mypy-compatible, decorator-friendly)
import pandera as pa
from pandera.typing import Series, DataFrame

class OrderSchema(pa.DataFrameModel):
    order_id: Series[str] = pa.Field(nullable=False, unique=True)
    amount: Series[float] = pa.Field(ge=0, le=100_000)
    status: Series[str] = pa.Field(isin=["pending", "completed", "cancelled"])
    created_at: Series[pa.DateTime] = pa.Field(nullable=False)

    class Config:
        strict = True      # reject unexpected columns
        coerce = True       # auto-cast types (use cautiously)
        ordered = True      # enforce column order

# Validate at function boundary
@pa.check_types
def process_orders(df: DataFrame[OrderSchema]) -> DataFrame[OrderSchema]:
    ...  # Pandera validates input AND output automatically
```

```python
# YAML schema (for config-driven validation)
# Save as order_schema.yml, load with pa.DataFrameSchema.from_yaml()
schema_type: dataframe
columns:
  order_id: {dtype: str, nullable: false, unique: true}
  amount: {dtype: float64, nullable: false, checks: {ge: 0, le: 100000}}
  status: {dtype: str, nullable: false, checks: {isin: ["pending", "completed", "cancelled"]}}
```

### Schema Drift Detection Pattern

```python
def detect_schema_drift(df, expected_schema: dict) -> dict:
    """Compare DataFrame against expected schema. Returns drift report."""
    actual_cols = set(df.columns)
    expected_cols = set(expected_schema.keys())

    report = {
        "new_columns": list(actual_cols - expected_cols),      # appeared
        "missing_columns": list(expected_cols - actual_cols),   # disappeared
        "type_changes": [],
    }
    for col in actual_cols & expected_cols:
        actual_type = str(df[col].dtype)
        expected_type = expected_schema[col]["dtype"]
        if actual_type != expected_type:
            report["type_changes"].append({
                "column": col, "expected": expected_type, "actual": actual_type
            })

    # Severity classification
    if report["missing_columns"] or report["type_changes"]:
        report["severity"] = "CRITICAL"
    elif report["new_columns"]:
        report["severity"] = "WARNING"
    else:
        report["severity"] = "PASS"
    return report
```

---

## Data Contracts

### What a Data Contract Contains

```
REQUIRED:
  - Schema: column names, types, nullability, uniqueness constraints
  - Ownership: who produces this data, who to contact
  - SLAs: freshness guarantee, availability uptime target
  - Quality rules: minimum quality checks that must pass

RECOMMENDED:
  - Semantic descriptions: what each column means, business definitions
  - Valid value ranges and accepted enumerations
  - Change management: how changes are communicated, deprecation timeline
  - Versioning: semver for breaking vs non-breaking changes

OPTIONAL:
  - Lineage: upstream sources, transformation logic summary
  - Sample data: representative examples
  - Consumer registry: who uses this data and for what
```

### dbt Model Contracts (for SQL-layer enforcement)

```yaml
models:
  - name: fct_orders
    config:
      contract:
        enforced: true            # build fails if output doesn't match
    columns:
      - name: order_id
        data_type: varchar        # exact type enforced at build time
        constraints:
          - type: not_null
          - type: primary_key     # composite PKs: put on all key columns
      - name: amount
        data_type: numeric(10,2)
        constraints:
          - type: not_null
          - type: check
            expression: "amount >= 0"
      - name: status
        data_type: varchar
```

```
CONTRACTS vs TESTS:
  Contract → "this column WILL BE varchar not-null" → prevents structural errors at build time
  Test → "this column's values SHOULD be in [a, b, c]" → catches data errors at run time
  USE BOTH: contracts for structure, tests for values.
```

### Breaking Change Protocol

```
IF change is additive (new column, new enum value) → non-breaking
  → Add to contract, deploy, notify consumers

IF change is destructive (drop column, rename column, change type) → breaking
  → 1. Announce 90+ days before removal
  → 2. Dual-write old + new fields for 60 days
  → 3. Send final warning to remaining consumers at 30 days
  → 4. Remove old field
  → 5. Update contract version (major version bump)

IF change is behavioral (same column, different meaning) → breaking
  → Treat as rename: create new column with new name + semantics
  → Deprecate old column following protocol above
```

---

## Data Lineage

### When Lineage Matters

```
IF debugging a data issue → trace upstream to find root cause
IF assessing change impact → trace downstream to find affected consumers
IF building trust → show users where data comes from and how it's transformed
IF regulatory/compliance → prove data handling meets requirements
```

### Lightweight Lineage Without Heavy Infrastructure

```
LEVEL 1 — Code-level lineage (free, always available):
  - SQL: document source tables in comments at top of each query/model
  - dbt: ref() and source() functions create automatic DAG
  - Python: docstrings listing input/output datasets on each function

LEVEL 2 — dbt lineage (if using dbt):
  - dbt docs generate → interactive DAG with column descriptions
  - Column-level lineage via dbt 1.7+ or Elementary
  - Exposure definitions to connect models → dashboards/ML systems

LEVEL 3 — OpenLineage (for cross-system lineage):
  - Standard JSON events: Job → Run → Dataset with Facets
  - Native integration with Airflow (v2.7+), Spark, dbt
  - Backend: Marquez (open source) for storage + API + web UI
  - Column-level: SQLGlot parses SQL AST for column-level tracking
```

### Documentation-as-Code Patterns

```
PRINCIPLE: Define once, generate everywhere. Never maintain separate docs.

PATTERN 1 — dbt YAML descriptions (SQL layer):
  Write column descriptions in schema.yml
  dbt docs generate → interactive HTML site
  Descriptions appear in IDE, docs site, and data catalog

PATTERN 2 — Pandera schema + docstrings (Python layer):
  DataFrameModel class docstring = table description
  Field descriptions via pa.Field(description="...")
  Export schema to YAML/JSON for non-Python consumers

PATTERN 3 — Standalone YAML data dictionary:
  One YAML file per dataset/domain
  Stored in Git alongside code
  CI/CD validates that dictionary matches actual schema
  Template:
    dataset: orders
    owner: data-engineering@company.com
    grain: one row per order
    freshness_sla: 4 hours
    columns:
      order_id:
        type: string
        description: Unique order identifier from checkout system
        nullable: false
        pii: false
      amount:
        type: decimal(10,2)
        description: Order total after discounts, before tax, in USD
        valid_range: [0, 100000]
```

### Data Dictionary Checklist

For every column in a documented dataset:

```
- [ ] Human-readable description (not just the column name restated)
- [ ] Data type with precision where applicable
- [ ] Nullable? If yes, what does null mean?
- [ ] Unique? Part of primary key?
- [ ] Valid value range or accepted values list
- [ ] Unit of measurement (USD, milliseconds, count, percentage as 0–1 or 0–100)
- [ ] PII flag (contains personally identifiable information?)
- [ ] Source: where does this value originate?
- [ ] Transform: any derivation logic? (e.g., "amount = subtotal * (1 + tax_rate) - discount")
```
