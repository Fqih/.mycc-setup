---
name: sql-patterns
description: Use when writing SQL queries — optimization, indexing, CTE, window functions, query plans, warehouse-specific patterns (Postgres, BigQuery, Snowflake, ClickHouse, DuckDB). Trigger on "sql", "query", "select", "join", "explain analyze", "CTE".
---

# sql-patterns

SQL patterns untuk query yang benar (correctness) + cepat (performance). Database-agnostic + per-engine optimization.

## Query writing principles

1. **Read query plan first** (`EXPLAIN ANALYZE`) — optimize yang jalan, bukan yang terlihat
2. **Filter early** (WHERE) — kurangi row count sebelum JOIN/AGGREGATE
3. **Project early** (SELECT specific columns, bukan `*`) — kurangi I/O
4. **Index what you query** — B-tree untuk equality/range, GIN untuk JSON/full-text, BRIN untuk time-series
5. **Avoid N+1** — satu JOIN atau aggregated query, bukan loop di app

## CTE vs subquery

```sql
-- ❌ Subquery (hard to read, often re-evaluated)
SELECT *
FROM orders o
WHERE user_id IN (SELECT id FROM users WHERE country = 'ID');

-- ✅ CTE (readable, optimizer-friendly in modern engines)
WITH id_users AS (
    SELECT id FROM users WHERE country = 'ID'
)
SELECT o.*
FROM orders o
JOIN id_users u ON o.user_id = u.id;
```

CTE `WITH ... AS` chain untuk complex queries. PostgreSQL 12+ inlines simple CTEs (treated as subquery, no materialization overhead).

## Window functions

```sql
-- Ranking
SELECT
    user_id,
    order_date,
    amount,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date DESC) AS rn,
    RANK() OVER (PARTITION BY user_id ORDER BY amount DESC) AS amt_rank
FROM orders;

-- Running totals
SELECT
    order_date,
    amount,
    SUM(amount) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM orders;

-- Lag/lead
SELECT
    order_date,
    amount,
    LAG(amount) OVER (PARTITION BY user_id ORDER BY order_date) AS prev_amount,
    amount - LAG(amount) OVER (PARTITION BY user_id ORDER BY order_date) AS diff
FROM orders;
```

## Pagination

```sql
-- ❌ OFFSET (slow untuk large offsets — DB scans + skips rows)
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 100000;

-- ✅ Cursor-based (stable, fast)
SELECT * FROM users WHERE id > :last_seen_id ORDER BY id LIMIT 20;
```

Cursor pagination ideal untuk infinite scroll, large datasets.

## Anti-patterns

### ❌ SELECT *
```sql
-- Bad
SELECT * FROM users;

-- Good (jauh lebih cepat di large tables)
SELECT id, name, email FROM users;
```

### ❌ Function on indexed column
```sql
-- Bad (index tidak dipakai)
SELECT * FROM users WHERE LOWER(email) = 'foo@bar.com';

-- Good (functional index atau normalized data)
CREATE INDEX idx_users_email_lower ON users (LOWER(email));
-- atau
SELECT * FROM users WHERE email = 'foo@bar.com';  -- store normalized
```

### ❌ OR conditions
```sql
-- Bad (often full table scan)
SELECT * FROM users WHERE name = 'X' OR email = 'X';

-- Good (UNION ALL atau IN)
SELECT * FROM users WHERE name = 'X'
UNION ALL
SELECT * FROM users WHERE email = 'X' AND name != 'X';
```

### ❌ NOT IN with NULLs
```sql
-- Bad (returns no rows if any NULL)
SELECT * FROM users WHERE id NOT IN (SELECT user_id FROM banned);

-- Good
SELECT * FROM users WHERE id NOT IN (
    SELECT user_id FROM banned WHERE user_id IS NOT NULL
);
-- atau lebih clean
SELECT u.* FROM users u
LEFT JOIN banned b ON u.id = b.user_id
WHERE b.user_id IS NULL;
```

### ❌ Implicit type cast
```sql
-- Bad (idx_users_phone tidak terpakai karena cast)
SELECT * FROM users WHERE phone = 6281234567890;

-- Good (matching type)
SELECT * FROM users WHERE phone = '6281234567890';
```

### ❌ Cartesian explosion
```sql
-- Bad (no join condition)
SELECT * FROM orders, users;

-- Good
SELECT * FROM orders o JOIN users u ON o.user_id = u.id;
```

## Index strategy

```sql
-- B-tree (default): equality, range
CREATE INDEX idx_orders_user_date ON orders (user_id, order_date DESC);

-- Composite index order matters
-- idx_orders_user_date berguna untuk:
--   WHERE user_id = X
--   WHERE user_id = X AND order_date BETWEEN ... AND ...
--   WHERE user_id = X ORDER BY order_date DESC
-- TIDAK berguna untuk:
--   WHERE order_date BETWEEN ... (user_id harus leading)

-- Partial index (subset of rows)
CREATE INDEX idx_active_users ON users (email) WHERE deleted_at IS NULL;

-- GIN (JSONB, full-text, array)
CREATE INDEX idx_users_metadata ON users USING gin (metadata);
CREATE INDEX idx_articles_fts ON articles USING gin (to_tsvector('english', body));

-- BRIN (large time-series tables)
CREATE INDEX idx_events_time ON events USING brin (created_at);
```

## Query plan reading

```sql
EXPLAIN ANALYZE
SELECT u.name, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.country = 'ID'
GROUP BY u.id;
```

