#!/bin/zsh
# OjaHub Marketplace: a three member MongoDB replica set on ports 27018, 27019 and 27020.
# Member files live outside the repo in ~/ojahub-cluster/rs. Products, reviews and orders are
# copied in from the main 27017 database.
set -e
BASE=~/ojahub-cluster/rs
RS="mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojahub-rs"

for port in 27018 27019 27020; do
  mkdir -p $BASE/$port
  # macOS does not allow mongod --fork, so each member runs in the background, detached from this shell
  nohup mongod --replSet ojahub-rs --port $port --bind_ip localhost --dbpath $BASE/$port \
        --wiredTigerCacheSizeGB 0.25 --logpath $BASE/$port.log > /dev/null 2>&1 &!
  until mongosh --quiet --port $port --eval "db.runCommand({ ping: 1 }).ok" > /dev/null 2>&1; do sleep 0.3; done
  echo "started member on $port"
done

mongosh --quiet --port 27018 --eval '
rs.initiate({ _id: "ojahub-rs", members: [
  { _id: 0, host: "localhost:27018", priority: 2 },
  { _id: 1, host: "localhost:27019", priority: 1 },
  { _id: 2, host: "localhost:27020", priority: 1 } ] });
while (!db.hello().isWritablePrimary) sleep(200);
print("replica set ojahub-rs initiated, primary is " + db.hello().primary);'

echo "copying products, reviews and orders from the 27017 database..."
start=$(date +%s)
mongodump --quiet --uri mongodb://localhost:27017/ojahub --archive \
          --collection products --db ojahub > $BASE/products.archive
mongodump --quiet --uri mongodb://localhost:27017/ojahub --archive \
          --collection reviews --db ojahub > $BASE/reviews.archive
mongodump --quiet --uri mongodb://localhost:27017/ojahub --archive \
          --collection orders --db ojahub > $BASE/orders.archive
for c in products reviews orders; do
  mongorestore --quiet --uri "$RS" --archive=$BASE/$c.archive --writeConcern '{w: "majority"}'
done
rm -f $BASE/*.archive
echo "copied in $(( $(date +%s) - start ))s"

mongosh --quiet "$RS" --eval '
const st = rs.status();
st.members.forEach(m => print("  " + m.name + "  " + m.stateStr + "  health " + m.health));
const o = db.getSiblingDB("ojahub");
print("documents: products " + o.products.countDocuments() + ", reviews " + o.reviews.countDocuments() + ", orders " + o.orders.countDocuments());'
