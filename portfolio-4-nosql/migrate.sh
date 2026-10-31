#!/bin/zsh
# Moves OjaHub from PostgreSQL into MongoDB: export each collection as JSON lines, then import.
# Run from inside portfolio-4-nosql. The exported files go to data/, which is not committed.
set -e
export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH
mkdir -p data

for c in categories products customers orders reviews; do
  f=$(ls export/*_$c.sql)
  start=$(date +%s)
  psql -d ojahub -X -q -At -v ON_ERROR_STOP=1 -v FETCH_COUNT=20000 -f $f > data/$c.json
  echo "exported $c: $(wc -l < data/$c.json | tr -d ' ') documents in $(( $(date +%s) - start ))s"
done

mongosh --quiet mongo/00_collections.js

for c in categories products customers orders reviews; do
  mongoimport --quiet --db ojahub --collection $c --file data/$c.json --numInsertionWorkers 4 --stopOnError
  echo "imported $c"
done
