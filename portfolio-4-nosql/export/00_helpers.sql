-- Shared helpers for the export scripts: MongoDB Extended JSON for dates and money
SET search_path TO ojahub;
SET timezone TO 'UTC';
SET max_parallel_workers_per_gather = 0;

CREATE FUNCTION pg_temp.d(ts timestamptz) RETURNS json LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN ts IS NULL THEN NULL
                ELSE json_build_object('$date', to_char(ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) END
$$;

-- Money goes across as Decimal128 so naira amounts never pass through floating point
CREATE FUNCTION pg_temp.money(n numeric) RETURNS json LANGUAGE sql IMMUTABLE AS $$
    SELECT json_build_object('$numberDecimal', n::text)
$$;
