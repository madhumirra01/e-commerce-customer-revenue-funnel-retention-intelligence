-- =====================================================================
-- 06_cohort_retention.sql | Monthly acquisition cohorts and retention
-- Cohort = month of a customer's FIRST delivered order.
-- month_index = months elapsed since the cohort month (0 = acquisition month).
-- Techniques: multi-step CTEs, MIN() per group, AGE(), COUNT(DISTINCT), conditional pivot.
-- =====================================================================
SET search_path TO olist;

CREATE OR REPLACE VIEW v_cohort_retention AS
WITH cust_months AS (
    SELECT customer_unique_id, order_month
    FROM v_orders_enriched
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id, order_month
), first_month AS (
    SELECT customer_unique_id, MIN(order_month) AS cohort_month
    FROM cust_months GROUP BY customer_unique_id
), activity AS (
    SELECT f.cohort_month, c.customer_unique_id,
           (EXTRACT(YEAR  FROM AGE(c.order_month, f.cohort_month)) * 12
          + EXTRACT(MONTH FROM AGE(c.order_month, f.cohort_month)))::int AS month_index
    FROM cust_months c
    JOIN first_month f USING (customer_unique_id)
), cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_month GROUP BY cohort_month
)
SELECT a.cohort_month, cs.cohort_customers, a.month_index,
       COUNT(DISTINCT a.customer_unique_id)                                              AS active_customers,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) / cs.cohort_customers, 2)       AS retention_pct
FROM activity a
JOIN cohort_size cs USING (cohort_month)
GROUP BY a.cohort_month, cs.cohort_customers, a.month_index;

-- Q1. Full cohort table (long format)
SELECT * FROM v_cohort_retention ORDER BY cohort_month, month_index;

-- Q2. Pivoted heatmap-style view: retention % for months 0..6
SELECT cohort_month, MAX(cohort_customers) AS cohort_customers,
       MAX(retention_pct) FILTER (WHERE month_index = 0) AS m0,
       MAX(retention_pct) FILTER (WHERE month_index = 1) AS m1,
       MAX(retention_pct) FILTER (WHERE month_index = 2) AS m2,
       MAX(retention_pct) FILTER (WHERE month_index = 3) AS m3,
       MAX(retention_pct) FILTER (WHERE month_index = 6) AS m6
FROM v_cohort_retention
GROUP BY cohort_month ORDER BY cohort_month;

-- Q3. Blended retention curve: weighted average across cohorts, by month_index
SELECT month_index,
       SUM(active_customers)                                       AS active,
       SUM(cohort_customers)                                       AS base,
       ROUND(100.0 * SUM(active_customers) / SUM(cohort_customers), 2) AS weighted_retention_pct
FROM v_cohort_retention
WHERE month_index <= 6
GROUP BY month_index ORDER BY month_index;

-- Q4. Of customers who ever repeat, how fast is the 2nd order? (ROW_NUMBER + conditional buckets)
WITH seq AS (
    SELECT customer_unique_id, order_purchase_timestamp,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS n
    FROM v_orders_enriched WHERE order_status = 'delivered'
), firsts AS (
    SELECT s1.customer_unique_id,
           s1.order_purchase_timestamp AS first_ts,
           s2.order_purchase_timestamp AS second_ts
    FROM seq s1
    LEFT JOIN seq s2 ON s2.customer_unique_id = s1.customer_unique_id AND s2.n = 2
    WHERE s1.n = 1
)
SELECT COUNT(*)                                                                    AS customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE second_ts - first_ts <= INTERVAL '30 days')  / COUNT(*), 2) AS repeat_within_30d_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE second_ts - first_ts <= INTERVAL '90 days')  / COUNT(*), 2) AS repeat_within_90d_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE second_ts IS NOT NULL)                       / COUNT(*), 2) AS repeat_ever_pct
FROM firsts;
-- Caveat to state in your report: later cohorts have had less time to come back (right-censoring).
