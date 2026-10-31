// OjaHub Marketplace: a multi document transaction, which a replica set allows and a single server did not.
// Closes the gap from Portfolio 4: the review and the product's rating summary now change together or not at all.
// Run: mongosh --quiet --nodb 03_transaction.js

const RS = "mongodb://localhost:27018,localhost:27019,localhost:27020/ojahub?replicaSet=ojahub-rs";
// Connect to the replica set explicitly, so this can never run against the standalone 27017 server by mistake
db = new Mongo(RS).getDB("ojahub");
if (db.hello().setName !== "ojahub-rs") throw new Error("not connected to the ojahub-rs replica set");
const outsider = new Mongo(RS).getDB("ojahub");
const summary = (d) => JSON.stringify(d.products.findOne({ _id: 1 }, { _id: 0, rating: 1 }).rating) +
                       ", test reviews: " + d.reviews.countDocuments({ _id: { $gte: 900000 } });
const savedProduct = db.products.findOne({ _id: 1 });

function addReview(sdb, id, rating, comment) {
  sdb.reviews.insertOne({ _id: id, product_id: 1, customer_id: 3, rating, comment, reviewed_at: new Date("2026-10-31T17:00:00Z") });
  sdb.products.updateOne({ _id: 1 }, [{ $set: {
    "rating.average": { $round: [{ $divide: [{ $add: [{ $multiply: ["$rating.average", "$rating.count"] }, rating] },
                                             { $add: ["$rating.count", 1] }] }, 2] },
    "rating.count": { $add: ["$rating.count", 1] } } }]);
}

try {
  print("========== A. Review and rating summary committed together ==========");
  print("before:              " + summary(db));
  const s1 = db.getMongo().startSession();
  s1.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
  addReview(s1.getDatabase("ojahub"), 900001, 3, "Battery is fine but it heats up when charging.");
  print("inside, uncommitted: " + summary(s1.getDatabase("ojahub")));
  print("seen by others now:  " + summary(outsider));
  s1.commitTransaction();
  s1.endSession();
  print("after commit:        " + summary(db));

  print("\n========== B. A transaction that fails halfway is rolled back completely ==========");
  const s2 = db.getMongo().startSession();
  s2.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
  addReview(s2.getDatabase("ojahub"), 900002, 1, "Never arrived.");
  print("inside, uncommitted: " + summary(s2.getDatabase("ojahub")));
  print("the app then finds the reviewer never received this product, so it aborts");
  s2.abortTransaction();
  s2.endSession();
  print("after abort:         " + summary(db));
  print("review 900002 exists: " + (db.reviews.countDocuments({ _id: 900002 }) === 1));
} finally {
  db.reviews.deleteMany({ _id: { $gte: 900000 } }, { writeConcern: { w: "majority" } });
  db.products.replaceOne({ _id: 1 }, savedProduct, { writeConcern: { w: "majority" } });
  print("\nRestored: test reviews removed and product 1 put back as it was: " + summary(db));
}
