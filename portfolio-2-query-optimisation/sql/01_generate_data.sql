-- OjaHub Marketplace: bulk data for query optimisation
-- Run after portfolio-1 01_schema.sql and 02_seed.sql. Appends roughly 2 million rows.
-- Deterministic: the fixed seed and serial execution give identical data on every rerun.

SET search_path TO ojahub;
SET timezone TO 'Africa/Lagos';
SET max_parallel_workers_per_gather = 0;
SELECT setseed(0.2026);

CREATE TEMP TABLE state_city (state_id smallint PRIMARY KEY, city text);
INSERT INTO state_city VALUES
    (1,'Umuahia'),(2,'Yola'),(3,'Uyo'),(4,'Awka'),(5,'Bauchi'),(6,'Yenagoa'),(7,'Makurdi'),
    (8,'Maiduguri'),(9,'Calabar'),(10,'Asaba'),(11,'Abakaliki'),(12,'Benin City'),(13,'Ado Ekiti'),
    (14,'Enugu'),(15,'Abuja'),(16,'Gombe'),(17,'Owerri'),(18,'Dutse'),(19,'Kaduna'),(20,'Kano'),
    (21,'Katsina'),(22,'Birnin Kebbi'),(23,'Lokoja'),(24,'Ilorin'),(25,'Ikeja'),(26,'Lafia'),
    (27,'Minna'),(28,'Abeokuta'),(29,'Akure'),(30,'Osogbo'),(31,'Ibadan'),(32,'Jos'),
    (33,'Port Harcourt'),(34,'Sokoto'),(35,'Jalingo'),(36,'Damaturu'),(37,'Gusau');

-- Lagos, the FCT, Rivers, Kano and Oyo carry far more online orders than the other states
CREATE FUNCTION pg_temp.pick_state(r double precision, r2 double precision) RETURNS smallint
LANGUAGE sql AS $$
    SELECT CASE
        WHEN r < 0.25 THEN 25
        WHEN r < 0.35 THEN 15
        WHEN r < 0.41 THEN 33
        WHEN r < 0.47 THEN 20
        WHEN r < 0.52 THEN 31
        ELSE 1 + floor(r2 * 37)
    END::smallint
$$;

\echo 'Customers'
INSERT INTO customers (first_name, last_name, email, phone, created_at)
SELECT fn[fi], ln[li],
       lower(fn[fi]) || '.' || lower(ln[li]) || g || '@example.ng',
       '+234' || px[pi] || lpad(g::text, 7, '0'),
       timestamptz '2024-06-01' + r * interval '880 days'
FROM (SELECT g, 1 + floor(random() * 40)::int AS fi, 1 + floor(random() * 40)::int AS li,
             1 + floor(random() * 10)::int AS pi, random() AS r
      FROM generate_series(1, 50000) g) s,
     (SELECT ARRAY['Adaeze','Babatunde','Chinedu','Damilola','Efosa','Folake','Garba','Halima','Ifeanyi','Jumoke',
                   'Kelechi','Lami','Musa','Nneka','Obinna','Oluwaseun','Precious','Rukayat','Sani','Temitope',
                   'Uche','Victoria','Wale','Yetunde','Zainab','Amaka','Bola','Chidi','Dayo','Ebere',
                   'Fatima','Gbenga','Hauwa','Ikechukwu','Joy','Kunle','Maryam','Nkechi','Olumide','Tobi'] AS fn,
             ARRAY['Adebayo','Okafor','Bello','Eze','Ogunbiyi','Nwachukwu','Abubakar','Okonkwo','Adeleke','Ibrahim',
                   'Chukwu','Danjuma','Ezenwa','Fashola','Gwarzo','Ilori','Johnson','Kalu','Lawal','Mohammed',
                   'Nnadi','Obi','Ojo','Okoro','Olaniyan','Onyeka','Salami','Suleiman','Taiwo','Udoh',
                   'Umar','Uzor','Williams','Yakubu','Yusuf','Ajayi','Akpan','Etim','Ikwuemesi','Mbah'] AS ln,
             ARRAY['803','805','806','703','706','813','816','903','906','810'] AS px) pools;

