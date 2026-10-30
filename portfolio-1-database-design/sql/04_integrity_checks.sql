-- OjaHub Marketplace: data integrity checks on the seeded data
-- Checks 1 and 2 should return zero rows.

SET search_path TO ojahub;

\echo '\n== Row counts per table =='
SELECT 'states' AS table_name, count(*) AS row_count FROM states
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'addresses', count(*) FROM addresses
UNION ALL SELECT 'sellers', count(*) FROM sellers
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'shipments', count(*) FROM shipments
UNION ALL SELECT 'reviews', count(*) FROM reviews;

\echo '\n== Check 1: successful payments that do not match the order total =='
SELECT o.order_id, items.order_total, p.amount AS amount_paid
FROM orders o
JOIN (SELECT order_id, sum(quantity * unit_price) AS order_total
      FROM order_items GROUP BY order_id) items USING (order_id)
JOIN payments p ON p.order_id = o.order_id AND p.payment_status = 'successful'
WHERE p.amount <> items.order_total;

\echo '\n== Check 2: reviews written by customers who never bought the product =='
SELECT r.review_id, r.customer_id, r.product_id
FROM reviews r
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.customer_id = r.customer_id AND oi.product_id = r.product_id
);

\echo '\n== Order totals computed from order_items =='
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer, o.order_status,
       sum(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers c USING (customer_id)
JOIN order_items oi USING (order_id)
GROUP BY o.order_id, c.first_name, c.last_name, o.order_status
ORDER BY o.order_id;
