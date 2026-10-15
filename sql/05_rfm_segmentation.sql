-- =====================================================================
-- 05_rfm_segmentation.sql | RFM customer segmentation (view + summary)
-- DESIGN DECISIONS (be ready to defend these in interviews):
--  1. Snapshot date = last order date in the DATA + 1 day, NOT CURRENT_DATE
--     (the dataset is historical; CURRENT_DATE would make everyone look "lost").
--  2. Recency & Monetary use NTILE(5) quintiles.
--  3. Frequency does NOT use NTILE: most customers have exactly 1 order, and NTILE would
--     split identical values into different buckets arbitrarily. Rule-based scoring instead:
--     1 order -> 1, 2 orders -> 3, 3+ orders -> 5.
--  4. Segments are assigned with explicit, auditable CASE rules.
-- =====================================================================
SET search_path TO olist;

CREATE OR REPLACE VIEW v_rfm AS
WITH snapshot AS (
    SELECT (MAX(order_purchase_timestamp)::date + 1) AS snap_date
    FROM orders
), base AS (
    SELECT customer_unique_id,
           (SELECT snap_date FROM snapshot) - MAX(order_purchase_timestamp)::date AS recency_days,
           COUNT(*)                                                               AS frequency,
           SUM(items_revenue)                                                      AS monetary
    FROM v_orders_enriched
    WHERE order_status = 'delivered' AND items_revenue > 0
    GROUP BY customer_unique_id
), scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,   -- most recent = 5
           CASE WHEN frequency >= 3 THEN 5 WHEN frequency = 2 THEN 3 ELSE 1 END AS f_score,
           NTILE(5) OVER (ORDER BY monetary)           AS m_score    -- biggest spender = 5
    FROM base
)
SELECT customer_unique_id, recency_days, frequency, ROUND(monetary,2) AS monetary,
       r_score, f_score, m_score,
       CASE
           WHEN f_score = 5 AND r_score >= 3             THEN 'Champions'
           WHEN f_score >= 3 AND r_score >= 3            THEN 'Loyal Repeat'
           WHEN f_score >= 3 AND r_score <  3            THEN 'Repeat - Lapsing'
           WHEN f_score = 1 AND r_score >= 4             THEN 'New / Recent'
           WHEN f_score = 1 AND m_score >= 4 AND r_score >= 2 THEN 'Big Spenders - One Time'
           WHEN f_score = 1 AND r_score <= 2             THEN 'Dormant One-Timers'
           ELSE 'Needs Attention'
       END AS segment
FROM scored;

-- Segment summary: size, revenue, and how each segment compares
SELECT segment,
       COUNT(*)                                                          AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                AS pct_customers,
       ROUND(SUM(monetary),2)                                            AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2)      AS pct_revenue,
       ROUND(AVG(monetary),2)                                            AS avg_monetary,
       ROUND(AVG(recency_days),0)                                        AS avg_recency_days,
       ROUND(AVG(frequency),2)                                           AS avg_orders
FROM v_rfm
GROUP BY segment
ORDER BY revenue DESC;

-- Sanity check: score ranges per component (should be 1..5)
SELECT MIN(r_score), MAX(r_score), MIN(f_score), MAX(f_score), MIN(m_score), MAX(m_score) FROM v_rfm;
