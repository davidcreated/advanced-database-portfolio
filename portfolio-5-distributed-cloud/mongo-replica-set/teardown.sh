#!/bin/zsh
# Stops every replica set member and deletes their files.
# mongod --shutdown is not available on macOS, so members get SIGTERM, which is mongod's clean shutdown.
BASE=~/ojahub-cluster/rs
listening() { lsof -nP -iTCP:27018-27020 -sTCP:LISTEN -t 2> /dev/null | sort -u; }

[ -n "$(listening)" ] && kill $(listening)
for i in $(seq 1 60); do [ -z "$(listening)" ] && break; sleep 0.5; done
[ -n "$(listening)" ] && kill -9 $(listening) && sleep 1
rm -rf $BASE
echo "replica set stopped and removed; members still listening: $(listening | wc -l | tr -d ' ')"
