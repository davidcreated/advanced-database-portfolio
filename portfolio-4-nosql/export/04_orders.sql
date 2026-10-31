\ir 00_helpers.sql

-- The address, product names and prices are copied into the order as they were when it was placed
WITH items AS (
    SELECT oi.order_id,
           json_agg(json_build_object('product_id', oi.product_id, 'name', p.product_name,
                                      'quantity', oi.quantity, 'unit_price', pg_temp.money(oi.unit_price))
                    ORDER BY oi.product_id) AS items,
           sum(oi.quantity * oi.unit_price) AS total
    FROM order_items oi JOIN products p USING (product_id)
    GROUP BY oi.order_id
), pays AS (
    SELECT order_id,
           json_agg(json_build_object('method', payment_method, 'status', payment_status,
                                      'amount', pg_temp.money(amount), 'reference', reference,
                                      'created_at', pg_temp.d(created_at))
                    ORDER BY created_at, payment_id) AS payments
    FROM payments
    GROUP BY order_id
)
SELECT json_strip_nulls(json_build_object(
    '_id', o.order_id,
    'customer', json_build_object('customer_id', c.customer_id, 'name', c.first_name || ' ' || c.last_name),
    'status', o.order_status,
    'ordered_at', pg_temp.d(o.ordered_at),
    'shipping_address', json_build_object('street', a.street, 'city', a.city, 'state', st.state_name, 'region', st.region),
    'items', i.items,
    'total', pg_temp.money(i.total),
    'payments', coalesce(py.payments, '[]'::json),
    'shipment', CASE WHEN sh.shipment_id IS NOT NULL THEN json_build_object(
        'courier', sh.courier, 'tracking_number', sh.tracking_number, 'status', sh.shipment_status,
        'shipped_at', pg_temp.d(sh.shipped_at), 'delivered_at', pg_temp.d(sh.delivered_at)) END
))
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN addresses a ON a.address_id = o.shipping_address_id
JOIN states st ON st.state_id = a.state_id
JOIN items i ON i.order_id = o.order_id
LEFT JOIN pays py ON py.order_id = o.order_id
LEFT JOIN shipments sh ON sh.order_id = o.order_id
ORDER BY o.order_id;
