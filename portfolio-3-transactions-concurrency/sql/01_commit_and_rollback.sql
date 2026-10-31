-- OjaHub Marketplace: commit, rollback, an error that aborts a transaction, and a savepoint
-- One ordinary session. Run with psql -e so every statement is echoed above its result.

SET search_path TO ojahub;
SELECT txdemo.reset();

\echo '\n========== A. Placing an order: four changes that must all happen together, then COMMIT =========='
SELECT product_name, stock_qty FROM products WHERE product_id = 2;

BEGIN;
INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
VALUES (1, 1, 'pending', timestamptz '2026-10-31 18:00') RETURNING order_id AS order_a \gset
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (:order_a, 2, 2, 245000.00);
UPDATE products SET stock_qty = stock_qty - 2 WHERE product_id = 2;
INSERT INTO payments (order_id, amount, payment_method, payment_status, reference)
VALUES (:order_a, 490000.00, 'card', 'successful', 'DEMO-' || :order_a);
UPDATE orders SET order_status = 'paid' WHERE order_id = :order_a;
COMMIT;

SELECT o.order_status, oi.quantity, p.payment_status, p.amount,
       (SELECT stock_qty FROM products WHERE product_id = 2) AS stock_left
FROM orders o JOIN order_items oi USING (order_id) JOIN payments p USING (order_id)
WHERE o.order_id = :order_a;

\echo '\n========== B. The card is declined halfway through, so the whole order is rolled back =========='
BEGIN;
INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
VALUES (2, 2, 'pending', timestamptz '2026-10-31 18:00') RETURNING order_id AS order_b \gset
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (:order_b, 2, 1, 245000.00);
UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 2;
SELECT stock_qty AS stock_inside_transaction FROM products WHERE product_id = 2;
ROLLBACK;

SELECT (SELECT count(*) FROM orders WHERE order_id = :order_b) AS order_b_rows,
       (SELECT stock_qty FROM products WHERE product_id = 2) AS stock_after_rollback;

\echo '\n========== C. An error inside a transaction poisons it: everything after fails and COMMIT becomes ROLLBACK =========='
BEGIN;
UPDATE products SET stock_qty = stock_qty - 25 WHERE product_id = 2;
SELECT stock_qty FROM products WHERE product_id = 2;
COMMIT;
SELECT stock_qty AS stock_after_failed_transaction FROM products WHERE product_id = 2;

\echo '\n========== D. SAVEPOINT: drop the out of stock item but keep the rest of the order =========='
SELECT product_id, product_name, stock_qty FROM products WHERE product_id IN (13, 14) ORDER BY product_id;

BEGIN;
INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
VALUES (3, 3, 'pending', timestamptz '2026-10-31 18:00') RETURNING order_id AS order_d \gset
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (:order_d, 13, 1, 42000.00);
UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 13;
SAVEPOINT before_fan;
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (:order_d, 14, 2, 36500.00);
UPDATE products SET stock_qty = stock_qty - 2 WHERE product_id = 14;
ROLLBACK TO SAVEPOINT before_fan;
INSERT INTO payments (order_id, amount, payment_method, payment_status, reference)
VALUES (:order_d, 42000.00, 'bank_transfer', 'successful', 'DEMO-' || :order_d);
UPDATE orders SET order_status = 'paid' WHERE order_id = :order_d;
COMMIT;

SELECT oi.product_id, p.product_name, oi.quantity, p.stock_qty AS stock_now
FROM order_items oi JOIN products p USING (product_id)
WHERE oi.order_id = :order_d;
SELECT product_id, product_name, stock_qty FROM products WHERE product_id = 14;

\echo '\n========== Clean up =========='
SELECT txdemo.reset();