\echo 'Addresses'
INSERT INTO addresses (customer_id, street, city, state_id, is_default)
SELECT s.customer_id, s.street, sc.city, s.state_id, s.is_default
FROM (SELECT c.customer_id, k = 1 AS is_default,
             (1 + floor(random() * 150))::int || ' ' || st[1 + floor(random() * 12)::int] AS street,
             pg_temp.pick_state(random(), random()) AS state_id
      FROM (SELECT customer_id, random() AS r_second FROM customers WHERE customer_id > 10) c
      CROSS JOIN generate_series(1, 2) k,
      (SELECT ARRAY['Allen Avenue','Awolowo Road','Ahmadu Bello Way','Murtala Mohammed Way','Nnamdi Azikiwe Street',
                    'Ring Road','Station Road','Market Road','Hospital Road','Airport Road','Okpara Avenue','Sapele Road'] AS st) pool
      WHERE k = 1 OR c.r_second < 0.2) s
JOIN state_city sc USING (state_id);

\echo 'Sellers'
INSERT INTO sellers (business_name, email, phone, state_id, joined_at, is_verified)
SELECT nm[ni] || ' ' || kind[ki] || ' ' || g,
       'seller' || g || '@ojahub-sellers.example.ng',
       '+234' || '80' || (1 + floor(random() * 9))::int || lpad(g::text, 7, '0'),
       pg_temp.pick_state(random(), random()),
       timestamptz '2024-01-01' + random() * interval '880 days',
       random() < 0.8
FROM (SELECT g, 1 + floor(random() * 12)::int AS ni, 1 + floor(random() * 8)::int AS ki
      FROM generate_series(1, 5000) g) s,
     (SELECT ARRAY['Iya Basira','Mama Ngozi','Alhaji Sule','Bros Emeka','Oga Tunde','Aunty Kemi',
                   'Mallam Bashir','Madam Esther','Chief Okon','Sister Blessing','Baba Ade','Uncle Femi'] AS nm,
             ARRAY['Stores','Ventures','Enterprises','Global','Gadgets','Fabrics','Foods','Home'] AS kind) pools;

\echo 'Products'
CREATE TEMP TABLE product_pool (category_id int, idx int, base_name text, min_price numeric, max_price numeric);
INSERT INTO product_pool
SELECT c.category_id, n.ord, n.name, c.min_price, c.max_price
FROM (VALUES
        (2, 60000, 450000, ARRAY['Tecno Spark 20','Tecno Camon 30','Infinix Hot 40','Infinix Note 40','itel A70',
                                 'Samsung Galaxy A15','Samsung Galaxy A25','Redmi 13C','Nokia G42','iPhone 13 UK Used']),
        (3, 2000, 60000,    ARRAY['Power Bank 20000mAh','Wireless Earbuds','USB C Fast Charger','Phone Case','Screen Protector',
                                 'Bluetooth Speaker','Smart Watch','Laptop Bag','HDMI Cable','Memory Card 64GB']),
        (5, 8000, 120000,   ARRAY['Ankara Print 6 Yards','George Wrapper','Swiss Lace 5 Yards','Aso Oke Set','Adire Fabric 4 Yards',
                                 'Cord Lace','Guinea Brocade 10 Yards','Kente Fabric','Senator Material 4 Yards','Chiffon 5 Yards']),
        (6, 5000, 90000,    ARRAY['Leather Sandals','Handmade Leather Bag','Leather Belt','Leather Wallet','Leather Slippers',
                                 'Leather Pouf','Leather Backpack','Leather Laptop Sleeve','Leather Keyholder','Leather Brogues']),
        (7, 2000, 60000,    ARRAY['Ofada Rice 5kg','Basmati Rice 10kg','Long Grain Parboiled Rice 25kg','Red Palm Oil 4 Litres',
                                 'Ijebu Garri 10kg','Honey Beans 5kg','Yam Flour 2kg','Egusi 1kg','Crayfish 500g','Plantain Chips Pack']),
        (8, 8000, 350000,   ARRAY['Non Stick Pot Set','Standing Fan 18 Inch','Rechargeable Lantern','Blender 1.5 Litres',
                                 'Gas Cooker 2 Burner','Electric Kettle','Mosquito Net','Bedsheet Set','Water Dispenser','Inverter Battery 200Ah'])
     ) AS c(category_id, min_price, max_price, names)
