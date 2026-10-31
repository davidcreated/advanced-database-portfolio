-- OjaHub Marketplace: the business queries used for optimisation
-- Each query is stored once in perf.queries so the results, EXPLAIN and benchmark scripts all run identical SQL.
-- Dates are fixed to 31 October 2026 so results do not drift when the scripts are rerun later.

DROP SCHEMA IF EXISTS perf CASCADE;
CREATE SCHEMA perf;
SET search_path TO ojahub, perf;
SET timezone TO 'Africa/Lagos';

CREATE TABLE perf.queries (
    query_no  int  PRIMARY KEY,
    question  text NOT NULL,
    sql_text  text NOT NULL
);

INSERT INTO perf.queries VALUES
(1, 'Order history for one customer, newest first', $q$
SELECT o.order_id, o.ordered_at, o.order_status, sum(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.customer_id = 4821
GROUP BY o.order_id
ORDER BY o.ordered_at DESC
LIMIT 20
$q$),

(2, 'Monthly revenue by region for the last quarter', $q$
SELECT date_trunc('month', o.ordered_at) AS month, s.region,
       count(DISTINCT o.order_id) AS orders, sum(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN addresses a ON a.address_id = o.shipping_address_id
JOIN states s ON s.state_id = a.state_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.ordered_at >= timestamptz '2026-08-01' AND o.ordered_at < timestamptz '2026-11-01'
  AND o.order_status <> 'cancelled'
GROUP BY 1, 2
ORDER BY 1, 2
$q$),

(3, 'Monthly sales history for one product (seller dashboard)', $q$
SELECT date_trunc('month', o.ordered_at) AS month, sum(oi.quantity) AS units_sold,
       sum(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE oi.product_id = 4242 AND o.order_status <> 'cancelled'
GROUP BY 1
ORDER BY 1
$q$),

(4, 'Customer search: active products whose name contains "basmati"', $q$
SELECT product_id, product_name, unit_price, stock_qty
FROM products
WHERE product_name ILIKE '%basmati%' AND is_active
ORDER BY unit_price
LIMIT 20
$q$),

(5, 'Operations queue: oldest 50 orders still pending after 3 days', $q$
SELECT o.order_id, o.customer_id, o.ordered_at, p.payment_status
FROM orders o
LEFT JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'pending' AND o.ordered_at < timestamptz '2026-10-31' - interval '3 days'
ORDER BY o.ordered_at
LIMIT 50
$q$),

(6, 'Average rating and review count for one product', $q$
SELECT p.product_id, p.product_name, count(r.review_id) AS reviews, round(avg(r.rating), 2) AS avg_rating
FROM products p
LEFT JOIN reviews r ON r.product_id = p.product_id
WHERE p.product_id = 4242
GROUP BY p.product_id, p.product_name
$q$),

(7, 'Delivered orders per month this year', $q$
SELECT date_trunc('month', ordered_at) AS month, count(*) AS delivered_orders
FROM orders
WHERE order_status = 'delivered' AND ordered_at >= timestamptz '2026-01-01'
GROUP BY 1
ORDER BY 1
$q$),

(8, 'Monthly sales report by category across all time', $q$
SELECT date_trunc('month', o.ordered_at) AS month, c.category_name,
       count(DISTINCT o.order_id) AS orders, sum(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.order_status <> 'cancelled'
GROUP BY 1, 2
ORDER BY 1, 2
$q$);

\echo '\n== Query results (Q8 shows the most recent 12 rows only) =='
SELECT format('SELECT %L AS query', 'Q' || query_no || ': ' || question),
       CASE WHEN query_no = 8
            THEN 'SELECT * FROM (' || sql_text || ') r ORDER BY month DESC, category_name LIMIT 12'
            ELSE sql_text END
FROM perf.queries
ORDER BY query_no
\gexec
