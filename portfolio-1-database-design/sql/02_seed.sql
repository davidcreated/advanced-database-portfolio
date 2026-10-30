-- OjaHub Marketplace: sample data
-- Run on a fresh schema straight after 01_schema.sql so identity values start at 1

SET search_path TO ojahub;
SET timezone TO 'Africa/Lagos';

INSERT INTO states (state_id, state_name, region) VALUES
    (1, 'Abia', 'South East'),          (2, 'Adamawa', 'North East'),
    (3, 'Akwa Ibom', 'South South'),    (4, 'Anambra', 'South East'),
    (5, 'Bauchi', 'North East'),        (6, 'Bayelsa', 'South South'),
    (7, 'Benue', 'North Central'),      (8, 'Borno', 'North East'),
    (9, 'Cross River', 'South South'),  (10, 'Delta', 'South South'),
    (11, 'Ebonyi', 'South East'),       (12, 'Edo', 'South South'),
    (13, 'Ekiti', 'South West'),        (14, 'Enugu', 'South East'),
    (15, 'Federal Capital Territory', 'North Central'),
    (16, 'Gombe', 'North East'),        (17, 'Imo', 'South East'),
    (18, 'Jigawa', 'North West'),       (19, 'Kaduna', 'North West'),
    (20, 'Kano', 'North West'),         (21, 'Katsina', 'North West'),
    (22, 'Kebbi', 'North West'),        (23, 'Kogi', 'North Central'),
    (24, 'Kwara', 'North Central'),     (25, 'Lagos', 'South West'),
    (26, 'Nasarawa', 'North Central'),  (27, 'Niger', 'North Central'),
    (28, 'Ogun', 'South West'),         (29, 'Ondo', 'South West'),
    (30, 'Osun', 'South West'),         (31, 'Oyo', 'South West'),
    (32, 'Plateau', 'North Central'),   (33, 'Rivers', 'South South'),
    (34, 'Sokoto', 'North West'),       (35, 'Taraba', 'North East'),
    (36, 'Yobe', 'North East'),         (37, 'Zamfara', 'North West');

INSERT INTO customers (first_name, last_name, email, phone, created_at) VALUES
    ('Chiamaka', 'Okeke',     'chiamaka.okeke@example.ng',   '+2348031234501', '2026-06-14 10:12'),
    ('Ibrahim',  'Musa',      'ibrahim.musa@example.ng',     '+2348052234502', '2026-06-20 18:40'),
    ('Funmilayo','Adeyemi',   'funmi.adeyemi@example.ng',    '+2347033234503', '2026-07-02 09:05'),
    ('Emeka',    'Nwosu',     'emeka.nwosu@example.ng',      '+2348064234504', '2026-07-11 21:30'),
    ('Aisha',    'Bello',     'aisha.bello@example.ng',      '+2349015234505', '2026-07-19 13:22'),
    ('Tunde',    'Bakare',    'tunde.bakare@example.ng',     '+2348026234506', '2026-08-01 08:47'),
    ('Ngozi',    'Eze',       'ngozi.eze@example.ng',        '+2347037234507', '2026-08-09 16:15'),
    ('Yusuf',    'Abdullahi', 'yusuf.abdullahi@example.ng',  '+2348148234508', '2026-08-23 11:58'),
    ('Blessing', 'Okon',      'blessing.okon@example.ng',    '+2348099234509', '2026-09-04 19:03'),
    ('Segun',    'Ogunleye',  'segun.ogunleye@example.ng',   '+2348130234510', '2026-09-12 07:36');

INSERT INTO addresses (customer_id, street, city, state_id, is_default) VALUES
    (1,  '14 Adeola Odeku Street',     'Victoria Island', 25, true),
    (2,  '7 Zoo Road',                 'Kano',            20, true),
    (3,  '22 Ring Road',               'Ibadan',          31, true),
    (4,  '5 Ogui Road',                'Enugu',           14, true),
    (5,  '31 Aminu Kano Crescent',     'Wuse II',         15, true),
    (6,  '9 Oke Ilewo Road',           'Abeokuta',        28, true),
    (7,  '18 Aba Road',                'Port Harcourt',   33, true),
    (8,  '3 Ahmadu Bello Way',         'Kaduna',          19, true),
    (9,  '40 Oron Road',               'Uyo',             3,  true),
    (10, '12 Allen Avenue',            'Ikeja',           25, true),
    (1,  '2 Broad Street, 4th Floor',  'Lagos Island',    25, false);

