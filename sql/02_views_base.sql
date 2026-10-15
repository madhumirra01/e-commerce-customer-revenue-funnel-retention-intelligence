-- =====================================================================
-- 02_views_base.sql | Reusable analytical layer.
-- KEY IDEA: aggregate items / payments / reviews to ORDER grain *before* joining,
-- otherwise joining 1 order -> N items -> M payments multiplies rows ("fan-out")
-- and silently inflates revenue.
-- BUSINESS DEFINITIONS
--   valid sale  : order_status NOT IN ('canceled','unavailable')
--   revenue     : SUM(item price)   (freight reported separately; GMV = price + freight)
--   customer    : customer_unique_id  (NOT customer_id)
-- =====================================================================
SET search_path TO olist;

CREATE OR REPLACE VIEW v_order_items_agg AS
SELECT order_id,
       COUNT(*)            AS items,
       SUM(price)          AS items_revenue,
       SUM(freight_value)  AS freight
FROM order_items
GROUP BY order_id;

CREATE OR REPLACE VIEW v_order_payments_agg AS
SELECT order_id,
       SUM(payment_value)                                          AS payment_total,
       MAX(payment_installments)                                   AS max_installments,
       (ARRAY_AGG(payment_type ORDER BY payment_value DESC))[1]    AS main_payment_type
FROM order_payments
GROUP BY order_id;

CREATE OR REPLACE VIEW v_order_reviews_agg AS
SELECT order_id, AVG(review_score)::numeric(3,2) AS review_score
FROM order_reviews
GROUP BY order_id;

CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT o.order_id,
       o.customer_id,
       c.customer_unique_id,
       c.customer_city,
       c.customer_state,
       o.order_status,
       (o.order_status NOT IN ('canceled','unavailable'))                AS is_valid_sale,
       o.order_purchase_timestamp,
       o.order_purchase_timestamp::date                                  AS order_date,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date             AS order_month,
       o.order_approved_at,
       o.order_delivered_carrier_date,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       COALESCE(i.items, 0)                                              AS items,
       COALESCE(i.items_revenue, 0)                                      AS items_revenue,
       COALESCE(i.freight, 0)                                            AS freight,
       COALESCE(i.items_revenue, 0) + COALESCE(i.freight, 0)             AS gmv,
       p.payment_total,
       p.main_payment_type,
       p.max_installments,
       r.review_score,
       CASE WHEN o.order_delivered_customer_date IS NOT NULL
            THEN o.order_delivered_customer_date::date - o.order_purchase_timestamp::date END  AS delivery_days,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0 END                                                   AS is_late
FROM orders o
JOIN customers c                 ON c.customer_id = o.customer_id
LEFT JOIN v_order_items_agg i    ON i.order_id = o.order_id
LEFT JOIN v_order_payments_agg p ON p.order_id = o.order_id
LEFT JOIN v_order_reviews_agg r  ON r.order_id = o.order_id;
