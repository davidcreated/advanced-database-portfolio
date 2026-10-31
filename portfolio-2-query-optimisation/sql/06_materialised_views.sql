-- OjaHub Marketplace: materialised views for the reporting queries (Q2 and Q8)
-- Indexes could not speed these up, because the cost is in joining and sorting, not in finding rows.

SET search_path TO ojahub, perf;
SET timezone TO 'Africa/Lagos';

DROP MATERIALIZED VIEW IF EXISTS mv_monthly_region_sales, mv_monthly_category_sales;

-- Each order ships to one address, so counting orders per region needs no DISTINCT
CREATE MATERIALIZED VIEW mv_monthly_region_sales AS
SELECT date_trunc('month', o.ordered_at, 'Africa/Lagos') AS month, s.region,
       count(*) AS orders, sum(t.order_total) AS revenue
FROM orders o
JOIN (SELECT order_id, sum(quantity * unit_price) AS order_total FROM order_items GROUP BY order_id) t
     ON t.order_id = o.order_id
JOIN addresses a ON a.address_id = o.shipping_address_id
JOIN states s ON s.state_id = a.state_id
WHERE o.order_status <> 'cancelled'
GROUP BY 1, 2;

CREATE MATERIALIZED VIEW mv_monthly_category_sales AS
SELECT date_trunc('month', o.ordered_at, 'Africa/Lagos') AS month, c.category_name,
       count(DISTINCT o.order_id) AS orders, sum(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.order_status <> 'cancelled'
GROUP BY 1, 2;

-- Unique indexes allow REFRESH ... CONCURRENTLY, so reports stay readable during a refresh
CREATE UNIQUE INDEX ON mv_monthly_region_sales (month, region);
CREATE UNIQUE INDEX ON mv_monthly_category_sales (month, category_name);
ANALYZE mv_monthly_region_sales, mv_monthly_category_sales;

\echo '\n== Do the views give exactly the same answers as the live queries? (0 differences expected) =='
SELECT 'CREATE TEMP TABLE live_q' || query_no || ' AS ' || sql_text
FROM perf.queries WHERE query_no IN (2, 8)
\gexec

SELECT 'Q2 by region' AS report, count(*) AS differences
FROM ((SELECT * FROM live_q2
       EXCEPT SELECT * FROM mv_monthly_region_sales
              WHERE month >= timestamptz '2026-08-01' AND month < timestamptz '2026-11-01')
      UNION ALL
      (SELECT * FROM mv_monthly_region_sales
              WHERE month >= timestamptz '2026-08-01' AND month < timestamptz '2026-11-01'
       EXCEPT SELECT * FROM live_q2)) d
UNION ALL
SELECT 'Q8 by category', count(*)
FROM ((SELECT * FROM live_q8 EXCEPT SELECT * FROM mv_monthly_category_sales)
      UNION ALL
      (SELECT * FROM mv_monthly_category_sales EXCEPT SELECT * FROM live_q8)) d;

\echo '\n== Live query compared with reading the view (median of 6 warm runs) =='
SELECT 'Q2 live query' AS report, b.median_ms, b.scans
FROM perf.queries q, perf.bench(q.sql_text) b WHERE q.query_no = 2
UNION ALL
SELECT 'Q2 from view', b.median_ms, b.scans
FROM perf.bench($v$SELECT * FROM mv_monthly_region_sales
                   WHERE month >= timestamptz '2026-08-01' AND month < timestamptz '2026-11-01'
                   ORDER BY month, region$v$) b
UNION ALL
SELECT 'Q8 live query', b.median_ms, b.scans
FROM perf.queries q, perf.bench(q.sql_text) b WHERE q.query_no = 8
UNION ALL
SELECT 'Q8 from view', b.median_ms, b.scans
FROM perf.bench($v$SELECT * FROM mv_monthly_category_sales ORDER BY month, category_name$v$) b;

\echo '\n== The cost moves to refresh time =='
\timing on
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_region_sales;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_category_sales;
\timing off

\echo '\n== The trade off: a view is only as fresh as its last refresh (rolled back afterwards) =='
BEGIN;

WITH new_order AS (
    INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
    VALUES (1, 1, 'paid', timestamptz '2026-10-31 09:00')
    RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT order_id, 2, 1, 245000.00 FROM new_order;

SELECT 'before refresh' AS moment,
       (SELECT revenue FROM mv_monthly_region_sales
        WHERE month = timestamptz '2026-10-01' AND region = 'South West') AS view_revenue,
       (SELECT sum(oi.quantity * oi.unit_price)
        FROM orders o
        JOIN order_items oi USING (order_id)
        JOIN addresses a ON a.address_id = o.shipping_address_id
        JOIN states s ON s.state_id = a.state_id
        WHERE o.ordered_at >= timestamptz '2026-10-01' AND o.ordered_at < timestamptz '2026-11-01'
          AND o.order_status <> 'cancelled' AND s.region = 'South West') AS live_revenue;

REFRESH MATERIALIZED VIEW mv_monthly_region_sales;

SELECT 'after refresh' AS moment,
       (SELECT revenue FROM mv_monthly_region_sales
        WHERE month = timestamptz '2026-10-01' AND region = 'South West') AS view_revenue;

ROLLBACK;
