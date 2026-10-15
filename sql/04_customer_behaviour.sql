-- =====================================================================
-- 04_customer_behaviour.sql | Who buys, how often, and what drives satisfaction
-- Techniques: CTEs, LAG, ROW_NUMBER, PERCENTILE_CONT, conditional aggregation, subqueries
-- Customer = customer_unique_id. Only DELIVERED orders count as real purchases here.
-- =====================================================================
SET search_path TO olist;

-- Q1. Headline: customers, repeat customers, repeat rate
WITH per_cust AS (
    SELECT customer_unique_id, COUNT(*) AS orders, SUM(items_revenue) AS revenue
    FROM v_orders_enriched
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                             AS customers,
       COUNT(*) FILTER (WHERE orders > 1)                    AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2) AS repeat_rate_pct,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE orders > 1) / SUM(revenue), 2) AS revenue_share_from_repeaters_pct,
       ROUND(AVG(revenue),2)                                 AS avg_lifetime_revenue
FROM per_cust;

-- Q2. Distribution of orders per customer
WITH per_cust AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM v_orders_enriched WHERE order_status = 'delivered' GROUP BY 1
)
SELECT CASE WHEN orders >= 4 THEN '4+' ELSE orders::text END AS orders_per_customer,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_customers
FROM per_cust
GROUP BY 1 ORDER BY 1;

-- Q3. Days between consecutive orders for repeat customers (LAG) - mean and median
WITH o AS (
    SELECT customer_unique_id, order_purchase_timestamp,
           order_purchase_timestamp::date
             - LAG(order_purchase_timestamp::date) OVER (PARTITION BY customer_unique_id
                                                         ORDER BY order_purchase_timestamp) AS gap_days
    FROM v_orders_enriched WHERE order_status = 'delivered'
)
SELECT COUNT(gap_days)                                                AS repeat_orders,
       ROUND(AVG(gap_days),1)                                         AS avg_gap_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days)          AS median_gap_days
FROM o WHERE gap_days IS NOT NULL;

-- Q4. New vs returning customer revenue by month
WITH ranked AS (
    SELECT order_month, items_revenue,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS order_seq
    FROM v_orders_enriched WHERE order_status = 'delivered'
)
SELECT order_month,
       COUNT(*) FILTER (WHERE order_seq = 1)                     AS new_customer_orders,
       COUNT(*) FILTER (WHERE order_seq > 1)                     AS returning_orders,
       ROUND(SUM(items_revenue) FILTER (WHERE order_seq = 1),2)  AS new_revenue,
       ROUND(SUM(items_revenue) FILTER (WHERE order_seq > 1),2)  AS returning_revenue
FROM ranked GROUP BY order_month ORDER BY order_month;

-- Q5. Does late delivery hurt satisfaction? (review score by delivery outcome)
SELECT CASE WHEN is_late = 1 THEN 'late' ELSE 'on time / early' END AS delivery_outcome,
       COUNT(*)                                   AS orders,
       ROUND(AVG(review_score),2)                 AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(*), 2) AS pct_low_reviews
FROM v_orders_enriched
WHERE order_status = 'delivered' AND is_late IS NOT NULL AND review_score IS NOT NULL
GROUP BY 1;

-- Q6. Review score by delivery-days band
SELECT CASE WHEN delivery_days <= 7  THEN '1) 0-7 days'
            WHEN delivery_days <= 14 THEN '2) 8-14 days'
            WHEN delivery_days <= 21 THEN '3) 15-21 days'
            ELSE '4) 22+ days' END                  AS delivery_band,
       COUNT(*)                                     AS orders,
       ROUND(AVG(review_score),2)                   AS avg_review_score
FROM v_orders_enriched
WHERE order_status = 'delivered' AND delivery_days IS NOT NULL AND review_score IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- Q7. Does a bad first experience reduce repeat purchase? (subquery + join)
WITH first_orders AS (
    SELECT DISTINCT ON (customer_unique_id) customer_unique_id, review_score, is_late
    FROM v_orders_enriched
    WHERE order_status = 'delivered'
    ORDER BY customer_unique_id, order_purchase_timestamp
), counts AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM v_orders_enriched WHERE order_status = 'delivered' GROUP BY 1
)
SELECT CASE WHEN f.review_score >= 4 THEN 'first review 4-5'
            WHEN f.review_score <= 2 THEN 'first review 1-2'
            ELSE 'first review 3' END                         AS first_experience,
       COUNT(*)                                               AS customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM first_orders f JOIN counts c USING (customer_unique_id)
WHERE f.review_score IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- Q8. Installments vs order value
SELECT CASE WHEN max_installments = 1 THEN '1 (pay in full)'
            WHEN max_installments <= 4 THEN '2-4'
            WHEN max_installments <= 9 THEN '5-9'
            ELSE '10+' END                      AS installments_band,
       COUNT(*)                                 AS orders,
       ROUND(AVG(items_revenue),2)              AS avg_order_value
FROM v_orders_enriched
WHERE is_valid_sale AND max_installments IS NOT NULL
GROUP BY 1 ORDER BY 1;
