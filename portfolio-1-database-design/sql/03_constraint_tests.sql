-- OjaHub Marketplace: constraint tests
-- Every statement in tests 1 to 14 breaks a rule and must be rejected.
-- Run after 01_schema.sql and 02_seed.sql without ON_ERROR_STOP so all tests run.

SET search_path TO ojahub;

\echo '\n== Test 1: duplicate customer email (UNIQUE) =='
INSERT INTO customers (first_name, last_name, email, phone)
VALUES ('Chiamaka', 'Duplicate', 'chiamaka.okeke@example.ng', '+2348000000001');

\echo '\n== Test 2: phone number not in +234 format (CHECK) =='
INSERT INTO customers (first_name, last_name, email, phone)
VALUES ('Kemi', 'Ajayi', 'kemi.ajayi@example.ng', '08031234567');

\echo '\n== Test 3: negative stock (CHECK) =='
UPDATE products SET stock_qty = -1 WHERE product_id = 1;

\echo '\n== Test 4: product priced at zero (CHECK) =='
INSERT INTO products (seller_id, category_id, product_name, unit_price)
VALUES (2, 3, 'Free Phone Case', 0);

\echo '\n== Test 5: rating outside 1 to 5 (CHECK) =='
INSERT INTO reviews (product_id, customer_id, rating) VALUES (2, 4, 6);

\echo '\n== Test 6: second review of the same product by the same customer (UNIQUE) =='
INSERT INTO reviews (product_id, customer_id, rating) VALUES (1, 1, 1);

\echo '\n== Test 7: order for a customer that does not exist (FOREIGN KEY) =='
INSERT INTO orders (customer_id, shipping_address_id) VALUES (999, 1);

\echo '\n== Test 8: second successful payment on an already paid order (partial UNIQUE index) =='
INSERT INTO payments (order_id, amount, payment_method, payment_status, reference)
VALUES (1, 226000.00, 'card', 'successful', 'OJH-PAY-TEST01');

\echo '\n== Test 9: second default address for one customer (partial UNIQUE index) =='
UPDATE addresses SET is_default = true WHERE address_id = 11;

\echo '\n== Test 10: delivery recorded before shipping (CHECK) =='
UPDATE shipments SET delivered_at = shipped_at - INTERVAL '1 day' WHERE order_id = 3;

\echo '\n== Test 11: unknown order status (CHECK) =='
UPDATE orders SET order_status = 'lost' WHERE order_id = 5;

\echo '\n== Test 12: deleting a seller who still has products (FOREIGN KEY, ON DELETE RESTRICT) =='
DELETE FROM sellers WHERE seller_id = 2;

\echo '\n== Test 13: category set as its own parent (CHECK) =='
UPDATE categories SET parent_category_id = category_id WHERE category_id = 2;

\echo '\n== Test 14: order item with zero quantity (CHECK) =='
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (5, 1, 0, 189000.00);

\echo '\n== Test 15 (should succeed): a failed payment retry on an order is still allowed =='
BEGIN;
INSERT INTO payments (order_id, amount, payment_method, payment_status, reference)
VALUES (5, 34800.00, 'card', 'failed', 'OJH-PAY-TEST02');
SELECT order_id, payment_status, count(*) FROM payments WHERE order_id = 5 GROUP BY 1, 2 ORDER BY 2;
ROLLBACK;

\echo '\n== Row counts after the tests (should match the seed exactly) =='
SELECT 'customers' AS table_name, count(*) FROM customers
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'sellers', count(*) FROM sellers;
