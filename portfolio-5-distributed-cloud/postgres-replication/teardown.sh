#!/bin/zsh
# Stops and removes the replica, and makes sure the primary no longer waits for it.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
DIR=~/ojahub-cluster/pg-replica

psql -p 5432 -d postgres -Xq -c "ALTER SYSTEM RESET synchronous_standby_names" -c "SELECT pg_reload_conf()" > /dev/null
[ -d $DIR ] && pg_ctl -D $DIR -m fast -w stop > /dev/null 2>&1
rm -rf $DIR ~/ojahub-cluster/pg-replica.log
echo "Replica stopped and removed; primary synchronous_standby_names is '$(psql -p 5432 -d postgres -XAtc 'SHOW synchronous_standby_names')'"
