-- =====================================================================
-- 07_funnel_analysis.sql | Order-lifecycle funnel
-- Olist has no browse/cart events, so the funnel is the FULFILLMENT journey:
-- placed -> approved -> shipped -> delivered -> reviewed.  (State this limitation openly.)
-- =====================================================================
SET search_path TO olist;

CREATE OR REPLACE VIEW v_funnel_monthly AS
SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date                          AS order_month,
       COUNT(*)                                                                       AS placed,
       COUNT(o.order_approved_at)                                                     AS approved,
       COUNT(o.order_delivered_carrier_date)                                          AS shipped,
       COUNT(o.order_delivered_customer_date)                                         AS delivered,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM order_reviews r WHERE r.order_id = o.order_id)) AS reviewed,
       COUNT(*) FILTER (WHERE o.order_status IN ('canceled','unavailable'))           AS canceled_or_unavailable
FROM orders o
GROUP BY 1;

-- Q1. Overall funnel with step conversion and drop-off (UNPIVOT via VALUES + LAG)
WITH totals AS (
    SELECT SUM(placed) placed, SUM(approved) approved, SUM(shipped) shipped,
           SUM(delivered) delivered, SUM(reviewed) reviewed
    FROM v_funnel_monthly
), stages AS (
    SELECT 1 AS step, 'Placed'    AS stage, placed    AS orders FROM totals UNION ALL
    SELECT 2, 'Approved',  approved  FROM totals UNION ALL
    SELECT 3, 'Shipped',   shipped   FROM totals UNION ALL
    SELECT 4, 'Delivered', delivered FROM totals UNION ALL
    SELECT 5, 'Reviewed',  reviewed  FROM totals
)
SELECT step, stage, orders,
       ROUND(100.0 * orders / FIRST_VALUE(orders) OVER (ORDER BY step), 2)                 AS pct_of_placed,
       ROUND(100.0 * orders / NULLIF(LAG(orders) OVER (ORDER BY step), 0), 2)              AS step_conversion_pct,
       LAG(orders) OVER (ORDER BY step) - orders                                           AS dropped_from_prev_step
FROM stages ORDER BY step;

-- Q2. Where do orders die? Final status distribution
SELECT order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders GROUP BY order_status ORDER BY orders DESC;

-- Q3. Time spent in each stage (hours/days) - mean and median
SELECT ROUND(AVG(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp))/3600)::numeric,1)            AS avg_hours_to_approve,
       ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at))/86400)::numeric,1)       AS avg_days_approve_to_carrier,
       ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date))/86400)::numeric,1) AS avg_days_in_transit,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp))/86400))::numeric,1) AS median_days_purchase_to_delivery
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL;

-- Q4. Monthly delivery conversion and late-delivery rate
SELECT f.order_month,
       f.placed,
       ROUND(100.0 * f.delivered / f.placed, 2)                                   AS delivered_pct,
       ROUND(100.0 * f.canceled_or_unavailable / f.placed, 2)                     AS canceled_pct,
       ROUND(100.0 * SUM(e.is_late) / NULLIF(COUNT(e.is_late), 0), 2)             AS late_pct
FROM v_funnel_monthly f
LEFT JOIN v_orders_enriched e ON e.order_month = f.order_month
GROUP BY f.order_month, f.placed, f.delivered, f.canceled_or_unavailable
ORDER BY f.order_month;

-- Q5. Late-delivery rate by customer state (worst 10, states with >= 200 delivered orders)
SELECT customer_state, COUNT(*) AS delivered_orders,
       ROUND(100.0 * AVG(is_late),2)       AS late_pct,
       ROUND(AVG(delivery_days),1)         AS avg_delivery_days
FROM v_orders_enriched
WHERE order_status = 'delivered' AND is_late IS NOT NULL
GROUP BY customer_state
HAVING COUNT(*) >= 200
ORDER BY late_pct DESC
LIMIT 10;
