#!/bin/zsh
# OjaHub Marketplace: define the zones, load every order through the router, and see where each one landed.
# Run from inside mongo-sharding after setup.sh.

mongosh --quiet --port 27040 zones.js

echo "\n========== Loading all orders through the mongos router =========="
start=$(date +%s)
mongodump --quiet --uri mongodb://localhost:27017/ojahub --collection orders --db ojahub --archive |
  mongorestore --quiet --uri mongodb://localhost:27040 --archive --nsInclude ojahub.orders
echo "  loaded $(mongosh --quiet --port 27040 ojahub --eval 'db.orders.countDocuments()') orders in $(( $(date +%s) - start ))s"

echo "\n========== Which shard holds which regions (asked of each shard directly) =========="
for shard in north:27031 south:27032; do
  mongosh --quiet --port ${shard#*:} ojahub --eval "
    const rows = db.orders.aggregate([{ \$group: { _id: '\$shipping_address.region', n: { \$sum: 1 } } }, { \$sort: { _id: 1 } }]).toArray();
    const total = rows.reduce((a, r) => a + r.n, 0);
    print('  ${shard%%:*} shard (${shard#*:}): ' + total + ' orders');
    rows.forEach(r => print('    ' + r._id.padEnd(14) + r.n));"
done

echo "\n========== Chunk placement from the router's point of view =========="
mongosh --quiet --port 27040 --eval '
const c = db.getSiblingDB("config");
const uuid = c.collections.findOne({ _id: "ojahub.orders" }).uuid;
c.chunks.aggregate([{ $match: { uuid } }, { $group: { _id: "$shard", chunks: { $sum: 1 } } }, { $sort: { _id: 1 } }])
  .forEach(r => print("  " + r._id + ": " + r.chunks + " chunk(s)"));'