INSERT INTO sellers (business_name, email, phone, state_id, joined_at, is_verified) VALUES
    ('Mama Nkechi Fabrics',  'sales@mamankechi.example.ng',  '+2348031110001', 4,  '2026-05-02 09:00', true),
    ('Lagos Gadget Hub',     'hello@lagosgadget.example.ng', '+2348091110002', 25, '2026-05-10 12:30', true),
    ('Kano Leather Works',   'orders@kanoleather.example.ng','+2348061110003', 20, '2026-05-18 08:15', true),
    ('Ibadan Farm Fresh',    'farm@ibadanfresh.example.ng',  '+2347031110004', 31, '2026-06-03 14:45', false),
    ('PH Home Essentials',   'shop@phhome.example.ng',       '+2348171110005', 33, '2026-06-21 10:20', true);

INSERT INTO categories (category_name, parent_category_id) VALUES
    ('Electronics',      NULL),
    ('Phones',           1),
    ('Accessories',      1),
    ('Fashion',          NULL),
    ('Fabrics',          4),
    ('Leather Goods',    4),
    ('Groceries',        NULL),
    ('Home and Kitchen', NULL);

INSERT INTO products (seller_id, category_id, product_name, description, unit_price, stock_qty) VALUES
    (2, 2, 'Tecno Spark 20',           '128GB, 8GB RAM, dual SIM',              189000.00, 25),
    (2, 2, 'Samsung Galaxy A15',       '128GB, 6GB RAM',                        245000.00, 12),
    (2, 3, '20000mAh Power Bank',      'Fast charging, two USB ports',           18500.00, 60),
    (2, 3, 'Oraimo Wireless Earbuds',  'Bluetooth 5.3 with charging case',       24000.00, 40),
    (1, 5, 'Ankara Print, 6 Yards',    '100 percent cotton wax print',           15000.00, 80),
    (1, 5, 'George Wrapper',           'Hand embroidered Indian George',         45000.00, 15),
    (1, 5, 'Swiss Lace, 5 Yards',      'Voile lace with stone work',             38000.00, 20),
    (3, 6, 'Leather Sandals',          'Hand stitched cow leather, sizes 40 to 46', 22000.00, 30),
    (3, 6, 'Handmade Leather Bag',     'Tanned goat leather tote',               55000.00, 10),
    (4, 7, 'Ofada Rice, 5kg',          'Locally milled, stone free',             12500.00, 100),
    (4, 7, 'Red Palm Oil, 4 Litres',   'Fresh pressed',                           9800.00, 50),
    (4, 7, 'Ijebu Garri, 10kg',        'Fine grain, sour',                        8500.00, 70),
    (5, 8, 'Non Stick Pot Set',        'Five piece set with glass lids',         42000.00, 18),
    (5, 8, 'Standing Fan, 18 Inch',    'Three speed, remote control',            36500.00, 0);

INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at) VALUES
    (1,  1,  'delivered', '2026-09-02 14:21'),
    (2,  2,  'delivered', '2026-09-05 20:10'),
    (3,  3,  'shipped',   '2026-10-12 09:44'),
    (4,  4,  'paid',      '2026-10-20 17:03'),
    (5,  5,  'pending',   '2026-10-25 22:18'),
    (6,  6,  'cancelled', '2026-09-18 11:35'),
    (7,  7,  'delivered', '2026-09-28 13:50'),
    (1,  11, 'paid',      '2026-10-22 08:12'),
    (8,  8,  'shipped',   '2026-10-15 15:27'),
    (10, 10, 'delivered', '2026-10-03 19:41');

