// OjaHub Marketplace: orders sharded by region, with zones pinning each half of the country to one shard.
// Run by 01_zones.sh against the router on 27040.
// Region names sort as North Central < North East < North West < South East < South South < South West,
// so one boundary at "South East" splits the country in two.

db = db.getSiblingDB("ojahub");
db.orders.drop();

sh.addShardToZone("north", "NORTH");
sh.addShardToZone("south", "SOUTH");
sh.updateZoneKeyRange("ojahub.orders",
  { "shipping_address.region": MinKey, _id: MinKey }, { "shipping_address.region": "South East", _id: MinKey }, "NORTH");
sh.updateZoneKeyRange("ojahub.orders",
  { "shipping_address.region": "South East", _id: MinKey }, { "shipping_address.region": MaxKey, _id: MaxKey }, "SOUTH");

// Sharding the collection while it is still empty lets MongoDB create its first chunks on the zone boundaries
sh.shardCollection("ojahub.orders", { "shipping_address.region": 1, _id: 1 });
db.orders.createIndex({ "customer.customer_id": 1, ordered_at: -1 }, { name: "customer_history" });
db.orders.createIndex({ ordered_at: 1 }, { name: "ordered_at" });

const bound = (k) => {
  const v = k["shipping_address.region"];
  return typeof v === "string" ? JSON.stringify(v) : (v._bsontype === "MinKey" ? "the lowest key" : "the highest key");
};
print("========== Zones ==========");
db.getSiblingDB("config").tags.find({ ns: "ojahub.orders" }).sort({ min: 1 }).forEach(t =>
  print("  " + t.tag + ": regions from " + bound(t.min) + " up to (not including) " + bound(t.max)));
