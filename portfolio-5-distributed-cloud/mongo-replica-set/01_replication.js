// OjaHub Marketplace: replication, write concern and read consistency on the replica set
// Run: mongosh --quiet "mongodb://localhost:27018,localhost:27019,localhost:27020/ojahub?replicaSet=ojahub-rs" 01_replication.js

const RS = "mongodb://localhost:27018,localhost:27019,localhost:27020/ojahub?replicaSet=ojahub-rs";
db = db.getSiblingDB("ojahub");
const ms = (t) => (Math.round(t * 1000) / 1000).toFixed(3);

print("========== 1. Members and how far behind the primary they are ==========");
const st = rs.status();
const primaryOptime = st.members.find(m => m.stateStr === "PRIMARY").optimeDate;
st.members.forEach(m => print("  " + m.name + "  " + m.stateStr.padEnd(9) + "  behind primary: " + ((primaryOptime - m.optimeDate) / 1000) + "s"));

print("\n========== 2. Write concern: who has to confirm a write before it counts ==========");
db.consistency_test.drop();
db.consistency_test.insertOne({ _id: 1, v: 0 }, { writeConcern: { w: "majority" } });
const concerns = [{ w: 1 }, { w: 1, j: true }, { w: 3 }, { w: 3, j: true }, { w: "majority" }];
for (const wc of concerns) {
  const n = 300, s = performance.now();
  for (let i = 1; i <= n; i++) db.consistency_test.updateOne({ _id: 1 }, { $set: { v: i } }, { writeConcern: wc });
  print("  " + JSON.stringify(wc).padEnd(22) + " average " + ms((performance.now() - s) / n) + " ms per write");
}
print("  w: 1 = primary only, w: 3 = every member, majority = 2 of 3 members");
print("  j: true = wait until the write is in the on disk journal, not just applied in memory");
print("  majority writes are journaled by default, which is why they cost more than an unjournaled w: 3");

print("\n========== 3. Reading your own write from a secondary ==========");
const sec = new Mongo(RS + "&readPreference=secondary").getDB("ojahub");
const servedBy = sec.consistency_test.find({ _id: 1 }).explain().serverInfo;
print("  secondary reads are served by " + servedBy.host + ":" + servedBy.port);

let stale = 0;
for (let i = 1; i <= 300; i++) {
  db.consistency_test.updateOne({ _id: 1 }, { $set: { v: 1000 + i } }, { writeConcern: { w: 1 } });
  if (sec.consistency_test.findOne({ _id: 1 }).v !== 1000 + i) stale++;
}
print("  plain:  write to the primary with w: 1, read straight back from a secondary  ->  stale reads: " + stale + " of 300");

const session = new Mongo(RS + "&readPreference=secondary").startSession({ causalConsistency: true });
const sdb = session.getDatabase("ojahub");
let staleCausal = 0;
for (let i = 1; i <= 300; i++) {
  sdb.consistency_test.updateOne({ _id: 1 }, { $set: { v: 2000 + i } }, { writeConcern: { w: "majority" } });
  if (sdb.consistency_test.find({ _id: 1 }).readConcern("majority").next().v !== 2000 + i) staleCausal++;
}
session.endSession();
print("  causal: same loop inside a causally consistent session, majority write and read  ->  stale reads: " + staleCausal + " of 300");

db.consistency_test.drop();
print("\nTest collection dropped");
