-- 08_category_abc_classification.sql
-- Business question: which product categories drive most of the revenue (and deserve the most planning attention)?
-- ABC rule used: A = categories making up the first 80% of revenue, B = next 15%, C = last 5%.
-- Techniques: cumulative share with SUM() OVER, CASE for classification, COALESCE for missing names.

WITH category_revenue AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        COUNT(*)            AS units,
        SUM(oi.price)       AS revenue
    FROM order_items oi
    JOIN orders o   USING (order_id)
    JOIN products p USING (product_id)
    LEFT JOIN category_translation t USING (product_category_name)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01'
    GROUP BY 1
),
cumulative AS (
    SELECT
        category,
        units,
        revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / SUM(revenue) OVER () AS cum_share
    FROM category_revenue
)
SELECT
    category,
    units,
    ROUND(revenue, 0)                    AS revenue,
    ROUND(100.0 * cum_share, 1)          AS cum_revenue_pct,
    CASE WHEN cum_share - revenue / SUM(revenue) OVER () < 0.80 THEN 'A'
         WHEN cum_share - revenue / SUM(revenue) OVER () < 0.95 THEN 'B'
         ELSE 'C' END                    AS abc_class
FROM cumulative
ORDER BY revenue DESC;
