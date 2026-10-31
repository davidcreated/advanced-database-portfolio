#!/bin/zsh
# OjaHub Marketplace: asynchronous streaming replication in action. Run after setup.sh.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
P() { psql -p 5432 -d ojahub -XAtq "$@"; }
R() { psql -p 5433 -d ojahub -XAtq "$@"; }

echo "========== 1. A new order on the primary, and how soon the replica sees it =========="
P -c "SELECT txdemo.reset()" > /dev/null
order=$(P -c "SELECT txdemo.place_order(1, 2, 1)")
commit_lsn=$(P -c "SELECT pg_current_wal_lsn()")
start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
polls=0
until [ "$(R -c "SELECT pg_last_wal_replay_lsn() >= '$commit_lsn'")" = t ]; do polls=$((polls + 1)); done
end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "primary committed order $order at WAL position $commit_lsn"
echo "replica replayed past that position after $(printf "%.1f" $(( (end - start) * 1000 ))) ms ($polls extra polls)"
echo "replica now reads: $(R -c "SELECT 'order ' || order_id || ' for customer ' || customer_id || ', status ' || order_status FROM ojahub.orders WHERE order_id = $order")"

echo "\n========== 2. Replica lag while the primary writes 1 million rows =========="
P -c "DROP TABLE IF EXISTS public.lag_test; CREATE TABLE public.lag_test (id int, payload text)"
P -c "INSERT INTO public.lag_test SELECT g, md5(g::text) FROM generate_series(1, 1000000) g" &
writer=$!
echo "time      bytes behind   replay_lag"
while kill -0 $writer 2> /dev/null; do
  psql -p 5432 -d postgres -XAt -F'   ' -c "SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS'),
         lpad(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)::text, 12),
         coalesce(replay_lag::text, 'caught up')
         FROM pg_stat_replication WHERE application_name = 'ojahub_replica'"
  sleep 0.2
done
wait $writer
sleep 1
psql -p 5432 -d postgres -XAt -F'   ' -c "SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') || ' (after)',
       lpad(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)::text, 12), coalesce(replay_lag::text, 'caught up')
       FROM pg_stat_replication WHERE application_name = 'ojahub_replica'"
echo "rows on primary: $(P -c 'SELECT count(*) FROM public.lag_test'), rows on replica: $(R -c 'SELECT count(*) FROM public.lag_test')"

echo "\n========== 3. The replica is read only =========="
psql -p 5433 -d ojahub -Xq -c "UPDATE ojahub.products SET stock_qty = 99 WHERE product_id = 14" 2>&1 | sed 's/^/replica says: /'

P -c "DROP TABLE public.lag_test"
P -c "SELECT txdemo.reset()" > /dev/null
echo "\nCleaned up: test table dropped and demo order removed on the primary (and so on the replica)"
