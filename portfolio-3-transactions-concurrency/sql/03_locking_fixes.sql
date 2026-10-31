-- OjaHub Marketplace: three ways to stop the lost update from 02_lost_update.sql
-- Same race each time: two buyers, one Standing Fan left.

\set QUIET on
\pset tuples_only on
\pset format unaligned
SET search_path TO ojahub;

CREATE FUNCTION pg_temp.fan_result() RETURNS text LANGUAGE sql AS $$
    SELECT format('Result: Standing Fan orders placed: %s, stock now: %s',
                  (SELECT count(*) FROM ojahub.order_items oi JOIN ojahub.orders o USING (order_id)
                   WHERE oi.product_id = 14 AND o.ordered_at >= timestamptz '2026-10-31'),
                  (SELECT stock_qty FROM ojahub.products WHERE product_id = 14))
$$;

SELECT txdemo.open('buyer_a');
SELECT txdemo.open('buyer_b');

\echo '\n========== Fix 1: SELECT ... FOR UPDATE locks the row at the moment it is read =========='
SELECT txdemo.reset();
SELECT txdemo.step('buyer_a', 'BEGIN');
SELECT txdemo.step('buyer_b', 'BEGIN');
SELECT txdemo.step('buyer_a', 'SELECT stock_qty FROM products WHERE product_id = 14 FOR UPDATE');
SELECT txdemo.send('buyer_b', 'SELECT stock_qty FROM products WHERE product_id = 14 FOR UPDATE');
SELECT txdemo.waiting('buyer_b');
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 14');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 14, 1)');
SELECT txdemo.step('buyer_a', 'COMMIT');
SELECT txdemo.collect('buyer_b');
\echo '# Buyer B only gets to read the stock after A has finished, sees 0 and shows "sold out"'
SELECT txdemo.step('buyer_b', 'ROLLBACK');
SELECT pg_temp.fan_result();

\echo '\n========== Fix 2: one atomic UPDATE that checks and decrements in the same statement =========='
SELECT txdemo.reset();
SELECT txdemo.step('buyer_a', 'BEGIN');
SELECT txdemo.step('buyer_b', 'BEGIN');
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 14 AND stock_qty >= 1');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 14, 1)');
SELECT txdemo.send('buyer_b', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 14 AND stock_qty >= 1');
SELECT txdemo.waiting('buyer_b');
SELECT txdemo.step('buyer_a', 'COMMIT');
SELECT txdemo.collect('buyer_b');
\echo '# After A commits, PostgreSQL rechecks B''s WHERE clause against the new row: 0 rows updated means sold out'
SELECT txdemo.step('buyer_b', 'ROLLBACK');
SELECT pg_temp.fan_result();

\echo '\n========== Fix 3: REPEATABLE READ refuses to let B overwrite a row that changed after B read it =========='
SELECT txdemo.reset();
SELECT txdemo.step('buyer_a', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('buyer_b', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('buyer_a', 'SELECT stock_qty FROM products WHERE product_id = 14');
SELECT txdemo.step('buyer_b', 'SELECT stock_qty FROM products WHERE product_id = 14');
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = 0 WHERE product_id = 14');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 14, 1)');
SELECT txdemo.send('buyer_b', 'UPDATE products SET stock_qty = 0 WHERE product_id = 14');
SELECT txdemo.waiting('buyer_b');
SELECT txdemo.step('buyer_a', 'COMMIT');
SELECT txdemo.collect('buyer_b');
SELECT txdemo.step('buyer_b', 'ROLLBACK');
\echo '# The app catches SQLSTATE 40001 and retries in a fresh transaction, which sees the real stock'
SELECT txdemo.step('buyer_b', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('buyer_b', 'SELECT stock_qty FROM products WHERE product_id = 14');
SELECT txdemo.step('buyer_b', 'ROLLBACK');
SELECT pg_temp.fan_result();

SELECT txdemo.close_all();
SELECT txdemo.reset();
