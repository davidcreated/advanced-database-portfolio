#!/bin/zsh
# OjaHub Marketplace: synchronous replication, what it costs, and what happens when the replica dies.
# Run after setup.sh. The primary is put back to asynchronous at the end.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
DIR=~/ojahub-cluster/pg-replica
P() { psql -p 5432 -d ojahub -XAtq "$@"; }
SCRIPT=$(mktemp)
echo "INSERT INTO public.sync_test (note) VALUES ('order placed');" > $SCRIPT

P -c "DROP TABLE IF EXISTS public.sync_test" -c "CREATE TABLE public.sync_test (id bigserial PRIMARY KEY, note text, at timestamptz DEFAULT clock_timestamp())" 2> /dev/null

bench() {
  local level=$1
  PGOPTIONS="-c synchronous_commit=$level" pgbench -p 5432 -n -c 1 -t 500 -f $SCRIPT ojahub 2>&1 |
    awk -v l="$level" '/latency average/ {printf "  %-14s 500 commits, average commit latency %s ms\n", l, $4}'
}
state() {
  psql -p 5432 -d postgres -XAt -c "SELECT '  replica sync_state: ' || coalesce((SELECT sync_state FROM pg_stat_replication WHERE application_name = 'ojahub_replica'), 'not connected')"
}

echo "========== 1. Asynchronous: the primary commits without waiting for the replica =========="
state
bench local

echo "\n========== 2. Synchronous: the primary waits for the replica on every commit =========="
P -c "ALTER SYSTEM SET synchronous_standby_names = 'ojahub_replica'" -c "SELECT pg_reload_conf()" > /dev/null
sleep 1
state
bench on
bench remote_apply
echo "  on           = wait until the replica has the commit safely on disk"
echo "  remote_apply = also wait until it is visible to queries on the replica"

echo "\n========== 3. The replica goes down while the primary is synchronous =========="
pg_ctl -D $DIR -m fast -w stop > /dev/null
echo "  replica stopped"
state
OUT=$(mktemp)
echo "  placing an order with statement_timeout = 3s..."
P -c "SET statement_timeout = '3s'" -c "INSERT INTO public.sync_test (note) VALUES ('order while replica is down') RETURNING 'insert returned id ' || id" > $OUT 2>&1 &
client=$!
sleep 5
psql -p 5432 -d postgres -XAt -c "SELECT '  after ' || round(extract(epoch FROM now() - query_start)) || 's the commit is still waiting (' || wait_event_type || ': ' || wait_event || ')' FROM pg_stat_activity WHERE wait_event = 'SyncRep'"
echo "  statement_timeout never fires here: PostgreSQL switches it off before the commit step, so the order would wait forever"
echo "  an operator cancels the stuck commit:"
psql -p 5432 -d postgres -XAt -c "SELECT '  pg_cancel_backend: ' || pg_cancel_backend(pid) FROM pg_stat_activity WHERE wait_event = 'SyncRep'"
wait $client
sed 's/^/  /' $OUT
rm -f $OUT
echo "  is that order on the primary anyway? $(P -c "SELECT count(*) FROM public.sync_test WHERE note = 'order while replica is down'") row"

echo "\n========== 4. The replica comes back and catches up =========="
pg_ctl -D $DIR -o "-p 5433" -l ~/ojahub-cluster/pg-replica.log -w start > /dev/null
for i in $(seq 1 30); do
  [ "$(psql -p 5432 -d postgres -XAtc "SELECT count(*) FROM pg_stat_replication WHERE application_name = 'ojahub_replica' AND state = 'streaming'")" = 1 ] && break
  sleep 0.5
done
state
echo "  rows on the replica: $(psql -p 5433 -d ojahub -XAtc 'SELECT count(*) FROM public.sync_test'), on the primary: $(P -c 'SELECT count(*) FROM public.sync_test')"

P -c "ALTER SYSTEM RESET synchronous_standby_names" -c "SELECT pg_reload_conf()" > /dev/null
P -c "DROP TABLE public.sync_test"
rm -f $SCRIPT
sleep 1
echo "\nPrimary set back to asynchronous; test table dropped"
state
