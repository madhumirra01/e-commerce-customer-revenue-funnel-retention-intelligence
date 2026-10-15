-- =====================================================================
-- 01_schema.sql  |  Relational schema for the Olist e-commerce warehouse
-- Star-ish layout: orders = hub, order_items/payments/reviews = facts hanging off it,
-- customers/products/sellers = dimensions.  Idempotent: safe to re-run.
-- =====================================================================
DROP SCHEMA IF EXISTS olist CASCADE;
CREATE SCHEMA olist;
SET search_path TO olist;

CREATE TABLE customers (
    customer_id               VARCHAR(32) PRIMARY KEY,          -- one per ORDER in source data
    customer_unique_id        VARCHAR(32) NOT NULL,             -- the real person
    customer_zip_code_prefix  CHAR(5),
    customer_city             TEXT,
    customer_state            CHAR(2)
);

CREATE TABLE sellers (
    seller_id               VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix  CHAR(5),
    seller_city             TEXT,
    seller_state            CHAR(2)
);

CREATE TABLE products (
    product_id                    VARCHAR(32) PRIMARY KEY,
    product_category_name         TEXT NOT NULL,                -- Portuguese
    product_name_length           INT,
    product_description_length    INT,
    product_photos_qty            INT,
    product_weight_g              NUMERIC(10,2),
    product_length_cm             NUMERIC(8,2),
    product_height_cm             NUMERIC(8,2),
    product_width_cm              NUMERIC(8,2),
    product_category_name_english TEXT NOT NULL
);

CREATE TABLE orders (
    order_id                       VARCHAR(32) PRIMARY KEY,
    customer_id                    VARCHAR(32) NOT NULL REFERENCES customers(customer_id),
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       TIMESTAMP NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP,
    CONSTRAINT chk_status CHECK (order_status IN
      ('created','approved','invoiced','processing','shipped','delivered','unavailable','canceled'))
);

CREATE TABLE order_items (
    order_id             VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    order_item_id        INT NOT NULL,                          -- line number within the order
    product_id           VARCHAR(32) NOT NULL REFERENCES products(product_id),
    seller_id            VARCHAR(32) NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2) NOT NULL,
    freight_value        NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id              VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    payment_sequential    INT NOT NULL,
    payment_type          VARCHAR(20) NOT NULL,
    payment_installments  INT NOT NULL,
    payment_value         NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE order_reviews (
    review_id                VARCHAR(32) NOT NULL,
    order_id                 VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    review_score             SMALLINT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    has_comment              BOOLEAN,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

-- Indexes on foreign keys / filter columns used by the analysis queries
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_purchase   ON orders(order_purchase_timestamp);
CREATE INDEX idx_orders_status     ON orders(order_status);
CREATE INDEX idx_customers_unique  ON customers(customer_unique_id);
CREATE INDEX idx_items_product     ON order_items(product_id);
CREATE INDEX idx_items_seller      ON order_items(seller_id);
CREATE INDEX idx_reviews_order     ON order_reviews(order_id);
