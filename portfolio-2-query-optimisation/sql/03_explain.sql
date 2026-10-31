-- OjaHub Marketplace: execution plans for every query in perf.queries
-- Run once before 05_indexes.sql and once after, saving the output each time.

SET search_path TO ojahub, perf;
SET timezone TO 'Africa/Lagos';

SELECT format('SELECT %L AS query', 'Q' || query_no || ': ' || question),
       'EXPLAIN (ANALYZE, BUFFERS) ' || sql_text
FROM perf.queries
ORDER BY query_no
\gexec
