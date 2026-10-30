# Normalisation of the OjaHub Data

I started from the kind of spreadsheet a small marketplace typically runs on before it gets a proper database, then worked it through each normal form until I reached the schema in `sql/01_schema.sql`.


## Starting Point: Unnormalised Order Sheet

Imagine every order recorded as one row in a sheet, with the products squeezed into the same row:

| order_no | date | customer | email | phone | address | state | region | products bought | payment | courier | tracking |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 02/09/2026 | Chiamaka Okeke | chiamaka.okeke@... | 0803... | 14 Adeola Odeku St, Victoria Island | Lagos | South West | Tecno Spark 20 (Lagos Gadget Hub, Phones, 189000 x1); Power Bank (Lagos Gadget Hub, Accessories, 18500 x2) | card, successful | GIG Logistics | GIG77300... |
| 2 | 05/09/2026 | Ibrahim Musa | ibrahim.musa@... | 0805... | 7 Zoo Road, Kano | Kano | North West | Leather Sandals (Kano Leather Works, Leather Goods, 22000 x2) | card failed, then bank transfer successful | Red Star Express | RSE55218... |

This sheet has all three classic anomalies:

1. **Update anomaly:** if Lagos Gadget Hub changes its name, I would have to find and edit it inside every order that mentions it.
2. **Insertion anomaly:** I cannot record a new product or a new seller until somebody orders from them.
3. **Deletion anomaly:** if Ibrahim's order is deleted, the only record that Kano Leather Works sells sandals disappears with it.


## First Normal Form (1NF)

1NF needs every field to hold one atomic value and no repeating groups.

The "products bought" column is a repeating group, and the payment column holds a list of attempts. Names and addresses are also composite.

What I changed:

1. One row per product per order instead of one row per order.
2. Customer name split into first_name and last_name, and the address split into street, city and state.
3. Payment attempts moved out into their own rows, because one order can have several attempts.
4. Surrogate keys added (order_id, product_id) so rows can be identified reliably.

The order line table now has the composite key **(order_id, product_id)**.


## Second Normal Form (2NF)

2NF removes partial dependencies, where a column depends on only part of a composite key.

Looking at the order line table with key (order_id, product_id):

```
order_id              → ordered_at, customer details, delivery address, order_status
product_id            → product_name, category, seller details, current list price
(order_id, product_id) → quantity, unit_price paid
```

Most columns depend on only half of the key. So I split it three ways:

1. **orders** (order_id, customer details, address, status, ordered_at)
2. **products** (product_id, product_name, category, seller details, list price, stock)
3. **order_items** (order_id, product_id, quantity, unit_price)

Only quantity and the price actually paid need the full key, so they stay in order_items.


## Third Normal Form (3NF)

3NF removes transitive dependencies, where a non key column depends on another non key column.

There were several left:

| Table | Transitive dependency | Fix |
| --- | --- | --- |
| orders | order_id → customer_id → email, phone, names | Moved customer details to **customers** |
| orders | a customer can keep several addresses and choose one per order | Moved to **addresses**, orders point to shipping_address_id |
| addresses | state_name → region | Moved to **states** |
| products | product_id → seller_id → business_name, email, phone, state | Moved to **sellers** |
| products | product_id → category_name → parent category | Moved to **categories**, with a self reference for the parent |
| orders | order_id → tracking_number → courier, shipment status, dates | Moved to **shipments** |

Reviews were never part of the sheet, but they follow the same idea: a review belongs to one customer and one product, so it gets its own table with both as foreign keys.

That gives the final eleven tables: states, customers, addresses, sellers, categories, products, orders, order_items, payments, shipments and reviews.


## Boyce Codd Normal Form (BCNF) Check

BCNF is stricter: every determinant must be a candidate key. I went through each table looking for a column that decides other columns without being a key.

1. **customers:** customer_id, email and phone are all candidate keys. Each one determines the whole row, so that is fine.
2. **states:** both state_id and state_name are candidate keys, and region depends on either.
3. **products:** product_id and (seller_id, product_name) are both candidate keys, because a seller cannot list two products with the same name.
4. **shipments:** shipment_id, order_id and tracking_number are all candidate keys.
5. **addresses:** I checked whether city → state_id holds. It does not in Nigeria, because the same town name can exist in more than one state, so there is no hidden dependency there.

I did not find any determinant that is not a candidate key, so the schema is in BCNF.


## Choices That Look Like Redundancy But Are Not

**unit_price in both products and order_items.** These are different facts. products.unit_price is today's list price. order_items.unit_price is what the customer actually paid on that day. Order 10 in the sample data shows why this matters: the power bank was bought for 17,500 during a promo, while the list price is 18,500. If I only kept one price, changing it would silently rewrite every past invoice.

**Order total is not stored.** It can always be worked out as the sum of quantity × unit_price from order_items. Storing it would create a second copy that could drift out of sync. I will revisit this in Portfolio 2 if reporting queries show a real need for it.

**Payment amount is stored.** This is what the payment gateway actually charged, which is an independent fact. Comparing it with the computed order total is exactly how finance would catch a mismatch.