CROSS JOIN LATERAL unnest(c.names) WITH ORDINALITY AS n(name, ord);

INSERT INTO products (seller_id, category_id, product_name, unit_price, stock_qty, is_active, created_at)
SELECT s.seller_id, pp.category_id,
       pp.base_name || ' OJ' || lpad(s.g::text, 6, '0'),
       round((pp.min_price + s.r_price * (pp.max_price - pp.min_price)) / 100) * 100,
       CASE WHEN s.r_stock < 0.05 THEN 0 ELSE floor(s.r_stock * 200)::int END,
       s.r_active > 0.03,
       timestamptz '2024-02-01' + s.r_date * interval '850 days'
FROM (SELECT g, 1 + floor(random() * 5005)::int AS seller_id,
             (ARRAY[2,3,5,6,7,8])[1 + floor(random() * 6)::int] AS category_id,
             1 + floor(random() * 10)::int AS idx,
             random() AS r_price, random() AS r_stock, random() AS r_active, random() AS r_date
      FROM generate_series(1, 100000) g) s
JOIN product_pool pp USING (category_id, idx);

\echo 'Orders'
-- Status depends on how old the order is relative to 31 October 2026
INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
SELECT o.customer_id, a.address_id,
       CASE
           WHEN o.age < interval '2 days' THEN
               CASE WHEN o.rs < 0.30 THEN 'pending' WHEN o.rs < 0.80 THEN 'paid' ELSE 'shipped' END
           WHEN o.age < interval '7 days' THEN
               CASE WHEN o.rs < 0.03 THEN 'pending' WHEN o.rs < 0.10 THEN 'paid' WHEN o.rs < 0.40 THEN 'shipped'
                    WHEN o.rs < 0.95 THEN 'delivered' ELSE 'cancelled' END
           ELSE
               CASE WHEN o.rs < 0.002 THEN 'pending' WHEN o.rs < 0.062 THEN 'cancelled' ELSE 'delivered' END
       END,
       o.ordered_at
FROM (SELECT customer_id, ordered_at, timestamptz '2026-10-31 00:00' - ordered_at AS age, rs
      FROM (SELECT 11 + floor(random() * 50000)::int AS customer_id,
                   timestamptz '2024-11-01' + power(random(), 0.8) * (timestamptz '2026-10-30 23:59' - timestamptz '2024-11-01') AS ordered_at,
                   random() AS rs
            FROM generate_series(1, 500000)) x
      ORDER BY ordered_at) o
JOIN addresses a ON a.customer_id = o.customer_id AND a.is_default;

\echo 'Order items'
CREATE TEMP TABLE item_picks AS
SELECT o.order_id, 1 + floor(random() * 100014)::int AS product_id,
       1 + floor(power(random(), 2) * 3)::int AS quantity, random() < 0.1 AS promo
FROM (SELECT order_id, 1 + floor(power(random(), 1.5) * 4)::int AS n FROM orders WHERE order_id > 10) o
CROSS JOIN LATERAL generate_series(1, o.n);

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT ip.order_id, ip.product_id, ip.quantity,
       CASE WHEN ip.promo THEN round(p.unit_price * 0.9 / 100) * 100 ELSE p.unit_price END
FROM item_picks ip
JOIN products p USING (product_id)
ON CONFLICT (order_id, product_id) DO NOTHING;

\echo 'Payments'
CREATE TEMP TABLE order_totals AS
SELECT o.order_id, o.order_status, o.ordered_at, sum(oi.quantity * oi.unit_price) AS total,
       random() AS r_fail, random() AS r_method
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.order_id > 10
GROUP BY o.order_id, o.order_status, o.ordered_at;