-- Order 10 bought the power bank during a promo, so its captured price differs from the current list price
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1,  1,  1, 189000.00), (1,  3,  2, 18500.00),
    (2,  8,  2, 22000.00),
    (3,  5,  3, 15000.00),  (3,  6,  1, 45000.00),
    (4,  2,  1, 245000.00),
    (5,  10, 2, 12500.00),  (5,  11, 1, 9800.00),
    (6,  13, 1, 42000.00),
    (7,  9,  1, 55000.00),  (7,  4,  1, 24000.00),
    (8,  12, 2, 8500.00),   (8,  10, 1, 12500.00),
    (9,  7,  1, 38000.00),
    (10, 3,  1, 17500.00),  (10, 4,  2, 24000.00);

INSERT INTO payments (order_id, amount, payment_method, payment_status, reference, created_at) VALUES
    (1,  226000.00, 'card',            'successful', 'OJH-PAY-000001', '2026-09-02 14:23'),
    (2,   44000.00, 'card',            'failed',     'OJH-PAY-000002', '2026-09-05 20:12'),
    (2,   44000.00, 'bank_transfer',   'successful', 'OJH-PAY-000003', '2026-09-05 20:19'),
    (3,   90000.00, 'ussd',            'successful', 'OJH-PAY-000004', '2026-10-12 09:46'),
    (4,  245000.00, 'card',            'successful', 'OJH-PAY-000005', '2026-10-20 17:05'),
    (5,   34800.00, 'bank_transfer',   'initiated',  'OJH-PAY-000006', '2026-10-25 22:20'),
    (6,   42000.00, 'card',            'refunded',   'OJH-PAY-000007', '2026-09-18 11:37'),
    (7,   79000.00, 'pay_on_delivery', 'successful', 'OJH-PAY-000008', '2026-10-01 12:05'),
    (8,   29500.00, 'card',            'failed',     'OJH-PAY-000009', '2026-10-22 08:14'),
    (8,   29500.00, 'ussd',            'successful', 'OJH-PAY-000010', '2026-10-22 08:21'),
    (9,   38000.00, 'bank_transfer',   'successful', 'OJH-PAY-000011', '2026-10-15 15:30'),
    (10,  65500.00, 'card',            'successful', 'OJH-PAY-000012', '2026-10-03 19:43');

INSERT INTO shipments (order_id, courier, tracking_number, shipment_status, shipped_at, delivered_at) VALUES
    (1,  'GIG Logistics',    'GIG7730012451', 'delivered',  '2026-09-03 10:00', '2026-09-05 15:42'),
    (2,  'Red Star Express', 'RSE5521840017', 'delivered',  '2026-09-07 09:30', '2026-09-10 12:15'),
    (3,  'GIG Logistics',    'GIG7730019982', 'in_transit', '2026-10-14 11:20', NULL),
    (4,  'Kwik Delivery',    'KWK0041187301', 'processing', NULL,               NULL),
    (7,  'Red Star Express', 'RSE5521863342', 'delivered',  '2026-09-29 08:45', '2026-10-01 12:00'),
    (8,  'Kwik Delivery',    'KWK0041190455', 'processing', NULL,               NULL),
    (9,  'GIG Logistics',    'GIG7730021307', 'in_transit', '2026-10-17 13:10', NULL),
    (10, 'Kwik Delivery',    'KWK0041176620', 'delivered',  '2026-10-04 09:15', '2026-10-04 16:40');

INSERT INTO reviews (product_id, customer_id, rating, comment, reviewed_at) VALUES
    (1,  1,  5, 'Phone came sealed and works perfectly. Fast delivery to VI.', '2026-09-07 18:20'),
    (3,  1,  4, 'Charges quickly, a bit heavy in the bag.',                   '2026-09-08 09:11'),
    (8,  2,  4, 'Good quality leather, size runs slightly big.',              '2026-09-12 20:45'),
    (9,  7,  5, 'Beautiful bag, you can see the handwork.',                   '2026-10-03 14:02'),
    (4,  10, 3, 'Sound is fine but the case scratches easily.',               '2026-10-06 21:30'),
    (3,  10, 5, 'Got it on promo, great value.',                              '2026-10-06 21:34');
