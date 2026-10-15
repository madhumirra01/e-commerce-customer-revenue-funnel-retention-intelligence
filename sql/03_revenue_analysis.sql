-- =====================================================================
-- 03_revenue_analysis.sql | Revenue & sales analysis
-- Techniques: CTE, LAG, running SUM() OVER, share-of-total window, Pareto cumulative share
-- Run each query separately in VS Code (SQLTools: select text -> Ctrl+E Ctrl+E)
-- NOTE: inspect the first and last months of Q1 - the source data usually has partial months
--       at both ends; decide (and document) whether to exclude them from trend conclusions.
-- =====================================================================
SET search_path TO olist;

-- Q1. Monthly revenue, orders, AOV, month-over-month growth, running total
WITH monthly AS (
    SELECT order_month,
           COUNT(*)                         AS orders,
           SUM(items_revenue)               AS revenue,
           SUM(items_revenue) / COUNT(*)    AS aov
    FROM v_orders_enriched
    WHERE is_valid_sale
    GROUP BY order_month
)
SELECT order_month, orders, ROUND(revenue,2) AS revenue, ROUND(aov,2) AS aov,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
             / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2)   AS revenue_mom_pct,
       ROUND(SUM(revenue) OVER (ORDER BY order_month), 2)                AS cumulative_revenue
FROM monthly
ORDER BY order_month;

-- Q2. Top 15 categories by revenue with % share and cumulative % (Pareto)
WITH cat AS (
    SELECT p.product_category_name_english AS category,
           COUNT(DISTINCT oi.order_id)     AS orders,
           SUM(oi.price)                   AS revenue
    FROM order_items oi
    JOIN products p  ON p.product_id = oi.product_id
    JOIN orders o    ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled','unavailable')
    GROUP BY 1
)
SELECT category, orders, ROUND(revenue,2) AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)                                    AS pct_of_total,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2)   AS cumulative_pct,
       RANK() OVER (ORDER BY revenue DESC)                                                 AS revenue_rank
FROM cat
ORDER BY revenue DESC
LIMIT 15;

-- Q3. Revenue by customer state, with share of total and avg order value
SELECT customer_state,
       COUNT(*)                                       AS orders,
       COUNT(DISTINCT customer_unique_id)             AS customers,
       ROUND(SUM(items_revenue),2)                    AS revenue,
       ROUND(100.0 * SUM(items_revenue) / SUM(SUM(items_revenue)) OVER (), 2) AS pct_of_total,
       ROUND(AVG(items_revenue),2)                    AS aov,
       ROUND(AVG(freight),2)                          AS avg_freight
FROM v_orders_enriched
WHERE is_valid_sale
GROUP BY customer_state
ORDER BY revenue DESC;

-- Q4. Payment method mix
SELECT main_payment_type,
       COUNT(*)                                                   AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)          AS pct_orders,
       ROUND(AVG(items_revenue),2)                                AS aov,
       ROUND(AVG(max_installments),2)                             AS avg_installments
FROM v_orders_enriched
WHERE is_valid_sale AND main_payment_type IS NOT NULL
GROUP BY main_payment_type
ORDER BY orders DESC;

-- Q5. Seller concentration: do a few sellers drive most revenue? (subquery + window)
SELECT seller_rank, seller_id, revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)                                  AS pct_of_total,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM (
    SELECT oi.seller_id,
           ROUND(SUM(oi.price),2) AS revenue,
           RANK() OVER (ORDER BY SUM(oi.price) DESC) AS seller_rank
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled','unavailable')
    GROUP BY oi.seller_id
) s
WHERE seller_rank <= 20
ORDER BY seller_rank;

-- Q6. Share of sellers needed to reach 80% of revenue
WITH s AS (
    SELECT seller_id, SUM(price) AS revenue
    FROM order_items oi JOIN orders o USING (order_id)
    WHERE o.order_status NOT IN ('canceled','unavailable')
    GROUP BY seller_id
), c AS (
    SELECT revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_share,
           ROW_NUMBER() OVER (ORDER BY revenue DESC)                         AS n
    FROM s
)
SELECT MIN(n) AS sellers_for_80pct_revenue, (SELECT COUNT(*) FROM s) AS total_sellers,
       ROUND(100.0 * MIN(n) / (SELECT COUNT(*) FROM s), 2) AS pct_of_sellers
FROM c WHERE cum_share >= 0.80;

-- Q7. Purchase timing: day of week x part of day
SELECT TO_CHAR(order_purchase_timestamp, 'Dy')                          AS dow,
       EXTRACT(ISODOW FROM order_purchase_timestamp)::int               AS dow_num,
       CASE WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 0 AND 5   THEN '1 night'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 6 AND 11  THEN '2 morning'
            WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 12 AND 17 THEN '3 afternoon'
            ELSE '4 evening' END                                         AS day_part,
       COUNT(*) AS orders
FROM v_orders_enriched
WHERE is_valid_sale
GROUP BY 1,2,3
ORDER BY dow_num, day_part;
