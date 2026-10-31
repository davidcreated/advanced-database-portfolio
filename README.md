# Advanced Database Systems Portfolio

**Course:** MIT 8103 Advanced Database Systems

**Session:** 2026/2027, First Semester

**Student:** David-Paul Folorunsho-Roberts

**Student ID:** 2026/A/MIT/0268


## Case Study: OjaHub Marketplace

OjaHub is a simulated Nigerian online marketplace. "Oja" means market in Yoruba, and the idea is a digital version of one: independent sellers open a shop, list their products, and customers across the country browse, order and pay, with delivery handled by courier partners.

I picked this scenario because it has enough moving parts to carry every activity in this course. It has structured relational data, heavy read and write traffic, money changing hands, stock that can run out, and product details that look completely different from one category to another.

**Nature of the business:** online retail marketplace connecting many small sellers with buyers in all 36 states and the FCT.

**Users of the database:**

1. Customers, who browse products, place orders, pay and leave reviews.
2. Sellers, who manage their shop, products and stock levels.
3. Operations staff, who track payments, shipments and disputes.
4. Management, who rely on sales reports by region, category and seller.

**Major data stored:** customers and their delivery addresses, sellers, product categories, products and stock, orders and order items, payments, shipments and product reviews.

**Key operations the database supports:**

1. Register customers and sellers.
2. Add and update products and stock.
3. Place an order and reduce stock safely when many people buy at once.
4. Process payments, including failed attempts and retries.
5. Track delivery status for each order.
6. Produce sales and performance reports.


## Repository Structure

```
advanced-database-portfolio/
├── portfolio-1-database-design/
├── portfolio-2-query-optimisation/
├── portfolio-3-transactions-concurrency/
├── portfolio-4-nosql/
├── portfolio-5-distributed-cloud/
└── README.md
```

Each portfolio folder is added when I start that activity, and has its own README explaining what I did and how I tested it.


## Tools

PostgreSQL 18 running locally on macOS through Homebrew, with psql for running scripts and capturing output.


## Progress

| Portfolio | Activity | Status |
| --- | --- | --- |
| 1 | Database Design and Modelling | Complete |
| 2 | Query Processing and Optimisation | Complete |
| 3 | Transactions and Concurrency | Not started |
| 4 | NoSQL and Advanced Data Models | Not started |
| 5 | Distributed and Cloud Database Exercise | Not started |
