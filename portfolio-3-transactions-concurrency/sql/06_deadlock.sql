-- OjaHub Marketplace: a deadlock between two orders, and the lock ordering fix
-- Both orders contain the Handmade Leather Bag (9) and the Non Stick Pot Set (13).

\set QUIET on
\pset tuples_only on
\pset format unaligned
SET search_path TO ojahub;

CREATE FUNCTION pg_temp.stock() RETURNS text LANGUAGE sql AS $$
    SELECT 'Stock now: ' || string_agg(format('%s = %s', product_name, stock_qty), ', ' ORDER BY product_id)
    FROM ojahub.products WHERE product_id IN (9, 13)
$$;

SELECT txdemo.open('order_a');
SELECT txdemo.open('order_b');

\echo '\n========== The deadlock: each order locks its first item, then wants the other one =========='
SELECT txdemo.reset();
SELECT txdemo.step('order_a', 'BEGIN');
SELECT txdemo.step('order_b', 'BEGIN');
SELECT txdemo.step('order_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 9');
SELECT txdemo.step('order_b', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 13');
SELECT txdemo.send('order_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 13');
SELECT txdemo.waiting('order_a');
SELECT txdemo.send('order_b', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 9');
SELECT txdemo.waiting('order_b');
\echo '# Each is waiting for the other, so neither can ever finish. After deadlock_timeout (1s) PostgreSQL picks a victim.'
SELECT txdemo.collect('order_a');
SELECT txdemo.collect('order_b');
SELECT txdemo.step('order_a', 'ROLLBACK');
SELECT txdemo.step('order_b', 'COMMIT');
SELECT pg_temp.stock();

\echo '\n========== The fix: every order locks its products in product_id order before changing anything =========='
SELECT txdemo.reset();
SELECT txdemo.step('order_a', 'BEGIN');
SELECT txdemo.step('order_b', 'BEGIN');
SELECT txdemo.step('order_a', 'SELECT product_id FROM products WHERE product_id IN (13, 9) ORDER BY product_id FOR UPDATE');
SELECT txdemo.send('order_b', 'SELECT product_id FROM products WHERE product_id IN (13, 9) ORDER BY product_id FOR UPDATE');
SELECT txdemo.waiting('order_b');
\echo '# Order B queues behind A on the very first product instead of grabbing the second one, so no cycle can form'
SELECT txdemo.step('order_a', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id IN (9, 13)');
SELECT txdemo.step('order_a', 'COMMIT');
SELECT txdemo.collect('order_b');
SELECT txdemo.step('order_b', 'UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id IN (9, 13)');
SELECT txdemo.step('order_b', 'COMMIT');
SELECT pg_temp.stock();

SELECT txdemo.close_all();
SELECT txdemo.reset();
