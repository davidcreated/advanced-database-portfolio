#!/bin/zsh
# OjaHub Marketplace: a hot standby replica of the 5432 primary, running on port 5433.
# The replica's files live outside the repo in ~/ojahub-cluster/pg-replica.
set -e
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
DIR=~/ojahub-cluster/pg-replica
mkdir -p ~/ojahub-cluster

echo "Cloning the primary with pg_basebackup..."
start=$(date +%s)
pg_basebackup -D $DIR -R -X stream -c fast -d "port=5432 application_name=ojahub_replica"
echo "Base backup done in $(( $(date +%s) - start ))s, replica size $(du -sh $DIR | cut -f1)"

pg_ctl -D $DIR -o "-p 5433" -l ~/ojahub-cluster/pg-replica.log -w start > /dev/null
echo "Replica started on port 5433\n"

for i in $(seq 1 30); do
  [ "$(psql -p 5432 -d postgres -XAtc "SELECT count(*) FROM pg_stat_replication WHERE application_name = 'ojahub_replica' AND state = 'streaming'")" = 1 ] && break
  sleep 0.5
done
echo "On the replica (5433):"
psql -p 5433 -d ojahub -XAt -c "SELECT '  in recovery (read only standby): ' || pg_is_in_recovery()"
psql -p 5433 -d ojahub -XAt -c "SELECT '  orders visible: ' || count(*) FROM ojahub.orders"
echo "On the primary (5432):"
psql -p 5432 -d postgres -XAt -F' | ' -c "SELECT '  replica ' || application_name, 'state ' || state, 'sync_state ' || sync_state FROM pg_stat_replication"
