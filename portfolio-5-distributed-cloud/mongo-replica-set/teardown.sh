#!/bin/zsh
# Stops every replica set member and deletes their files.
BASE=~/ojahub-cluster/rs
for port in 27018 27019 27020; do
  [ -d $BASE/$port ] && mongod --shutdown --dbpath $BASE/$port > /dev/null 2>&1
done
sleep 1
rm -rf $BASE
echo "replica set stopped and removed; members still listening: $(lsof -nP -iTCP:27018-27020 -sTCP:LISTEN 2> /dev/null | grep -c mongod)"
