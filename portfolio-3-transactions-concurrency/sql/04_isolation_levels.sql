-- OjaHub Marketplace: what a long running report sees while a buyer commits an order
-- The report reads two things: a count of today's orders (a new row can appear) and the
-- Galaxy A15 stock (an existing row can change).

\set QUIET on
\pset tuples_only on
\pset format unaligned
SET search_path TO ojahub;

\set report_query 'SELECT (SELECT count(*) FROM orders WHERE ordered_at >= timestamptz ''2026-10-31'') AS orders_today, (SELECT stock_qty FROM products WHERE product_id = 2) AS galaxy_stock'

SELECT txdemo.open('report');
SELECT txdemo.open('buyer_a');

\echo '\n========== READ COMMITTED (the PostgreSQL default) =========='
SELECT txdemo.reset();
SELECT txdemo.step('report', 'BEGIN ISOLATION LEVEL READ COMMITTED');
SELECT txdemo.step('report', :'report_query');
SELECT txdemo.step('buyer_a', 'BEGIN');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 2, 1)');
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 2');
\echo '# The buyer has not committed yet. Can the report see the new order? (a dirty read)'
SELECT txdemo.step('report', :'report_query');
SELECT txdemo.step('buyer_a', 'COMMIT');
\echo '# Same report transaction, same query, after the buyer commits'
SELECT txdemo.step('report', :'report_query');
SELECT txdemo.step('report', 'COMMIT');

\echo '\n========== REPEATABLE READ =========='
SELECT txdemo.reset();
SELECT txdemo.step('report', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('report', :'report_query');
SELECT txdemo.step('buyer_a', 'BEGIN');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 2, 1)');
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 2');
SELECT txdemo.step('buyer_a', 'COMMIT');
\echo '# The buyer has committed, but the report keeps reading from the snapshot taken at its first query'
SELECT txdemo.step('report', :'report_query');
SELECT txdemo.step('report', 'COMMIT');
\echo '# A new transaction sees the committed order'
SELECT txdemo.step('report', :'report_query');

SELECT txdemo.close_all();
SELECT txdemo.reset();
