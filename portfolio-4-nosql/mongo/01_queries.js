// OjaHub Marketplace: query results and plans before any secondary indexes
// Run from inside portfolio-4-nosql: mongosh --quiet mongo/01_queries.js

load("mongo/queries.js");

for (const q of QUERIES) {
  print("\n== Q" + q.no + ": " + q.question + " ==");
  q.run().forEach(r => print(EJSON.stringify(r, { relaxed: true })));
}

report("Before indexes (median of 6 warm runs)");
