\ir 00_helpers.sql

SELECT json_strip_nulls(json_build_object(
    '_id', review_id,
    'product_id', product_id,
    'customer_id', customer_id,
    'rating', rating,
    'comment', comment,
    'reviewed_at', pg_temp.d(reviewed_at)
))
FROM reviews
ORDER BY review_id;
