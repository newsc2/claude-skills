# SQL Conventions Reference

## CTEs Are the Default

CTEs are universally preferred for analytical SQL. In Snowflake, single-reference CTEs are pure pass-throughs with zero cost. PostgreSQL 12+ inlines them by default. BigQuery inlines aggressively.

```sql
-- Good: CTE approach — readable, each step independently testable
WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    GROUP BY customer_id
),
high_value_customers AS (
    SELECT customer_id
    FROM customer_order_counts
    WHERE order_count > 5
)
SELECT o.*
FROM orders o
JOIN high_value_customers hvc ON o.customer_id = hvc.customer_id;
```

Reserve subqueries for simple `WHERE ... IN (SELECT ...)` filters and scalar lookups.

---

## dbt Naming Conventions (Industry Standard)

### Model Prefixes
```
stg_{source}__{entity}   → Staging (double underscore separates source from entity)
int_{description}        → Intermediate transformation building blocks
fct_{entity}             → Fact tables (immutable events)
dim_{entity}             → Dimension tables (mutable entities)
rpt_{description}        → Report aggregations
```

Examples: `stg_stripe__payments`, `int_payments_pivoted_to_orders`, `fct_orders`, `dim_customers`, `rpt_monthly_revenue`

### Column Naming
```
Primary keys:   {entity}_id            (customer_id, order_id)
Surrogate keys: {entity}_sk            (customer_sk)
Timestamps:     {event}_at (UTC)       (created_at, updated_at, shipped_at)
Dates:          {event}_date           (order_date, birth_date)
Booleans:       is_{adjective}         (is_active, is_deleted)
                has_{noun}             (has_subscription, has_address)
Counts:         {entity}_count         (order_count, line_item_count)
Monetary:       {description}_amount   (total_amount_usd, discount_amount)
```

Everything `snake_case`. No abbreviations.

### Database Schemas
```
raw → staging → intermediate → marts
```

### dbt-Specific Rules
- Staging models materialize as **views** (always fresh, no storage cost)
- Staging is the **only layer** that references `source()`
- Every model has a primary key tested for `unique` and `not_null`
- Every `ref()` in a model should have a corresponding `import CTE` at the top

---

## dbt CTE Convention

Import CTEs at top (one per `ref()`), then functional CTEs, then `final`:

```sql
with

orders as (
    select * from {{ ref('stg_shopify__orders') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
),

orders_enriched as (
    select
        orders.order_id,
        orders.order_date,
        customers.customer_segment,
    from orders
    left join customers on orders.customer_id = customers.customer_id
),

final as (
    select * from orders_enriched
)

select * from final
```

---

## SQL Formatting (2025 Consensus)

- **Trailing commas** (cleaner git diffs, fewer syntax errors)
- **4-space indentation**
- **Lowercase keywords** (`select`, `from`, `where`, not `SELECT`, `FROM`)
- **Explicit `AS`** for all aliases
- **`GROUP BY 1, 2`** over column names
- **One column per line** in SELECT clauses
- SQLFluff and sqlfmt both default to this style

---

## Query Optimization Patterns

### Aggregate Early, Join Late
```sql
-- Good: aggregate before joining — far fewer rows in the join
WITH order_metrics AS (
    SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total_spend
    FROM orders
    GROUP BY customer_id
)
SELECT c.name, om.order_count, om.total_spend
FROM customers c
LEFT JOIN order_metrics om ON c.id = om.customer_id;
```

### Window Functions Over Self-Joins
```sql
-- Good: QUALIFY (Snowflake/BigQuery) for "latest per group"
SELECT * FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1;

-- Equivalent for PostgreSQL (no QUALIFY)
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
)
SELECT * FROM ranked WHERE rn = 1;
```

### Other High-Impact Patterns
- Explicitly list columns instead of `SELECT *` in columnar warehouses
- Filter on partition/cluster keys for partition pruning
- Push predicates INTO CTEs rather than applying after joins
- Use `COALESCE` / `NULLIF` instead of `CASE WHEN ... IS NULL`
- Avoid `DISTINCT` as a band-aid for duplicates — fix the join or dedup explicitly

---

## Common SQL Anti-Patterns

### 1. Correlated Subqueries
**Bad:** Executes inner query once per outer row.
**Fix:** Rewrite as CTE + JOIN.

### 2. Implicit Type Coercion
```sql
-- Bad: comparing VARCHAR to integer prevents index usage
WHERE user_id = 12345

-- Good: match the column type
WHERE user_id = '12345'
```

### 3. Not Using Window Functions
```sql
-- Bad: self-join for running totals
SELECT a.date, SUM(b.amount)
FROM orders a JOIN orders b ON b.date <= a.date
GROUP BY a.date;

-- Good: window function
SELECT date, SUM(amount) OVER (ORDER BY date) AS running_total
FROM orders;
```

### 4. SELECT * in Columnar Stores
Columnar warehouses (Snowflake, BigQuery, Redshift) store data by column — `SELECT *` scans every column even if you only need 2. Specify columns explicitly.

### 5. N+1 Query Pattern
Application code loops over rows and executes a query per row. Fix: batch with `WHERE id IN (...)` or single query with JOIN.

### 6. Self-Joins for Deduplication
```sql
-- Bad: self-join
SELECT a.* FROM orders a
JOIN (SELECT customer_id, MAX(order_date) AS max_date FROM orders GROUP BY customer_id) b
ON a.customer_id = b.customer_id AND a.order_date = b.max_date;

-- Good: window function
SELECT * FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1;
```

### 7. Using DISTINCT to Mask Bad Joins
If you need DISTINCT, the join logic is probably wrong. Check for fanout: `SELECT COUNT(*) FROM table_a JOIN table_b ON ...` — if row count increases unexpectedly, the join key isn't unique on one side.

---

## dbt Macros for DRY SQL

Extract repeated logic into macros when it appears in 3+ models:

```sql
-- macros/decode_order_status.sql
{% macro decode_order_status(column_name) %}
    case
        when {{ column_name }} = 0 then 'pending'
        when {{ column_name }} = 1 then 'shipped'
        when {{ column_name }} = 2 then 'delivered'
        when {{ column_name }} = 3 then 'returned'
    end
{% endmacro %}
```

Use Jinja loops for repetitive column definitions:
```sql
{% set methods = ['credit_card', 'bank_transfer', 'gift_card'] %}
select
    order_id,
    {% for method in methods %}
    sum(case when payment_method = '{{ method }}' then amount else 0 end) as {{ method }}_amount{% if not loop.last %},{% endif %}
    {% endfor %}
from payments
group by order_id
```

CTEs duplicated across models → extract into intermediate models (`int_*`), not macros. Macros are for logic; models are for data dependencies.
