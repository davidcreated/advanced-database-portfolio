#!/bin/zsh
# Confirms MongoDB holds exactly what PostgreSQL holds, then saves one real document per collection.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH

echo "Document counts, PostgreSQL rows against MongoDB documents:"
for c in categories products customers orders reviews; do
  pg=$(psql -d ojahub -XAtc "SELECT count(*) FROM ojahub.$c")
  mg=$(mongosh --quiet ojahub --eval "db.$c.countDocuments()")
  [ "$pg" = "$mg" ] && verdict=match || verdict=DIFFERENT
  printf "  %-11s %8s %8s  %s\n" $c $pg $mg $verdict
done

echo "\nSpot check of three orders (total and number of items):"
for id in 2 245678 500010; do
  pg=$(psql -d ojahub -XAtc "SELECT sum(quantity * unit_price) || ' / ' || count(*) FROM ojahub.order_items WHERE order_id = $id")
  mg=$(mongosh --quiet ojahub --eval "const o = db.orders.findOne({_id: $id}); print(o.total + ' / ' + o.items.length)")
  [ "$pg" = "$mg" ] && verdict=match || verdict=DIFFERENT
  printf "  order %-7s PostgreSQL %-16s MongoDB %-16s %s\n" $id "$pg" "$mg" $verdict
done

mkdir -p sample-documents
mongosh --quiet ojahub --eval '
const samples = {
  "category.json": db.categories.findOne({_id: 2}),
  "product.json": db.products.findOne({_id: 1}),
  "customer.json": db.customers.findOne({_id: 1}),
  "order.json": db.orders.findOne({_id: 2}),
  "review.json": db.reviews.findOne({_id: 1})
};
for (const [file, doc] of Object.entries(samples)) {
  fs.writeFileSync("sample-documents/" + file, EJSON.stringify(doc, null, 2, { relaxed: true }) + "\n");
}
print("\nSaved sample documents: " + Object.keys(samples).join(", "));'
