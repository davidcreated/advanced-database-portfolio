// OjaHub Marketplace: secondary indexes, then the same queries again
// Run from inside portfolio-4-nosql: mongosh --quiet mongo/02_indexes.js

load("mongo/queries.js");

db.orders.dropIndexes();
db.products.dropIndexes();

// Q3: a customer's orders, already sorted newest first inside the index
db.orders.createIndex({ "customer.customer_id": 1, ordered_at: -1 }, { name: "customer_history" });
// Q6: date range for the revenue report
db.orders.createIndex({ ordered_at: 1 }, { name: "ordered_at" });
// Q4 and Q7: equality on category, then price order for "cheapest first"
db.products.createIndex({ "category.id": 1, price: 1 }, { name: "category_price" });
// Q4: attributes differ per category, so a wildcard index covers every attribute without naming them
db.products.createIndex({ "attributes.$**": 1 }, { name: "attributes_wildcard" });
// Q5: word search on product names
db.products.createIndex({ name: "text" }, { name: "name_text" });

print("\n========== Index sizes ==========");
for (const c of ["orders", "products"]) {
  const s = db[c].stats();
  print(c + ": documents " + (s.size / 1048576).toFixed(1) + " MB in memory form, " +
        (s.storageSize / 1048576).toFixed(1) + " MB on disk compressed");
  for (const [name, bytes] of Object.entries(s.indexSizes)) print("  " + name + ": " + (bytes / 1048576).toFixed(1) + " MB");
}

print("\n========== Which index won for Q4, and what it beat ==========");
const q4 = QUERIES.find(q => q.no === 4).explain().queryPlanner;
const indexOf = p => JSON.stringify(p).match(/"indexName":"([^"]+)"/)?.[1] ?? "none";
print("winning: " + indexOf(q4.winningPlan));
q4.rejectedPlans.forEach(p => print("rejected: " + indexOf(p)));

report("After indexes (median of 6 warm runs)");
