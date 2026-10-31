-- OjaHub Marketplace: the lost update, two buyers and one Standing Fan left
-- The app reads the stock, works out the new value itself, and writes it back. Default READ COMMITTED.

\set QUIET on
\pset tuples_only on
\pset format unaligned
SET search_path TO ojahub;

SELECT txdemo.reset();
SELECT txdemo.open('buyer_a');
SELECT txdemo.open('buyer_b');

\echo '\n# Both buyers open the product page at the same moment'
SELECT txdemo.step('buyer_a', 'BEGIN');
SELECT txdemo.step('buyer_b', 'BEGIN');
SELECT txdemo.step('buyer_a', 'SELECT stock_qty FROM products WHERE product_id = 14');
SELECT txdemo.step('buyer_b', 'SELECT stock_qty FROM products WHERE product_id = 14');

\echo '\n# Both apps saw 1 in stock, so both compute 1 - 1 = 0 and go ahead'
SELECT txdemo.step('buyer_a', 'UPDATE products SET stock_qty = 0 WHERE product_id = 14');
SELECT txdemo.step('buyer_a', 'SELECT txdemo.place_order(1, 14, 1)');
SELECT txdemo.send('buyer_b', 'UPDATE products SET stock_qty = 0 WHERE product_id = 14');
SELECT txdemo.waiting('buyer_b');

\echo '\n# Buyer A commits; the row lock is released and buyer B''s update simply goes through'
SELECT txdemo.step('buyer_a', 'COMMIT');
SELECT txdemo.collect('buyer_b');
SELECT txdemo.step('buyer_b', 'SELECT txdemo.place_order(2, 14, 1)');
SELECT txdemo.step('buyer_b', 'COMMIT');

\echo '\n# Result'
SELECT format('Standing Fan orders placed: %s, stock now: %s, units that actually existed: 1',
              (SELECT count(*) FROM order_items oi JOIN orders o USING (order_id)
               WHERE oi.product_id = 14 AND o.ordered_at >= timestamptz '2026-10-31'),
              (SELECT stock_qty FROM products WHERE product_id = 14));

SELECT txdemo.close_all();
SELECT txdemo.reset();
