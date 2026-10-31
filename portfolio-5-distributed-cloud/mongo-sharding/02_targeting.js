// OjaHub Marketplace: how the mongos router sends queries to shards
// Run: mongosh --quiet --port 27040 02_targeting.js

db = db.getSiblingDB("ojahub");
const quarter = { $gte: ISODate("2026-07-31T23:00:00Z"), $lt: ISODate("2026-10-31T23:00:00Z") };
const revenue = (match) => [
  { $match: match },
  { $group: { _id: "$shipping_address.region", orders: { $sum: 1 }, revenue: { $sum: "$total" } } },
  { $sort: { _id: 1 } }
];

const queries = [
  { label: "Pending orders in North West", has_key: "yes, region",
    run: () => db.orders.find({ "shipping_address.region": "North West", status: "pending" }).toArray(),
    explain: () => db.orders.find({ "shipping_address.region": "North West", status: "pending" }).explain("executionStats") },
  { label: "One order by region and _id", has_key: "yes, full key",
    run: () => db.orders.find({ "shipping_address.region": "North East", _id: 245678 }).toArray(),
    explain: () => db.orders.find({ "shipping_address.region": "North East", _id: 245678 }).explain("executionStats") },
  { label: "Order history for customer 4821", has_key: "no",
    run: () => db.orders.find({ "customer.customer_id": 4821 }).sort({ ordered_at: -1 }).limit(20).toArray(),
    explain: () => db.orders.find({ "customer.customer_id": 4821 }).sort({ ordered_at: -1 }).limit(20).explain("executionStats") },
  { label: "Revenue by region, last quarter", has_key: "no",
    run: () => db.orders.aggregate(revenue({ ordered_at: quarter })).toArray(),
    explain: () => db.orders.explain("executionStats").aggregate(revenue({ ordered_at: quarter })) },
  { label: "Revenue for South West only, last quarter", has_key: "yes, region",
    run: () => db.orders.aggregate(revenue({ "shipping_address.region": "South West", ordered_at: quarter })).toArray(),
    explain: () => db.orders.explain("executionStats").aggregate(revenue({ "shipping_address.region": "South West", ordered_at: quarter })) }
];

// Finds which shards answered and how many documents each one examined, for both find and aggregate explains
function shardStats(ex) {
  const perShard = {};
  const firstDocs = (o) => {
    if (!o || typeof o !== "object") return undefined;
    if (typeof o.totalDocsExamined === "number") return o.totalDocsExamined;
    for (const v of Object.values(o)) { const n = firstDocs(v); if (n !== undefined) return n; }
    return undefined;
  };
  if (ex.shards && !Array.isArray(ex.shards)) {
    for (const [name, s] of Object.entries(ex.shards)) perShard[name] = firstDocs(s);
  } else {
    const shards = ex.executionStats.executionStages.shards;
    shards.forEach(s => { perShard[s.shardName] = s.totalDocsExamined; });
  }
  const stage = ex.queryPlanner ? ex.queryPlanner.winningPlan.stage : (ex.mergeType ? "merged on " + ex.mergeType : "one shard, no merge");
  return { perShard, stage };
}

function median(fn) {
  fn();
  const t = [];
  for (let i = 0; i < 6; i++) { const s = performance.now(); fn(); t.push(performance.now() - s); }
  t.sort((a, b) => a - b);
  return ((t[2] + t[3]) / 2).toFixed(2);
}

print("Customer 4821 lives in the South East, and order 245678 shipped to the North East.\n");
print("query | shard key in filter | shards asked | docs examined per shard | router stage | median ms");
for (const q of queries) {
  const s = shardStats(q.explain());
  const asked = Object.keys(s.perShard);
  print([q.label, q.has_key, asked.length + " (" + asked.join(", ") + ")",
         asked.map(n => n + " " + s.perShard[n]).join(", "), s.stage, median(q.run)].join(" | "));
}