Output (Postgres):
```
HashAggregate  (cost=X..Y rows=Z) (actual time=A..B rows=C)
  Group Key: u.id
  ->  Hash Left Join  (cost=X..Y rows=Z) (actual time=A..B rows=C)
        Hash Cond: (o.user_id = u.id)
        ->  Seq Scan on orders o  ← ⚠️ full table scan
        ->  Hash  (cost=X..Y rows=Z) (actual time=A..B rows=C)
              ->  Seq Scan on users u
                    Filter: (country = 'ID')
```

Red flags:
- **Seq Scan** pada large tables (perlu index)
- **Nested Loop** dengan outer table besar (consider Hash Join)
- **Sort** di memory high (`Sort Method: external merge Disk:`)
- **Actual rows** jauh lebih besar dari **estimated rows** (stale stats — run `ANALYZE`)

## Common optimization patterns

### Batch delete/update
```sql
-- Bad (locks table, large transaction)
DELETE FROM events WHERE created_at < '2020-01-01';

-- Good (batch by batch)
DELETE FROM events
WHERE id IN (
    SELECT id FROM events
    WHERE created_at < '2020-01-01'
    LIMIT 10000
);
-- Repeat sampai 0 rows affected
```

### Upsert
```sql
INSERT INTO users (id, name, email)
VALUES (1, 'X', 'x@bar.com')
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name, email = EXCLUDED.email;
```

### Recursive CTE (tree traversal)
```sql
WITH RECURSIVE org_tree AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.id, e.name, e.manager_id, t.depth + 1
    FROM employees e
    JOIN org_tree t ON e.manager_id = t.id
)
SELECT * FROM org_tree ORDER BY depth, name;
```

## Per-engine notes

### PostgreSQL

```sql
-- JSONB query
SELECT * FROM events
WHERE metadata @> '{"source": "web"}';

-- Full-text search
SELECT * FROM articles
WHERE to_tsvector('english', body) @@ to_tsquery('english', 'database & optimization');

-- Upsert with RETURNING
INSERT INTO ... ON CONFLICT ... DO UPDATE ...
RETURNING id, created_at;

-- Listen/notify untuk real-time
LISTEN new_order;
```

### BigQuery

```sql
-- Partitioning + clustering
CREATE TABLE events (
    id INT64,
    event_date DATE,
    user_id INT64
)
PARTITION BY event_date
CLUSTER BY user_id;

-- Approximate count (cheap)
SELECT APPROX_COUNT_DISTINCT(user_id) FROM events;

-- Window with QUALIFY
SELECT *
FROM (
    SELECT
        user_id,
        event_date,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC) AS rn
    FROM events
)
WHERE rn = 1
QUALIFY rn = 1;  -- BigQuery-specific
```

BigQuery optimization:
- Avoid `SELECT *` (full scan even of partitioned columns)
- Use partition pruning (`WHERE event_date BETWEEN ...`)
- Cluster by frequently filtered columns
- Use `APPROX_*` functions for large cardinality counts

### ClickHouse

```sql
-- Specialized aggregations
SELECT
    quantile(0.95)(response_time) AS p95,
    quantile(0.99)(response_time) AS p99,
    uniqExact(user_id) AS dau
FROM events;

-- ReplacingMergeTree untuk upsert
CREATE TABLE users (
    id UInt64,
    name String,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at);

-- FINAL keyword after merge
SELECT * FROM users FINAL WHERE id = 1;
```

ClickHouse optimization:
- `PREWHERE` untuk filter sebelum SELECT
- `SAMPLE` untuk approximate queries di huge tables
- Materialized views untuk pre-aggregation

### DuckDB (in-process analytical)

```sql
-- Direct Parquet query tanpa load
SELECT * FROM read_parquet('events.parquet')
WHERE event_date >= '2024-01-01';

-- Export to Parquet
COPY (SELECT * FROM events) TO 'export.parquet' (FORMAT PARQUET);
```

DuckDB: in-memory analytics, embedded di Python/R/Julia, perfect untuk local data exploration.

## JSON/JSONB patterns

```sql
-- PostgreSQL JSONB
SELECT
    metadata->>'source' AS source,           -- text
    metadata->'tags' AS tags_json,           -- jsonb
    jsonb_array_length(metadata->'tags') AS tag_count
FROM events
WHERE metadata @> '{"priority": "high"}'
  AND metadata->>'source' IN ('web', 'mobile');
```

```sql
-- Create expression index
CREATE INDEX idx_events_priority ON events ((metadata->>'priority'));
```

## Common pitfalls

| Pitfall | Fix |
|---|---|
| Query plan stale | Run `ANALYZE table_name` (Postgres) atau equivalent |
| N+1 di app code | Aggregate di SQL, return 1 row per group |
| Implicit cast | Match types exactly di WHERE |
| LIKE '%foo%' | Full table scan, consider FTS index atau trigram |
| Large OFFSET pagination | Cursor-based: `WHERE id > :last_id` |
| Correlated subquery slow | Rewrite sebagai JOIN |
| NULL handling | Use `IS NULL` / `IS NOT NULL`, not `= NULL` |
| Date timezone issues | Store UTC, convert di app |

## Integration

- **ORM**: SQLAlchemy, Drizzle, Prisma, Knex — generate SQL + escape params (SQL injection safe)
- **Migration**: alembic (Python), drizzle-kit, prisma migrate
- **Lint**: `sqlfluff` untuk style + correctness
- **Performance**: `EXPLAIN ANALYZE`, pg_stat_statements (Postgres)

## Invokation

Auto-trigger:
- Edit file dengan `.sql` extension atau query string panjang
- Reference ke "optimize query", "slow query", "explain"
- ORM raw query / complex join
