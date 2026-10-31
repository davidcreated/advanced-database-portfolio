\ir 00_helpers.sql

SELECT json_build_object(
    '_id', c.customer_id,
    'first_name', c.first_name,
    'last_name', c.last_name,
    'email', c.email,
    'phone', c.phone,
    'created_at', pg_temp.d(c.created_at),
    'addresses', a.addresses
)
FROM customers c
JOIN (SELECT ad.customer_id,
             json_agg(json_build_object('address_id', ad.address_id, 'street', ad.street, 'city', ad.city,
                                        'state', st.state_name, 'region', st.region, 'is_default', ad.is_default)
                      ORDER BY ad.is_default DESC, ad.address_id) AS addresses
      FROM addresses ad JOIN states st USING (state_id)
      GROUP BY ad.customer_id) a USING (customer_id)
ORDER BY c.customer_id;
