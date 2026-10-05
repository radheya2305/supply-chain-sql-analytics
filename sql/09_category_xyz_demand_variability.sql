-- 09_category_xyz_demand_variability.sql
-- Business question: how forecastable is each category's demand?
-- XYZ uses the coefficient of variation (CV = std dev / mean) of monthly units:
--   X = CV < 0.5 (steady), Y = 0.5 to 1.0 (variable), Z = CV >= 1.0 (erratic).
-- Combined with ABC (query 08), this tells planners where to automate and where to watch closely.
-- Techniques: CROSS JOIN to fill months with zero sales, STDDEV_SAMP, joining to the ABC result.

WITH months AS (
    SELECT DISTINCT DATE_TRUNC('month', order_purchase_timestamp) AS order_month
    FROM orders
    WHERE order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND order_purchase_timestamp <  TIMESTAMP '2018-09-01'
),
category_month AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        COUNT(*) AS units
    FROM order_items oi
    JOIN orders o   USING (order_id)
    JOIN products p USING (product_id)
    LEFT JOIN category_translation t USING (product_category_name)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01'
    GROUP BY 1, 2
),
filled AS (   -- every category x every month, zero when nothing sold
    SELECT c.category, m.order_month, COALESCE(cm.units, 0) AS units
    FROM (SELECT DISTINCT category FROM category_month) c
    CROSS JOIN months m
    LEFT JOIN category_month cm ON cm.category = c.category AND cm.order_month = m.order_month
),
variability AS (
    SELECT category,
           SUM(units)                         AS total_units,
           AVG(units)                         AS avg_monthly_units,
           STDDEV_SAMP(units) / NULLIF(AVG(units), 0) AS cv
    FROM filled
    GROUP BY category
),
revenue AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o   USING (order_id)
    JOIN products p USING (product_id)
    LEFT JOIN category_translation t USING (product_category_name)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01'
    GROUP BY 1
),
abc AS (
    SELECT category, revenue,
           CASE WHEN SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) - revenue
                     < 0.80 * SUM(revenue) OVER () THEN 'A'
                WHEN SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) - revenue
                     < 0.95 * SUM(revenue) OVER () THEN 'B'
                ELSE 'C' END AS abc_class
    FROM revenue
)
SELECT
    v.category,
    a.abc_class,
    CASE WHEN v.cv < 0.5 THEN 'X' WHEN v.cv < 1.0 THEN 'Y' ELSE 'Z' END AS xyz_class,
    a.abc_class || CASE WHEN v.cv < 0.5 THEN 'X' WHEN v.cv < 1.0 THEN 'Y' ELSE 'Z' END AS abc_xyz,
    v.total_units,
    ROUND(v.avg_monthly_units, 1) AS avg_monthly_units,
    ROUND(v.cv, 2)                AS cv,
    ROUND(a.revenue, 0)           AS revenue
FROM variability v
JOIN abc a USING (category)
ORDER BY a.revenue DESC;
