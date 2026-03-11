# Ingestion Patterns Reference

## Pagination Strategies

### Cursor-Based (default for production)
Opaque token pointing to last item. Stable under concurrent writes, consistent performance regardless of depth. Used by Stripe, Slack, GitHub.

```python
import httpx

async def fetch_all_cursor(api_url: str, api_key: str, page_size: int = 100) -> list[dict]:
    all_items, cursor, has_more = [], None, True
    async with httpx.AsyncClient(timeout=30.0) as client:
        while has_more:
            params = {"limit": page_size}
            if cursor:
                params["starting_after"] = cursor
            resp = await client.get(api_url, headers={"Authorization": f"Bearer {api_key}"}, params=params)
            resp.raise_for_status()
            data = resp.json()
            items = data.get("data", [])
            all_items.extend(items)
            has_more = data.get("has_more", False)
            if items:
                cursor = items[-1]["id"]
    return all_items
```

### Keyset Pagination
Transparent cursor using real column values (typically `(timestamp, id)` composite). Maps to `WHERE (created_at, id) < (:last_ts, :last_id)` — leverages indexes efficiently. Best for time-series logs.

### Offset Pagination
Simple but degrades on large datasets (DB must skip all preceding rows). Concurrent writes cause page drift. Reserve for small admin UIs where page numbers are needed.

**Decision:** Cursor/keyset for production. Offset only for small, static datasets.

---

## Rate Limiting

### Respecting 429 + Retry-After
```python
from tenacity import retry, stop_after_attempt, retry_if_exception_type
import httpx

class RateLimitError(Exception):
    def __init__(self, retry_after: float):
        self.retry_after = retry_after

def wait_for_retry_after(retry_state):
    exc = retry_state.outcome.exception()
    if isinstance(exc, RateLimitError):
        return exc.retry_after
    return min(2 ** retry_state.attempt_number, 60)

@retry(retry=retry_if_exception_type(RateLimitError), wait=wait_for_retry_after, stop=stop_after_attempt(5))
def api_call(client: httpx.Client, url: str) -> dict:
    resp = client.get(url)
    if resp.status_code == 429:
        raise RateLimitError(float(resp.headers.get("Retry-After", 5)))
    resp.raise_for_status()
    return resp.json()
```

### Client-Side Token Bucket
```python
import time, asyncio

class TokenBucket:
    def __init__(self, rate: float, capacity: int):
        self.rate = rate
        self.capacity = capacity
        self.tokens = capacity
        self._last_refill = time.monotonic()
        self._lock = asyncio.Lock()

    async def acquire(self):
        async with self._lock:
            now = time.monotonic()
            self.tokens = min(self.capacity, self.tokens + (now - self._last_refill) * self.rate)
            self._last_refill = now
            if self.tokens < 1:
                await asyncio.sleep((1 - self.tokens) / self.rate)
                self.tokens = 0
            else:
                self.tokens -= 1
```

---

## OAuth2 Token Rotation

httpx's `Auth` class provides auto-refreshing auth:

```python
import httpx, time
from typing import Generator

class OAuth2TokenAuth(httpx.Auth):
    requires_response_body = True

    def __init__(self, client_id: str, client_secret: str, token_url: str,
                 access_token: str = "", refresh_token: str = "", expires_at: float = 0):
        self.client_id, self.client_secret = client_id, client_secret
        self.token_url = token_url
        self.access_token, self.refresh_token = access_token, refresh_token
        self.expires_at = expires_at

    def auth_flow(self, request: httpx.Request) -> Generator[httpx.Request, httpx.Response, None]:
        if time.time() > (self.expires_at - 60):  # Proactive refresh
            response = yield self._build_refresh_request()
            self._update_tokens(response)
        request.headers["Authorization"] = f"Bearer {self.access_token}"
        response = yield request
        if response.status_code == 401:
            refresh_resp = yield self._build_refresh_request()
            self._update_tokens(refresh_resp)
            request.headers["Authorization"] = f"Bearer {self.access_token}"
            yield request

    def _build_refresh_request(self) -> httpx.Request:
        return httpx.Request("POST", self.token_url, data={
            "grant_type": "refresh_token", "refresh_token": self.refresh_token,
            "client_id": self.client_id, "client_secret": self.client_secret,
        })

    def _update_tokens(self, response: httpx.Response):
        data = response.json()
        self.access_token = data["access_token"]
        self.refresh_token = data.get("refresh_token", self.refresh_token)
        self.expires_at = time.time() + data.get("expires_in", 3600)
```

For standard OAuth2 flows, Authlib (v1.6) handles refresh automatically with `update_token` callback.

---

## Incremental Loading (High-Water Mark)

