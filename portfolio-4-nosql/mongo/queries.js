// OjaHub Marketplace: the MongoDB queries, defined once and loaded by the before and after scripts

db = db.getSiblingDB("ojahub");

const lastQuarter = { $gte: ISODate("2026-07-31T23:00:00Z"), $lt: ISODate("2026-10-31T23:00:00Z") };

globalThis.QUERIES = [
  {
    no: 1, question: "Product page for product 1, with seller, rating and latest reviews",
    run: () => [db.products.findOne({ _id: 1 }, { name: 1, price: 1, seller: 1, rating: 1, "latest_reviews.rating": 1 })],
    explain: () => db.products.find({ _id: 1 }).explain("executionStats")
  },
  {
    no: 2, question: "Order page for order 245678, with items, payments and shipment",
    run: () => [db.orders.findOne({ _id: 245678 }, { status: 1, total: 1, "items.name": 1, "payments.status": 1, "shipment.status": 1 })],
    explain: () => db.orders.find({ _id: 245678 }).explain("executionStats")
  },
  {
    no: 3, question: "Order history for customer 4821, newest first",
    run: () => db.orders.find({ "customer.customer_id": 4821 }, { ordered_at: 1, status: 1, total: 1 })
                        .sort({ ordered_at: -1 }).limit(20).toArray(),
    explain: () => db.orders.find({ "customer.customer_id": 4821 }).sort({ ordered_at: -1 }).limit(20).explain("executionStats")
  },
  {
    no: 4, question: "Active phones with at least 8GB RAM and 256GB storage, cheapest first",
    run: () => db.products.find({ "category.id": 2, "attributes.ram_gb": { $gte: 8 }, "attributes.storage_gb": 256, is_active: true },
                                { name: 1, price: 1, attributes: 1 }).sort({ price: 1 }).limit(5).toArray(),
    explain: () => db.products.find({ "category.id": 2, "attributes.ram_gb": { $gte: 8 }, "attributes.storage_gb": 256, is_active: true })
                              .sort({ price: 1 }).limit(5).explain("executionStats")
  },
  {
    no: 5, question: "Search: products whose name contains basmati",
    run: () => [{ matches: db.products.countDocuments(globalThis.SEARCH()) }],
    explain: () => db.products.find(globalThis.SEARCH()).explain("executionStats")
  },
  {
    no: 6, question: "Monthly revenue by region for the last quarter (aggregation pipeline)",
    run: () => db.orders.aggregate(globalThis.REVENUE_PIPELINE).toArray().slice(0, 6),
    explain: () => db.orders.explain("executionStats").aggregate(globalThis.REVENUE_PIPELINE)
  },
  {
    no: 7, question: "Graph traversal: every category under Electronics and how many products they hold ($graphLookup)",
    run: () => db.categories.aggregate(globalThis.CATEGORY_TREE).toArray(),
    explain: () => db.categories.explain("executionStats").aggregate(globalThis.CATEGORY_TREE)
  }
];

// Before the text index exists, search has to use a case insensitive regex. After, it uses $text.
globalThis.SEARCH = () => db.products.getIndexes().some(i => i.name === "name_text")
  ? { $text: { $search: "basmati" } }
  : { name: /basmati/i };

globalThis.REVENUE_PIPELINE = [
  { $match: { ordered_at: lastQuarter, status: { $ne: "cancelled" } } },
  { $group: {
      _id: { month: { $dateTrunc: { date: "$ordered_at", unit: "month", timezone: "Africa/Lagos" } },
             region: "$shipping_address.region" },
      orders: { $sum: 1 }, revenue: { $sum: "$total" } } },
  { $sort: { "_id.month": 1, "_id.region": 1 } }
];

globalThis.CATEGORY_TREE = [
  { $match: { name: "Electronics" } },
  { $graphLookup: { from: "categories", startWith: "$_id", connectFromField: "_id",
                    connectToField: "parent_id", as: "subcategories", depthField: "depth" } },
  { $unwind: "$subcategories" },
  { $lookup: { from: "products", localField: "subcategories._id", foreignField: "category.id",
               as: "products", pipeline: [{ $count: "n" }] } },
  { $project: { _id: 0, parent: "$name", subcategory: "$subcategories.name", depth: "$subcategories.depth",
                products: { $ifNull: [{ $first: "$products.n" }, 0] } } },
  { $sort: { subcategory: 1 } }
];

// Pulls the useful numbers out of an explain, whichever shape it comes back in
globalThis.summarise = (ex) => {
  const stages = new Set(); let stats = null;
  const walk = (o, inPlan) => {
    if (!o || typeof o !== "object") return;
    if (Array.isArray(o)) return o.forEach(x => walk(x, inPlan));
    for (const [k, v] of Object.entries(o)) {
      if (k === "rejectedPlans" || k === "allPlansExecution") continue;
      if (k === "executionStats" && !stats) stats = v;
      if (k === "stage" && inPlan && typeof v === "string") stages.add(v);
      walk(v, inPlan || k === "winningPlan" || k === "queryPlan");
    }
  };
  walk(ex, false);
  if (ex.stages) ex.stages.forEach(s => stages.add(Object.keys(s)[0]));
  return { plan: [...stages].join(" > "), keysExamined: stats?.totalKeysExamined, docsExamined: stats?.totalDocsExamined };
};

globalThis.medianMs = (fn, runs = 7) => {
  fn();
  const t = [];
  for (let i = 0; i < runs - 1; i++) { const s = performance.now(); fn(); t.push(performance.now() - s); }
  t.sort((a, b) => a - b);
  return Math.round(t[Math.floor(t.length / 2)] * 100) / 100;
};

globalThis.report = (label) => {
  print("\n========== " + label + " ==========");
  print("q | median ms | plan | keys examined | docs examined");
  for (const q of QUERIES) {
    const s = summarise(q.explain());
    print([q.no, medianMs(q.run), s.plan, s.keysExamined ?? "", s.docsExamined ?? ""].join(" | "));
  }
};
