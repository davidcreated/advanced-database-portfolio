-- OjaHub Marketplace: relational schema (PostgreSQL 18)

DROP SCHEMA IF EXISTS ojahub CASCADE;
CREATE SCHEMA ojahub;
SET search_path TO ojahub;

CREATE TABLE states (
    state_id    SMALLINT    PRIMARY KEY,
    state_name  VARCHAR(40) NOT NULL UNIQUE,
    region      VARCHAR(20) NOT NULL
        CHECK (region IN ('North Central', 'North East', 'North West',
                          'South East', 'South South', 'South West'))
);

CREATE TABLE customers (
    customer_id  INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(120) NOT NULL UNIQUE,
    phone        VARCHAR(15)  NOT NULL UNIQUE CHECK (phone ~ '^\+234[0-9]{10}$'),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE addresses (
    address_id   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INTEGER      NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
    street       VARCHAR(150) NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    state_id     SMALLINT     NOT NULL REFERENCES states (state_id),
    is_default   BOOLEAN      NOT NULL DEFAULT false
);

-- A customer can have many addresses but only one default
CREATE UNIQUE INDEX one_default_address_per_customer
    ON addresses (customer_id) WHERE is_default;

CREATE TABLE sellers (
    seller_id      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_name  VARCHAR(100) NOT NULL UNIQUE,
    email          VARCHAR(120) NOT NULL UNIQUE,
    phone          VARCHAR(15)  NOT NULL UNIQUE CHECK (phone ~ '^\+234[0-9]{10}$'),
    state_id       SMALLINT     NOT NULL REFERENCES states (state_id),
    joined_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_verified    BOOLEAN      NOT NULL DEFAULT false
);

CREATE TABLE categories (
    category_id         INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name       VARCHAR(60) NOT NULL UNIQUE,
    parent_category_id  INTEGER     REFERENCES categories (category_id) ON DELETE RESTRICT,
    CHECK (parent_category_id <> category_id)
);

CREATE TABLE products (
    product_id    INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id     INTEGER       NOT NULL REFERENCES sellers (seller_id) ON DELETE RESTRICT,
    category_id   INTEGER       NOT NULL REFERENCES categories (category_id) ON DELETE RESTRICT,
    product_name  VARCHAR(120)  NOT NULL,
    description   TEXT,
    unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    stock_qty     INTEGER       NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    is_active     BOOLEAN       NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (seller_id, product_name)
);

CREATE TABLE orders (
    order_id             INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id          INTEGER     NOT NULL REFERENCES customers (customer_id) ON DELETE RESTRICT,
    shipping_address_id  INTEGER     NOT NULL REFERENCES addresses (address_id) ON DELETE RESTRICT,
    order_status         VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (order_status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    ordered_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_id     INTEGER       NOT NULL REFERENCES orders (order_id) ON DELETE CASCADE,
    product_id   INTEGER       NOT NULL REFERENCES products (product_id) ON DELETE RESTRICT,
    quantity     INTEGER       NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE payments (
    payment_id      INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INTEGER       NOT NULL REFERENCES orders (order_id) ON DELETE RESTRICT,
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(20)   NOT NULL
        CHECK (payment_method IN ('card', 'bank_transfer', 'ussd', 'pay_on_delivery')),
    payment_status  VARCHAR(20)   NOT NULL DEFAULT 'initiated'
        CHECK (payment_status IN ('initiated', 'successful', 'failed', 'refunded')),
    reference       VARCHAR(40)   NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Retries are allowed, but an order can only be paid successfully once
CREATE UNIQUE INDEX one_successful_payment_per_order
    ON payments (order_id) WHERE payment_status = 'successful';

CREATE TABLE shipments (
    shipment_id      INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         INTEGER     NOT NULL UNIQUE REFERENCES orders (order_id) ON DELETE RESTRICT,
    courier          VARCHAR(40) NOT NULL,
    tracking_number  VARCHAR(30) NOT NULL UNIQUE,
    shipment_status  VARCHAR(20) NOT NULL DEFAULT 'processing'
        CHECK (shipment_status IN ('processing', 'in_transit', 'delivered', 'returned')),
    shipped_at       TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    CHECK (delivered_at IS NULL OR (shipped_at IS NOT NULL AND delivered_at >= shipped_at))
);

CREATE TABLE reviews (
    review_id    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id   INTEGER     NOT NULL REFERENCES products (product_id) ON DELETE CASCADE,
    customer_id  INTEGER     NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
    rating       SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    reviewed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, customer_id)
);
