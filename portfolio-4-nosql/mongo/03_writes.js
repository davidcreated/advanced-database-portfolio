// OjaHub Marketplace: writing to the document model
// Run from inside portfolio-4-nosql: mongosh --quiet mongo/03_writes.js
// Everything changed here is put back at the end, even if a step fails.

db = db.getSiblingDB("ojahub");
const show = (label, doc) => print(label + " " + EJSON.stringify(doc, { relaxed: true }));
const savedProduct = db.products.findOne({ _id: 1 });

try {

print("========== A. A new review updates the product's rating summary in one atomic step ==========");
show("before:", db.products.findOne({ _id: 1 }, { _id: 0, rating: 1, "latest_reviews.customer": 1 }));

const review = { _id: 900001, product_id: 1, customer_id: 3, rating: 3,
                 comment: "Battery is fine but it heats up when charging.", reviewed_at: ISODate("2026-10-31T17:00:00Z") };
db.reviews.insertOne(review);

// One update, evaluated on the server against the current document, so no other writer can slip in between
db.products.updateOne({ _id: 1 }, [{ $set: {
  "rating.average": { $round: [{ $divide: [
      { $add: [{ $multiply: [{ $ifNull: ["$rating.average", 0] }, "$rating.count"] }, review.rating] },
      { $add: ["$rating.count", 1] }] }, 2] },
  "rating.count": { $add: ["$rating.count", 1] },
  latest_reviews: { $slice: [{ $concatArrays: [[{ customer: "Funmilayo", rating: review.rating, comment: review.comment,
                                                  reviewed_at: review.reviewed_at }], "$latest_reviews"] }, 3] }
} }]);
show("after: ", db.products.findOne({ _id: 1 }, { _id: 0, rating: 1, "latest_reviews.customer": 1 }));
print("The review insert and the product update are two writes. Without a replica set there is no multi document");
print("transaction, so a crash between them would leave the summary one review behind until it is recalculated.");

print("\n========== B. The validators reject bad documents ==========");
function attempt(label, fn) {
  try { fn(); print(label + "  =>  accepted"); }
  catch (e) {
    // Written out longhand: mongosh's async rewriting breaks an optional chained .map() inside a catch
    const rule = e.errInfo && e.errInfo.details ? e.errInfo.details.schemaRulesNotSatisfied[0] : null;
    let fields = [];
    if (rule && rule.propertiesNotSatisfied) fields = rule.propertiesNotSatisfied.map(p => p.propertyName);
    else if (rule && rule.missingProperties) fields = rule.missingProperties;
    const name = e.code === 121 ? "DocumentValidationFailure" : (e.codeName || "");
    print(label + "  =>  rejected, code " + e.code + " (" + name + ") on " + fields.join(", "));
  }
}
const goodOrder = db.orders.findOne({ _id: 2 });
attempt("order with status 'lost'", () => db.orders.insertOne({ ...goodOrder, _id: 900001, status: "lost" }));
attempt("order with no items", () => db.orders.insertOne({ ...goodOrder, _id: 900002, items: [] }));
attempt("order with a zero quantity item", () => db.orders.insertOne({ ...goodOrder, _id: 900003,
  items: [{ ...goodOrder.items[0], quantity: 0 }] }));
attempt("product stock set to -1", () => db.products.updateOne({ _id: 14 }, { $set: { stock_qty: -1 } }));
attempt("customer with a local phone format", () => db.customers.insertOne({ _id: 900001, first_name: "Kemi",
  last_name: "Ajayi", email: "kemi.ajayi@example.ng", phone: "08031234567", addresses: [{ city: "Ibadan" }] }));
attempt("review rated 6", () => db.reviews.insertOne({ ...review, _id: 900002, rating: 6 }));
attempt("a valid order (control)", () => db.orders.insertOne({ ...goodOrder, _id: 900004 }));

print("\n========== C. The price of copying data: a seller renames their business ==========");
const before = db.products.countDocuments({ "seller.business_name": "Lagos Gadget Hub" });
const r = db.products.updateMany({ "seller.seller_id": 2 }, { $set: { "seller.business_name": "Lagos Gadget Hub Ltd" } });
print("In PostgreSQL this is one UPDATE to one sellers row. Here every product carrying the seller summary must change:");
print("products updated: " + r.modifiedCount + " (products showing the old name before: " + before + ")");
print("Orders are deliberately left alone: they keep the product names and prices from the day they were placed.");

} finally {
  print("\n========== Putting everything back ==========");
  db.reviews.deleteMany({ _id: { $gte: 900000 } });
  db.orders.deleteMany({ _id: { $gte: 900000 } });
  db.customers.deleteMany({ _id: { $gte: 900000 } });
  db.products.replaceOne({ _id: 1 }, savedProduct);
  db.products.updateMany({ "seller.seller_id": 2 }, { $set: { "seller.business_name": "Lagos Gadget Hub" } });
  print("restored: test review and orders removed, product 1 and the seller name back as they were");
}
