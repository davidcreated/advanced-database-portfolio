#!/bin/zsh
# OjaHub Marketplace: kill the replica set primary mid traffic and measure the outage.
# Run after setup.sh.
BASE=~/ojahub-cluster/rs
RS="mongodb://localhost:27018,localhost:27019,localhost:27020/ojahub?replicaSet=ojahub-rs&serverSelectionTimeoutMS=2000"
LOG=$(mktemp)
now_ms() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000'; }

mongosh --quiet "$RS" --eval 'db.failover_test.drop()' > /dev/null
primary=$(mongosh --quiet "$RS" --eval 'print(db.hello().primary)')
echo "========== 1. Order traffic starts: one majority write every 100 ms for 30 s =========="
echo "  primary is $primary"

mongosh --quiet "$RS" --eval '
  const end = Date.now() + 30000;
  for (let i = 1; Date.now() < end; i++) {
    const s = Date.now();
    try {
      db.failover_test.insertOne({ _id: i, at: new Date() }, { writeConcern: { w: "majority", wtimeout: 2000 } });
      print(JSON.stringify({ i, start: s, end: Date.now(), ok: true, primary: db.hello().primary }));
    } catch (e) {
      print(JSON.stringify({ i, start: s, end: Date.now(), ok: false, error: e.codeName || e.name }));
    }
    sleep(100);
  }' > $LOG 2>&1 &
writer=$!

sleep 4
port=${primary##*:}
pid=$(lsof -nP -iTCP:$port -sTCP:LISTEN -t | head -1)
killed_at=$(now_ms)
kill -9 $pid
echo "\n========== 2. The primary process on $port is killed with kill -9 (a crash, not a clean shutdown) =========="
wait $writer

echo "\n========== 3. What the order traffic experienced =========="
python3 - "$LOG" "$killed_at" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.startswith("{")]
killed = int(sys.argv[2])
ok = [r for r in rows if r["ok"]]
failed = [r for r in rows if not r["ok"]]
before = [r for r in ok if r["end"] <= killed]
after = [r for r in ok if r["start"] > killed or r["end"] > killed]
last_before = before[-1]["end"] if before else killed
first_after = min(r["end"] for r in after)
print(f"  attempts {len(rows)}, acknowledged {len(ok)}, failed {len(failed)}" +
      (f" ({', '.join(sorted(set(r['error'] for r in failed)))})" if failed else ""))
print(f"  last write acknowledged by the old primary: {last_before - killed} ms relative to the kill")
print(f"  first write acknowledged after the kill:    {first_after - killed} ms after the kill")
print(f"  writes were unavailable for about {(first_after - last_before) / 1000:.1f} s")
print(f"  new primary: {after[-1]['primary']}")
json.dump([r["i"] for r in ok], open(sys.argv[1] + ".acked", "w"))
PY

echo "\n========== 4. Was any acknowledged order lost? =========="
mongosh --quiet "$RS" --eval "
  const acked = JSON.parse(fs.readFileSync('$LOG.acked', 'utf8'));
  const found = db.failover_test.countDocuments({ _id: { \$in: acked } }, { readConcern: { level: 'majority' } });
  print('  acknowledged ' + acked.length + ', present on the new primary ' + found + ', lost ' + (acked.length - found));"

echo "\n========== 5. The old primary is restarted and rejoins =========="
nohup mongod --replSet ojahub-rs --port $port --bind_ip localhost --dbpath $BASE/$port \
      --wiredTigerCacheSizeGB 0.25 --logpath $BASE/$port.log --logappend > /dev/null 2>&1 &!
restarted_at=$(now_ms)
last=""
for s in $(seq 1 60); do
  states=$(mongosh --quiet "mongodb://localhost:27019,localhost:27020/?replicaSet=ojahub-rs" --eval \
    'print(rs.status().members.map(m => m.name.split(":")[1] + " " + m.stateStr).join(", "))' 2> /dev/null)
  if [ -n "$states" ] && [ "$states" != "$last" ]; then
    echo "  +$(( ($(now_ms) - restarted_at) / 1000 ))s  $states"
    last=$states
  fi
  [[ "$states" == *"$port PRIMARY"* ]] && break
  sleep 1
done
echo "  27018 has the highest priority, so once it has caught up it takes the primary role back"

mongosh --quiet "$RS" --eval 'db.failover_test.drop()' > /dev/null
rm -f $LOG $LOG.acked
