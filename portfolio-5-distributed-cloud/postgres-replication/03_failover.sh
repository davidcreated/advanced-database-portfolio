#!/bin/zsh
# OjaHub Marketplace: failover by promoting the replica, and the split brain that follows if the old
# primary is not stopped. The real 5432 server stays up throughout; run teardown.sh afterwards to
# discard the promoted copy.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
P() { psql -p 5432 -d ojahub -XAtq "$@"; }
R() { psql -p 5433 -d ojahub -XAtq "$@"; }
role() { echo "  $1: in recovery $(psql -p $2 -d postgres -XAtc 'SELECT pg_is_in_recovery()'), timeline $(psql -p $2 -d postgres -XAtc 'SELECT timeline_id FROM pg_control_checkpoint()')"; }

P -c "SELECT txdemo.reset()" > /dev/null

echo "========== 1. Before: one primary, one standby =========="
role "primary 5432" 5432
role "replica 5433" 5433

echo "\n========== 2. The primary is declared dead, so the replica is promoted =========="
start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
R -c "SELECT pg_promote(wait => true)" > /dev/null
end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "  pg_promote() finished in $(printf '%.0f' $(( (end - start) * 1000 ))) ms"
R -c "CHECKPOINT"
role "promoted 5433" 5433
new_r=$(R -c "SELECT txdemo.place_order(2, 2, 1)")
echo "  it now takes orders: order $new_r for customer 2"

echo "\n========== 3. Split brain: the old primary was never really dead =========="
new_p=$(P -c "SELECT txdemo.place_order(1, 2, 1)")
echo "  the old primary also takes an order: order $new_p for customer 1"
echo "  on 5432: $(P -c "SELECT string_agg('order ' || order_id || ' belongs to customer ' || customer_id, ', ') FROM ojahub.orders WHERE ordered_at >= timestamptz '2026-10-31'")"
echo "  on 5433: $(R -c "SELECT string_agg('order ' || order_id || ' belongs to customer ' || customer_id, ', ') FROM ojahub.orders WHERE ordered_at >= timestamptz '2026-10-31'")"
echo "  replicas streaming from 5432 now: $(psql -p 5432 -d postgres -XAtc 'SELECT count(*) FROM pg_stat_replication')"
echo "  Each side now holds an order the other has never seen, and nothing will reconcile them."
if [ "$new_r" = "$new_p" ]; then
  echo "  Worse, both handed out order number $new_p to different customers."
else
  echo "  The IDs differ by $(( new_r - new_p )) only because a promoted server can skip ahead in its sequences (PostgreSQL"
  echo "  logs sequence values 32 at a time). After that many more orders on 5432 the order numbers would collide."
fi
echo "  Real failover tooling stops (fences) the old primary first, then rebuilds it as a standby with pg_rewind."

P -c "SELECT txdemo.reset()" > /dev/null
echo "\nDemo order removed from 5432. Run teardown.sh to discard the promoted 5433 copy."