```python
import json, httpx
from datetime import datetime, timezone
from pathlib import Path

class HighWaterMarkIngester:
    def __init__(self, api_url: str, state_file: str = "watermark.json"):
        self.api_url = api_url
        self.state_file = Path(state_file)

    def _load_watermark(self) -> str | None:
        if self.state_file.exists():
            return json.loads(self.state_file.read_text()).get("last_modified")
        return None

    def _save_watermark(self, watermark: str):
        self.state_file.write_text(json.dumps({
            "last_modified": watermark,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }))

    def ingest(self) -> list[dict]:
        watermark = self._load_watermark()
        params = {"sort": "updated_at", "limit": 100}
        params["updated_after"] = watermark or "1970-01-01T00:00:00Z"
        all_records, max_seen = [], watermark or ""

        with httpx.Client(timeout=60.0) as client:
            cursor = None
            while True:
                if cursor:
                    params["cursor"] = cursor
                data = client.get(self.api_url, params=params).json()
                records = data.get("data", [])
                if not records:
                    break
                for r in records:
                    max_seen = max(max_seen, r["updated_at"])
                all_records.extend(records)
                cursor = data.get("next_cursor")
                if not cursor:
                    break

        if max_seen and max_seen != watermark:
            self._save_watermark(max_seen)
        return all_records
```

Requirements: source must expose a monotonically increasing field. Deletes need soft-delete flags or CDC. For multi-source pipelines, replace JSON with SQLite-backed watermark store keyed by `source_id`.

---

## Backfill Strategies

### Core Principles
- Same code path for daily runs and backfills (parameterized by date)
- Partition overwrite for idempotency
- Throttle between chunks to protect source systems
- Never hardcode `datetime.now()`

### Parallel Date-Chunking
```python
from datetime import date, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

def backfill_date_range(start: date, end: date, process_fn, parallel: int = 4):
    dates = []
    current = start
    while current <= end:
        dates.append(current)
        current += timedelta(days=1)

    results = {"success": [], "failed": []}
    with ThreadPoolExecutor(max_workers=parallel) as executor:
        futures = {executor.submit(process_fn, d): d for d in dates}
        for future in as_completed(futures):
            d = futures[future]
            try:
                future.result()
                results["success"].append(d)
            except Exception as e:
                results["failed"].append((d, str(e)))
    return results
```

### Shadow Table Pattern (zero-downtime)
```sql
CREATE TABLE analytics.fct_events_shadow LIKE analytics.fct_events;
INSERT INTO analytics.fct_events_shadow SELECT /* corrected transforms */ FROM raw.events;
-- Validate row counts + checksums
ALTER TABLE analytics.fct_events SWAP WITH analytics.fct_events_shadow;
```

---

## Defensive Schema Parsing

```python
from pydantic import BaseModel, Field, model_validator, ConfigDict, ValidationError

class FlexibleAPIResponse(BaseModel):
    model_config = ConfigDict(extra="allow", populate_by_name=True)
    id: str
    name: str
    email: str | None = None
    status: str = Field(default="unknown", alias="state")

    @model_validator(mode="before")
    @classmethod
    def handle_schema_evolution(cls, data: dict) -> dict:
        if "user_name" in data and "name" not in data:
            data["name"] = data.pop("user_name")
        if isinstance(data.get("status"), int):
            data["status"] = {0: "inactive", 1: "active"}.get(data["status"], "unknown")
        return data

def parse_batch_defensive(records: list[dict], model: type[BaseModel]):
    valid, errors = [], []
    for i, record in enumerate(records):
        try:
            valid.append(model.model_validate(record))
        except ValidationError as e:
            errors.append({"index": i, "record": record, "errors": e.errors()})
    return valid, errors
```

---

## Async Ingestion

```python
import asyncio, httpx

async def fetch_all_endpoints(urls: list[str], max_concurrent: int = 10) -> list[dict]:
    semaphore = asyncio.Semaphore(max_concurrent)
    async def fetch_one(client: httpx.AsyncClient, url: str) -> dict:
        async with semaphore:
            resp = await client.get(url, timeout=30.0)
            resp.raise_for_status()
            return resp.json()

    async with httpx.AsyncClient(
        limits=httpx.Limits(max_connections=max_concurrent, max_keepalive_connections=5),
    ) as client:
        results = await asyncio.gather(*[fetch_one(client, url) for url in urls], return_exceptions=True)
    return [r for r in results if not isinstance(r, Exception)]
```

### HTTP Client Selection
- **httpx (default):** Async + sync, HTTP/2, custom auth flows, type hints
- **aiohttp:** 5–10x faster at very high concurrency (100+ connections), less ergonomic API
- **requests:** Legacy only

### When async helps
Parallel API calls (biggest win — 2.5hr → 7min), fan-out DB reads, WebSocket ingestion.

### When to avoid async
Simple sequential ETL, CPU-bound transforms, <50 API calls (threading suffices), Jupyter.
