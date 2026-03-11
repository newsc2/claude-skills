# Python Patterns Reference

## Pydantic v2 at Pipeline Boundaries

Use Pydantic v2 (v2.12+) where data enters or exits the system. Use dataclasses for internal DTOs.

### Key Patterns

```python
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator, computed_field
from typing import Annotated
from datetime import datetime

class PipelineDTO(BaseModel):
    """Base model with production defaults."""
    model_config = ConfigDict(
        from_attributes=True,       # ORM objects → models
        extra="forbid",             # Fail fast on unknown fields (catches schema drift)
        str_strip_whitespace=True,  # Auto-strip string inputs
        frozen=True,                # Immutable after creation
    )

class SalesRecord(PipelineDTO):
    id: Annotated[int, Field(ge=1)]
    product_name: Annotated[str, Field(min_length=1, max_length=200)]
    quantity: Annotated[int, Field(ge=0)]
    unit_price: Annotated[float, Field(ge=0.0)]
    sale_date: datetime
    region: Annotated[str, Field(pattern=r"^[A-Z]{2}$")]

    @computed_field
    @property
    def total_revenue(self) -> float:
        return self.quantity * self.unit_price
```

**Performance tip:** Use `Annotated` constraints instead of `@field_validator` — ~30x faster at scale because Annotated runs in Rust while field validators always execute in Python.

**Bulk validation:** Use `TypeAdapter` for batch processing:
```python
from pydantic import TypeAdapter
adapter = TypeAdapter(list[SalesRecord])
validated = adapter.validate_python(batch_of_dicts)     # From dicts
validated = adapter.validate_json(json_bytes)           # From JSON (even faster)
```

### When to use what
- **Pydantic** → pipeline boundaries (API responses, file loads, database results)
- **dataclasses** → internal DTOs passed between functions
- **attrs** → library code with minimal dependencies

---

## Protocols for Pluggable Pipeline Components

```python
from typing import Protocol, runtime_checkable
import pandas as pd

@runtime_checkable
class Extractor(Protocol):
    def extract(self) -> pd.DataFrame: ...

@runtime_checkable
class Transformer(Protocol):
    def transform(self, data: pd.DataFrame) -> pd.DataFrame: ...

@runtime_checkable
class Loader(Protocol):
    def load(self, data: pd.DataFrame) -> None: ...
```

Classes satisfy the interface by having the right methods — no inheritance required. Use Protocols for interfaces external code implements. Use ABCs when you control the hierarchy and want shared concrete methods.

---

## Type Hints

Use modern syntax (Python 3.10+):
- `X | None` over `Optional[X]`
- `list[int]` over `List[int]`
- `TypedDict` for unvalidated dict schemas
- `ParamSpec` + `TypeVar` for decorators preserving signatures

Run `mypy --strict` in CI. Zero runtime cost.

---

## Idempotency Patterns

### UPSERT/MERGE

**PostgreSQL:**
```sql
INSERT INTO customers (customer_id, name, email, updated_at)
VALUES (101, 'Acme Corp', 'new@acme.com', '2024-06-15')
ON CONFLICT (customer_id)
DO UPDATE SET
    name = EXCLUDED.name, email = EXCLUDED.email, updated_at = EXCLUDED.updated_at
WHERE EXCLUDED.updated_at > customers.updated_at;
```

**Snowflake** (pre-deduplicate source to avoid nondeterministic results):
```sql
MERGE INTO target AS t
USING (
    SELECT order_id, MAX(amount) AS amount, MAX(updated_at) AS updated_at
    FROM staging GROUP BY order_id
) AS s ON t.order_id = s.order_id
WHEN MATCHED THEN UPDATE SET t.amount = s.amount, t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (order_id, amount, updated_at)
    VALUES (s.order_id, s.amount, s.updated_at);
```

**BigQuery** (supports `WHEN NOT MATCHED BY SOURCE THEN DELETE`):
```sql
-- Atomic full replace without JOIN overhead
MERGE INTO `project.dataset.target` AS T
USING `project.dataset.source` AS S
ON FALSE
WHEN NOT MATCHED BY SOURCE THEN DELETE
WHEN NOT MATCHED THEN INSERT ROW;
```

### Partition-Based Overwrite
```sql
BEGIN TRANSACTION;
DELETE FROM fact_orders WHERE order_date = '2024-01-15';
INSERT INTO fact_orders SELECT * FROM staging_orders WHERE order_date = '2024-01-15';
COMMIT;
```
The transaction wrapper is critical — without it, a failure between DELETE and INSERT loses data.

In Spark: `spark.conf.set('spark.sql.sources.partitionOverwriteMode', 'dynamic')`

### Deterministic File Naming
```python
def get_output_path(base: str, pipeline: str, partition_date: str, source: str) -> str:
    return f"{base}/{pipeline}/date={partition_date}/{source}.parquet"
```
In Airflow, always use `{{ ds }}` (logical execution date), not wall-clock time.

### Deduplication Pattern
```sql
WITH clean_batch AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_timestamp DESC) AS rn
    FROM staging_events
)
SELECT * FROM clean_batch WHERE rn = 1;
```

