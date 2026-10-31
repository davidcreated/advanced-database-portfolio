#!/bin/zsh
# OjaHub Marketplace: the same four questions answered by PostgreSQL and by MongoDB.
# Both are timed from the client (psql \timing and mongosh wall clock), median of 6 warm runs.
# Run from inside portfolio-4-nosql after Portfolio 2's indexes and this portfolio's indexes exist.
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH

pg_median() {
  local sql=$1
  { printf '%s\n' 'SET search_path TO ojahub;' '\timing on' '\o /dev/null'; for i in 1 2 3 4 5 6 7; do printf '%s;\n' "$sql"; done; } |
    psql -d ojahub -X -q -f - 2>&1 |
    awk '/^Time:/ {print $2}' | tail -6 | sort -n | awk '{a[NR]=$1} END {printf "%.2f", (a[3]+a[4])/2}'
}

mongo_median() {
  mongosh --quiet ojahub --eval "load('mongo/queries.js'); print(medianMs(() => { $1 }).toFixed(2))"
}

typeset -A pg mongo label
label[1]="Order page (order 245678 with items, payments, shipment)"
pg[1]="SELECT o.order_id, o.order_status, c.first_name, c.last_name, a.street, a.city, s.state_name, oi.product_id, p.product_name, oi.quantity, oi.unit_price, pay.payment_method, pay.payment_status, sh.courier, sh.shipment_status FROM orders o JOIN customers c ON c.customer_id = o.customer_id JOIN addresses a ON a.address_id = o.shipping_address_id JOIN states s ON s.state_id = a.state_id JOIN order_items oi ON oi.order_id = o.order_id JOIN products p ON p.product_id = oi.product_id LEFT JOIN payments pay ON pay.order_id = o.order_id LEFT JOIN shipments sh ON sh.order_id = o.order_id WHERE o.order_id = 245678"
mongo[1]="db.orders.findOne({ _id: 245678 })"

label[2]="Order history for customer 4821"
pg[2]="SELECT o.order_id, o.ordered_at, o.order_status, sum(oi.quantity * oi.unit_price) FROM orders o JOIN order_items oi USING (order_id) WHERE o.customer_id = 4821 GROUP BY o.order_id ORDER BY o.ordered_at DESC LIMIT 20"
mongo[2]="db.orders.find({ 'customer.customer_id': 4821 }, { ordered_at: 1, status: 1, total: 1 }).sort({ ordered_at: -1 }).limit(20).toArray()"

label[3]="Monthly revenue by region, last quarter"
pg[3]="SELECT date_trunc('month', o.ordered_at) AS month, s.region, count(DISTINCT o.order_id), sum(oi.quantity * oi.unit_price) FROM orders o JOIN addresses a ON a.address_id = o.shipping_address_id JOIN states s ON s.state_id = a.state_id JOIN order_items oi ON oi.order_id = o.order_id WHERE o.ordered_at >= timestamptz '2026-08-01 00:00+01' AND o.ordered_at < timestamptz '2026-11-01 00:00+01' AND o.order_status <> 'cancelled' GROUP BY 1, 2 ORDER BY 1, 2"
mongo[3]="db.orders.aggregate(REVENUE_PIPELINE).toArray()"

label[4]="Search: names containing basmati"
pg[4]="SELECT product_id, product_name, unit_price FROM products WHERE product_name ILIKE '%basmati%'"
mongo[4]="db.products.find({ \$text: { \$search: 'basmati' } }, { name: 1, price: 1 }).toArray()"

echo "========== Same question, both databases (client side median ms of 6 warm runs) =========="
printf "%-58s %12s %10s\n" "Question" "PostgreSQL" "MongoDB"
for i in 1 2 3 4; do
  printf "%-58s %12s %10s\n" "${label[$i]}" "$(pg_median "${pg[$i]}")" "$(mongo_median "${mongo[$i]}")"
done

echo "\n========== Storage for the whole OjaHub dataset =========="
psql -d ojahub -XAt -c "SELECT format('PostgreSQL tables:  %s MB data, %s MB indexes',
    round(sum(pg_table_size(c.oid)) / 1048576.0, 1), round(sum(pg_indexes_size(c.oid)) / 1048576.0, 1))
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'ojahub' AND c.relkind = 'r'"
mongosh --quiet ojahub --eval '
const s = db.stats();
print("MongoDB collections: " + (s.storageSize / 1048576).toFixed(1) + " MB data on disk (compressed), " +
      (s.indexSize / 1048576).toFixed(1) + " MB indexes, " + (s.dataSize / 1048576).toFixed(1) + " MB data before compression");'
