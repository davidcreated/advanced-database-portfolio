#!/bin/zsh
# Stops the router, shards and config server, and deletes their files.
# mongod --shutdown is not available on macOS, so every process gets SIGTERM, its clean shutdown.
BASE=~/ojahub-cluster/shard
listening() { lsof -nP -iTCP:27030-27040 -sTCP:LISTEN -t 2> /dev/null | sort -u; }

[ -n "$(listening)" ] && kill $(listening)
for i in $(seq 1 60); do [ -z "$(listening)" ] && break; sleep 0.5; done
[ -n "$(listening)" ] && kill -9 $(listening) && sleep 1
rm -rf $BASE
echo "sharded cluster stopped and removed; processes still listening: $(listening | wc -l | tr -d ' ')"
