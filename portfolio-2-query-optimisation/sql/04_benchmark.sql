-- OjaHub Marketplace: median execution time for every query in perf.queries
-- Each query runs 7 times; the first run only warms the cache and is discarded.
-- The write test places 10,000 orders inside a subtransaction that is rolled back, so no data is kept.

SET search_path TO ojahub, perf;
SET timezone TO 'Africa/Lagos';

CREATE OR REPLACE FUNCTION perf.bench(query text, runs int DEFAULT 7)
RETURNS TABLE (median_ms numeric, scans text)
LANGUAGE plpgsql
SET search_path = ojahub, perf
AS $$
DECLARE
    plan  jsonb;
    times numeric[] := '{}';
BEGIN
    FOR i IN 1..runs LOOP
        EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || query INTO plan;
        IF i > 1 THEN
            times := times || (plan -> 0 ->> 'Execution Time')::numeric;
        END IF;
    END LOOP;

    median_ms := (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY t)::numeric, 2) FROM unnest(times) t);

    scans := (SELECT string_agg(DISTINCT
                         (n ->> 'Node Type')
                         || coalesce(' on ' || (n ->> 'Relation Name'), '')
                         || coalesce(' using ' || (n ->> 'Index Name'), ''), '; ')
              FROM jsonb_path_query(plan, 'strict $.** ? (@."Node Type" like_regex "Scan")') n);
    RETURN NEXT;
END;
$$;

SELECT q.query_no AS q, b.median_ms, b.scans
FROM perf.queries q
CROSS JOIN LATERAL perf.bench(q.sql_text) b
ORDER BY q.query_no;

CREATE OR REPLACE FUNCTION perf.bench_write(statement text, runs int DEFAULT 5)
RETURNS numeric
LANGUAGE plpgsql
SET search_path = ojahub, perf
AS $$
DECLARE
    plan  jsonb;
    times numeric[] := '{}';
BEGIN
    FOR i IN 1..runs LOOP
        BEGIN
            EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || statement INTO plan;
            IF i > 1 THEN
                times := times || (plan -> 0 ->> 'Execution Time')::numeric;
            END IF;
            RAISE EXCEPTION 'undo benchmark writes';
        EXCEPTION WHEN raise_exception THEN
            NULL;
        END;
    END LOOP;
    RETURN (SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY t)::numeric, 2) FROM unnest(times) t);
END;
$$;

SELECT 'Place 10,000 orders with one item each' AS write_test,
       perf.bench_write($w$
WITH new_orders AS (
    INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
    SELECT a.customer_id, a.address_id, 'pending', timestamptz '2026-10-31' + g * interval '1 second'
    FROM generate_series(1, 10000) g
    JOIN addresses a ON a.address_id = 1 + (g * 7919) % 60021
    RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT order_id, 1 + (order_id * 31) % 100014, 1, 5000
FROM new_orders
$w$) AS median_ms;
