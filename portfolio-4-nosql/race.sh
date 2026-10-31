#!/bin/zsh
# OjaHub Marketplace: ten buyers race for the last Standing Fan in MongoDB.
# Each buyer is a separate mongosh process. They all wait for the same start instant, then go.
# Run from inside portfolio-4-nosql.

buyers=10

race() {
  local style=$1
  mongosh --quiet ojahub --eval '
    db.products.updateOne({ _id: 14 }, { $set: { stock_qty: 1 } });
    db.race_orders.drop();' > /dev/null
  local start=$(( $(date +%s) * 1000 + 3000 ))
  local log=$(mktemp)

  for b in $(seq 1 $buyers); do
    mongosh --quiet ojahub --eval "
      const buyer = $b, start = $start;
      sleep(start - Date.now());
      if ('$style' === 'naive') {
        const p = db.products.findOne({ _id: 14 });
        sleep(200);
        if (p.stock_qty >= 1) {
          db.products.updateOne({ _id: 14 }, { \$set: { stock_qty: p.stock_qty - 1 } });
          db.race_orders.insertOne({ buyer, product_id: 14 });
          print('buyer ' + buyer + ': saw stock ' + p.stock_qty + ', bought');
        } else print('buyer ' + buyer + ': saw stock ' + p.stock_qty + ', sold out');
      } else {
        const p = db.products.findOneAndUpdate({ _id: 14, stock_qty: { \$gte: 1 } }, { \$inc: { stock_qty: -1 } });
        if (p) {
          db.race_orders.insertOne({ buyer, product_id: 14 });
          print('buyer ' + buyer + ': bought');
        } else print('buyer ' + buyer + ': sold out');
      }" >> $log &
  done
  wait
  sort -V $log
  rm -f $log

  mongosh --quiet ojahub --eval '
    print("Result: orders placed " + db.race_orders.countDocuments() + ", stock now " + db.products.findOne({ _id: 14 }).stock_qty + ", units that existed 1");'
}

echo "========== Naive: read the stock, decide in the app, write the new value back =========="
race naive
echo "\n========== Atomic: one findOneAndUpdate that checks stock_qty >= 1 and decrements together =========="
race atomic

mongosh --quiet ojahub --eval 'db.race_orders.drop(); db.products.updateOne({ _id: 14 }, { $set: { stock_qty: 1 } });' > /dev/null
