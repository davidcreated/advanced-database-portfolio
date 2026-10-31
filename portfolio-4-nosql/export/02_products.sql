\ir 00_helpers.sql

-- PostgreSQL has no category specific attributes, so they are generated here from product_id.
-- Same product_id always gives the same attributes. Where a seed product's description states its
-- storage and RAM, those values are used instead.
SELECT json_strip_nulls(json_build_object(
    '_id', p.product_id,
    'name', p.product_name,
    'description', p.description,
    'price', pg_temp.money(p.unit_price),
    'stock_qty', p.stock_qty,
    'is_active', p.is_active,
    'created_at', pg_temp.d(p.created_at),
    'category', json_build_object('id', c.category_id, 'name', c.category_name, 'parent', pc.category_name),
    'seller', json_build_object('seller_id', s.seller_id, 'business_name', s.business_name,
                                'state', st.state_name, 'verified', s.is_verified),
    'attributes', CASE p.category_id
        WHEN 2 THEN json_build_object(
            'storage_gb', coalesce(substring(p.description FROM '(\d+)GB,')::int,
                                   (ARRAY[64, 128, 256])[1 + p.product_id % 3]),
            'ram_gb', coalesce(substring(p.description FROM '(\d+)GB RAM')::int,
                               (ARRAY[4, 6, 8, 12])[1 + (p.product_id / 3) % 4]),
            'network', CASE WHEN p.product_id % 4 = 0 THEN '5G' ELSE '4G' END,
            'dual_sim', p.product_id % 5 <> 0)
        WHEN 3 THEN json_build_object(
            'colour', (ARRAY['Black', 'White', 'Blue', 'Red'])[1 + p.product_id % 4],
            'compatible_with', CASE p.product_id % 3 WHEN 0 THEN json_build_array('Android')
                                   WHEN 1 THEN json_build_array('iPhone') ELSE json_build_array('Android', 'iPhone') END,
            'warranty_months', (ARRAY[3, 6, 12])[1 + p.product_id % 3])
        WHEN 5 THEN json_build_object(
            'yards', (ARRAY[2, 4, 5, 6, 10])[1 + p.product_id % 5],
            'material', (ARRAY['Cotton', 'Lace', 'Silk blend', 'Polyester'])[1 + (p.product_id / 5) % 4],
            'pattern', (ARRAY['Ankara', 'Plain', 'Embroidered', 'Adire'])[1 + (p.product_id / 7) % 4],
            'colour', (ARRAY['Gold', 'Wine', 'Royal blue', 'Emerald', 'Peach'])[1 + p.product_id % 5])
        WHEN 6 THEN json_build_object(
            'leather', (ARRAY['Cow', 'Goat'])[1 + p.product_id % 2],
            'colour', (ARRAY['Brown', 'Black', 'Tan'])[1 + p.product_id % 3],
            'handmade', p.product_id % 4 <> 0,
            'sizes', CASE WHEN p.product_name ~ 'Sandals|Slippers|Brogues'
                          THEN json_build_array(40, 41, 42, 43, 44, 45, 46) END)
        WHEN 7 THEN json_build_object(
            'weight_kg', (ARRAY[0.5, 1, 2, 5, 10, 25])[1 + p.product_id % 6],
            'shelf_life_months', (ARRAY[3, 6, 12, 18])[1 + p.product_id % 4],
            'origin_state', (SELECT state_name FROM states WHERE state_id = 1 + p.product_id % 37),
            'organic', p.product_id % 3 = 0)
        WHEN 8 THEN json_build_object(
            'power_watts', (ARRAY[45, 60, 150, 800, 1500, 2000])[1 + p.product_id % 6],
            'warranty_months', (ARRAY[6, 12, 24])[1 + p.product_id % 3],
            'colour', (ARRAY['Silver', 'Black', 'White'])[1 + p.product_id % 3])
    END,
    'rating', json_build_object('count', coalesce(r.review_count, 0), 'average', r.avg_rating),
    'latest_reviews', r.latest
))
FROM products p
JOIN categories c ON c.category_id = p.category_id
LEFT JOIN categories pc ON pc.category_id = c.parent_category_id
JOIN sellers s ON s.seller_id = p.seller_id
JOIN states st ON st.state_id = s.state_id
LEFT JOIN LATERAL (
    SELECT count(*) AS review_count,
           round(avg(rv.rating), 2)::float8 AS avg_rating,
           (SELECT json_agg(json_build_object('customer', cu.first_name, 'rating', x.rating,
                                              'comment', x.comment, 'reviewed_at', pg_temp.d(x.reviewed_at))
                            ORDER BY x.reviewed_at DESC)
            FROM (SELECT * FROM reviews WHERE product_id = p.product_id ORDER BY reviewed_at DESC LIMIT 3) x
            JOIN customers cu ON cu.customer_id = x.customer_id) AS latest
    FROM reviews rv
    WHERE rv.product_id = p.product_id
) r ON true
ORDER BY p.product_id;