CREATE TEMP SEQUENCE payment_ref START 1;

INSERT INTO payments (order_id, amount, payment_method, payment_status, reference, created_at)
SELECT order_id, total, method, status, 'OJH-' || lpad(nextval('payment_ref')::text, 10, '0'), created_at
FROM (
    SELECT order_id, total, 'card' AS method, 'failed' AS status, ordered_at + interval '2 minutes' AS created_at, 1 AS attempt
    FROM order_totals
    WHERE order_status IN ('paid', 'shipped', 'delivered') AND r_fail < 0.12
    UNION ALL
    SELECT order_id, total,
           CASE WHEN r_method < 0.45 THEN 'card' WHEN r_method < 0.75 THEN 'bank_transfer'
                WHEN r_method < 0.90 THEN 'ussd' ELSE 'pay_on_delivery' END,
           'successful', ordered_at + interval '6 minutes', 2
    FROM order_totals
    WHERE order_status IN ('paid', 'shipped', 'delivered')
    UNION ALL
    SELECT order_id, total, 'bank_transfer', 'initiated', ordered_at + interval '3 minutes', 1
    FROM order_totals
    WHERE order_status = 'pending' AND r_fail < 0.7
    UNION ALL
    SELECT order_id, total, 'card', CASE WHEN r_fail < 0.5 THEN 'refunded' ELSE 'failed' END,
           ordered_at + interval '4 minutes', 1
    FROM order_totals
    WHERE order_status = 'cancelled'
) p
ORDER BY order_id, attempt;

\echo 'Shipments'
INSERT INTO shipments (order_id, courier, tracking_number, shipment_status, shipped_at, delivered_at)
SELECT order_id, courier,
       upper(left(replace(courier, ' ', ''), 3)) || lpad(order_id::text, 10, '0'),
       CASE order_status WHEN 'delivered' THEN 'delivered' WHEN 'shipped' THEN 'in_transit' ELSE 'processing' END,
       CASE WHEN order_status IN ('shipped', 'delivered') THEN shipped_at END,
       CASE WHEN order_status = 'delivered'
            THEN least(shipped_at + interval '1 day' + r_del * interval '4 days', timestamptz '2026-10-31 00:00') END
FROM (SELECT order_id, order_status,
             (ARRAY['GIG Logistics','Red Star Express','Kwik Delivery','DHL Nigeria'])[1 + floor(random() * 4)::int] AS courier,
             ordered_at + interval '2 hours' + random() * interval '1 day' AS shipped_at,
             random() AS r_del
      FROM order_totals
      WHERE order_status IN ('paid', 'shipped', 'delivered')) s;

\echo 'Reviews'
INSERT INTO reviews (product_id, customer_id, rating, comment, reviewed_at)
SELECT product_id, customer_id, rating,
       CASE WHEN r_comment < 0.4 THEN NULL ELSE comments[rating] END,
       least(ordered_at + interval '5 days' + r_date * interval '10 days', timestamptz '2026-10-31 00:00')
FROM (SELECT oi.product_id, o.customer_id, o.ordered_at,
             CASE WHEN r < 0.06 THEN 1 WHEN r < 0.13 THEN 2 WHEN r < 0.25 THEN 3 WHEN r < 0.55 THEN 4 ELSE 5 END AS rating,
             random() AS r_comment, random() AS r_date
      FROM (SELECT oi.*, random() AS r, random() AS pick FROM order_items oi WHERE oi.order_id > 10) oi
      JOIN orders o USING (order_id)
      WHERE o.order_status = 'delivered' AND oi.pick < 0.11) s,
     (SELECT ARRAY['Very poor, not as described.','Below what I expected.','It is okay for the price.',
                   'Good product, delivery was fast.','Excellent, will buy again.'] AS comments) pool
ON CONFLICT (product_id, customer_id) DO NOTHING;

\echo 'Vacuum and analyze'
VACUUM ANALYZE;
