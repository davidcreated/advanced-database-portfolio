\ir 00_helpers.sql

SELECT json_build_object('_id', category_id, 'name', category_name, 'parent_id', parent_category_id)
FROM categories
ORDER BY category_id;
