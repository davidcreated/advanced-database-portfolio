#!/bin/zsh
# OjaHub Marketplace: a small sharded cluster. One config server (27030), two shards called north
# (27031) and south (27032), and a mongos router (27040) that applications connect to.
# Files live outside the repo in ~/ojahub-cluster/shard.
set -e
BASE=~/ojahub-cluster/shard
up() { until mongosh --quiet --port $1 --eval "db.runCommand({ ping: 1 }).ok" > /dev/null 2>&1; do sleep 0.3; done; }

start_member() {
  local role=$1 name=$2 port=$3
  mkdir -p $BASE/$port
  # macOS does not allow mongod --fork, so each process runs detached in the background
  nohup mongod $role --replSet $name --port $port --bind_ip localhost --dbpath $BASE/$port \
        --wiredTigerCacheSizeGB 0.25 --logpath $BASE/$port.log > /dev/null 2>&1 &!
  up $port
  mongosh --quiet --port $port --eval "
    rs.initiate({ _id: '$name', configsvr: $( [ $role = --configsvr ] && echo true || echo false ),
                  members: [{ _id: 0, host: 'localhost:$port' }] });
    while (!db.hello().isWritablePrimary) sleep(200);"
  echo "started $name on $port"
}

start_member --configsvr ojahub-cfg 27030
start_member --shardsvr north 27031
start_member --shardsvr south 27032

nohup mongos --configdb ojahub-cfg/localhost:27030 --port 27040 --bind_ip localhost \
      --logpath $BASE/mongos.log > /dev/null 2>&1 &!
up 27040
echo "started mongos router on 27040"

mongosh --quiet --port 27040 --eval '
sh.addShard("north/localhost:27031");
sh.addShard("south/localhost:27032");
db.adminCommand({ listShards: 1 }).shards.forEach(s => print("  shard " + s._id + " at " + s.host));'
