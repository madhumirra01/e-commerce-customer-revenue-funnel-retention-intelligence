-- =====================================================================
-- 08_powerbi_views.sql | Star-schema views that Power BI imports.
-- Power BI reads these bi_* views plus v_rfm, v_cohort_retention, v_funnel_monthly
-- (clean contract between the database and the dashboard).
-- =====================================================================
SET search_path TO olist;

CREATE OR REPLACE VIEW bi_fact_orders AS
SELECT order_id, customer_unique_id, order_status, is_valid_sale,
       order_date, order_purchase_timestamp,
       items, items_revenue, freight, gmv, main_payment_type, max_installments,
       review_score, delivery_days, is_late, customer_state
FROM v_orders_enriched;

CREATE OR REPLACE VIEW bi_fact_order_items AS
SELECT oi.order_id, oi.order_item_id, oi.product_id, oi.seller_id, oi.price, oi.freight_value,
       o.order_purchase_timestamp::date AS order_date,
       (o.order_status NOT IN ('canceled','unavailable')) AS is_valid_sale
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id;

CREATE OR REPLACE VIEW bi_dim_customer AS
SELECT DISTINCT ON (customer_unique_id)
       customer_unique_id, customer_city, customer_state
FROM v_orders_enriched
ORDER BY customer_unique_id, order_purchase_timestamp DESC;   -- latest known location

CREATE OR REPLACE VIEW bi_dim_product AS
SELECT product_id, product_category_name_english AS category, product_photos_qty, product_weight_g
FROM products;

CREATE OR REPLACE VIEW bi_dim_seller AS
SELECT seller_id, seller_city, seller_state FROM sellers;
