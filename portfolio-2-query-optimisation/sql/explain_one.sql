-- Execution plan for a single query from perf.queries
-- Usage: psql -d ojahub -v q=1 -f sql/explain_one.sql

SET search_path TO ojahub, perf;
SET timezone TO 'Africa/Lagos';

SELECT 'EXPLAIN (ANALYZE, BUFFERS) ' || sql_text FROM perf.queries WHERE query_no = :q
\gexec
