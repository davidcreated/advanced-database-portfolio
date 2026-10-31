-- OjaHub Marketplace: write skew, a rule that spans two rows
-- Rule: a seller must keep at least one active listing in every category they sell in.
-- Lagos Gadget Hub (seller 2) has exactly two Home and Kitchen listings. Two staff members each
-- deactivate a different one, and each first checks that the other one is still active.

\set QUIET on
\pset tuples_only on
\pset format unaligned
SET search_path TO ojahub;

\set check_rule 'SELECT count(*) AS active_home_listings FROM products WHERE seller_id = 2 AND category_id = 8 AND is_active'

SELECT txdemo.reset();
SELECT format('Listing %s: %s (active: %s)', product_id, product_name, is_active)
FROM products WHERE product_id IN (90354, 92355) ORDER BY product_id;

SELECT txdemo.open('staff_1');
SELECT txdemo.open('staff_2');

\echo '\n========== REPEATABLE READ =========='
SELECT txdemo.step('staff_1', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('staff_2', 'BEGIN ISOLATION LEVEL REPEATABLE READ');
SELECT txdemo.step('staff_1', :'check_rule');
SELECT txdemo.step('staff_2', :'check_rule');
\echo '# Both see 2, so both decide it is safe to switch one off. They touch different rows, so nobody waits.'
SELECT txdemo.step('staff_1', 'UPDATE products SET is_active = false WHERE product_id = 90354');
SELECT txdemo.step('staff_2', 'UPDATE products SET is_active = false WHERE product_id = 92355');
SELECT txdemo.step('staff_1', 'COMMIT');
SELECT txdemo.step('staff_2', 'COMMIT');
SELECT format('Result: active Home and Kitchen listings for Lagos Gadget Hub = %s (the rule needs at least 1)',
              count(*)) FROM products WHERE seller_id = 2 AND category_id = 8 AND is_active;

\echo '\n========== SERIALIZABLE =========='
SELECT txdemo.reset();
SELECT txdemo.step('staff_1', 'BEGIN ISOLATION LEVEL SERIALIZABLE');
SELECT txdemo.step('staff_2', 'BEGIN ISOLATION LEVEL SERIALIZABLE');
SELECT txdemo.step('staff_1', :'check_rule');
SELECT txdemo.step('staff_2', :'check_rule');
SELECT txdemo.step('staff_1', 'UPDATE products SET is_active = false WHERE product_id = 90354');
SELECT txdemo.step('staff_2', 'UPDATE products SET is_active = false WHERE product_id = 92355');
SELECT txdemo.step('staff_1', 'COMMIT');
SELECT txdemo.step('staff_2', 'COMMIT');
\echo '# Staff 2 retries in a new transaction, sees only 1 active listing left, and the app refuses'
SELECT txdemo.step('staff_2', 'BEGIN ISOLATION LEVEL SERIALIZABLE');
SELECT txdemo.step('staff_2', :'check_rule');
SELECT txdemo.step('staff_2', 'ROLLBACK');
SELECT format('Result: active Home and Kitchen listings for Lagos Gadget Hub = %s (the rule needs at least 1)',
              count(*)) FROM products WHERE seller_id = 2 AND category_id = 8 AND is_active;

SELECT txdemo.close_all();
SELECT txdemo.reset();