### Hybrid Strategy
Incremental merges daily for efficiency + full refresh weekly to catch drift and handle hard deletes.

---

## Error Handling

### Exception Hierarchy
```python
class PipelineError(Exception):
    def __init__(self, message: str, *, stage: str = "", record_id: str = ""):
        super().__init__(message)
        self.stage = stage
        self.record_id = record_id

class TransientError(PipelineError): pass   # → retry
class UpstreamTimeoutError(TransientError): pass
class RateLimitError(TransientError):
    def __init__(self, message: str, retry_after: float = 0, **kwargs):
        super().__init__(message, **kwargs)
        self.retry_after = retry_after

class PermanentError(PipelineError): pass   # → DLQ
class SchemaValidationError(PermanentError): pass
class DataQualityError(PermanentError): pass
```

### Tenacity Retry Patterns (v9.1.4)
```python
from tenacity import retry, stop_after_attempt, wait_random_exponential, retry_if_exception_type, before_sleep_log
import logging

logger = logging.getLogger(__name__)

@retry(
    stop=stop_after_attempt(5),
    wait=wait_random_exponential(multiplier=1, max=60),
    retry=retry_if_exception_type(TransientError),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def resilient_api_call(url: str) -> dict:
    return httpx.get(url).json()
```

Always set `stop_after_attempt()`. Always use jitter (`wait_random_exponential`). Always `reraise=True`.

### Dead Letter Queue
```python
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
import json, traceback

@dataclass
class DeadLetterRecord:
    original_record: str
    error_type: str
    error_message: str
    traceback: str
    pipeline_stage: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

class DeadLetterQueue:
    def __init__(self, path: str = "dead_letter_queue.jsonl"):
        self.path = path
    def send(self, record, exception: Exception, pipeline_stage: str):
        dl = DeadLetterRecord(
            original_record=repr(record), error_type=type(exception).__name__,
            error_message=str(exception), traceback=traceback.format_exc(),
            pipeline_stage=pipeline_stage,
        )
        with open(self.path, "a") as f:
            f.write(json.dumps(asdict(dl), default=str) + "\n")
```

### Continue vs Fail-Fast
- **Continue-on-error** for independent records (batch ETL): accumulate PermanentErrors in DLQ
- **Fail-fast** for ordered/dependent records (CDC, financial): any TransientError aborts
- **Abort on threshold:** If success rate < 50%, stop entire batch

---

## Structured Logging (structlog v25.5.0)

```python
import structlog

log = structlog.get_logger("pipeline").bind(run_id="run-abc-123", stage="transform")
log.info("dedup_complete", removed=230, output_rows=14770)
# {"event":"dedup_complete","removed":230,"output_rows":14770,"run_id":"run-abc-123",...}
```

Every stage should emit: input_rows, output_rows, error_rows, duration_seconds.

### Correlation IDs
```python
import contextvars, uuid
correlation_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("correlation_id")
def new_pipeline_run() -> str:
    cid = str(uuid.uuid4())
    correlation_id_var.set(cid)
    return cid
```

---

## Testing

### Test Pyramid
- **Bottom (most tests):** Unit tests on pure transform functions + data quality checks
- **Middle:** Integration tests with testcontainers (real Postgres/MySQL in Docker)
- **Top (fewest):** End-to-end pipeline runs

### DuckDB for SQL Testing
```python
import duckdb, pytest

@pytest.fixture
def con():
    conn = duckdb.connect(":memory:")
    conn.execute("CREATE TABLE raw AS SELECT * FROM (VALUES (1, 100), (2, -50)) AS t(id, amount)")
    yield conn
    conn.close()

def test_filters_negatives(con):
    result = con.execute("SELECT * FROM raw WHERE amount >= 0").fetchdf()
    assert len(result) == 1
```

### Hypothesis for Property-Based Testing
```python
from hypothesis import given
from hypothesis import strategies as st

@given(df=order_dataframes())
def test_clean_is_idempotent(df):
    once = clean_revenue(df)
    twice = clean_revenue(once)
    pd.testing.assert_frame_equal(once, twice)
```

---

## Configuration (pydantic-settings v2.13)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import SecretStr, Field

class PipelineSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="PIPELINE_")
    database_url: str
    api_key: SecretStr
    batch_size: int = 1000
    debug: bool = False
```

`SecretStr` prevents credentials leaking into logs. Use env vars for all secrets.

---

## Docker Multi-Stage Build with uv

```dockerfile
FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.10.4 /uv /uvx /bin/
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-install-project --no-dev
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev --no-editable

FROM python:3.13-slim AS runtime
RUN groupadd -g 1001 app && useradd -u 1001 -g app -m app
WORKDIR /app
COPY --from=builder --chown=app:app /app/.venv /app/.venv
COPY --from=builder --chown=app:app /app/src /app/src
ENV PATH="/app/.venv/bin:$PATH"
USER app
ENTRYPOINT ["python", "-m", "data_pipeline.main"]
```

Copy `pyproject.toml` + `uv.lock` BEFORE source code for layer cache optimization.
