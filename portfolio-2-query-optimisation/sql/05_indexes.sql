-- OjaHub Marketplace: indexes chosen from the baseline plans

SET search_path TO ojahub, perf;

DROP INDEX IF EXISTS orders_customer_ordered_idx, orders_ordered_at_idx, order_items_product_idx,
    products_name_trgm_idx, orders_pending_idx, payments_order_idx;

-- Q1: PostgreSQL does not index foreign keys automatically, so a customer's orders meant scanning all 500k.
-- ordered_at second keeps each customer's orders in date order inside the index. Q1 still sorts after
-- its GROUP BY, but only over that one customer's handful of rows.
CREATE INDEX orders_customer_ordered_idx ON orders (customer_id, ordered_at DESC);

-- Q2 and Q7: date range filters on orders
CREATE INDEX orders_ordered_at_idx ON orders (ordered_at);

-- Q3: the other unindexed foreign key; finding one product's sales meant scanning 1 million order items
CREATE INDEX order_items_product_idx ON order_items (product_id);

-- Q4: a leading wildcard (ILIKE '%basmati%') cannot use a B-tree; trigram GIN indexes substrings
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE INDEX products_name_trgm_idx ON products USING gin (product_name public.gin_trgm_ops);

-- Q5: only about 0.3 percent of orders are pending, so index just those rows
CREATE INDEX orders_pending_idx ON orders (ordered_at) WHERE order_status = 'pending';

-- Q5: payments.order_id only had the partial unique index for successful payments
CREATE INDEX payments_order_idx ON payments (order_id);

ANALYZE orders, order_items, products, payments;

\echo '\n== Size of the partial pending index compared with an equivalent full index =='
CREATE INDEX orders_status_full_tmp ON orders (order_status, ordered_at);
SELECT 'partial: WHERE order_status = ''pending''' AS index_kind,
       pg_size_pretty(pg_relation_size('orders_pending_idx')) AS size
UNION ALL
SELECT 'full: (order_status, ordered_at)', pg_size_pretty(pg_relation_size('orders_status_full_tmp'));
DROP INDEX orders_status_full_tmp;

\echo '\n== How closely the physical row order follows each column (1.0 means perfectly sorted) =='
SELECT attname AS column_name, round(correlation::numeric, 4) AS correlation
FROM pg_stats
WHERE schemaname = 'ojahub' AND tablename = 'orders' AND attname IN ('ordered_at', 'customer_id')
ORDER BY attname;

\echo '\n== Because orders are stored in date order, a BRIN index could replace the B-tree on ordered_at =='
CREATE INDEX orders_ordered_at_brin_tmp ON orders USING brin (ordered_at);
SELECT 'B-tree on ordered_at' AS index_kind, pg_size_pretty(pg_relation_size('orders_ordered_at_idx')) AS size
UNION ALL
SELECT 'BRIN on ordered_at', pg_size_pretty(pg_relation_size('orders_ordered_at_brin_tmp'));
DROP INDEX orders_ordered_at_brin_tmp;

\echo '\n== All indexes on the main tables with their sizes =='
SELECT i.relname AS table_name, i.indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
       pg_size_pretty(pg_relation_size(i.relid)) AS table_size
FROM pg_stat_user_indexes i
WHERE i.schemaname = 'ojahub' AND i.relname IN ('orders', 'order_items', 'products', 'payments', 'reviews')
ORDER BY i.relname, pg_relation_size(i.indexrelid) DESC;
