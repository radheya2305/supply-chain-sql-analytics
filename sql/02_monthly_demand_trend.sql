-- 02_monthly_demand_trend.sql
-- Business question: how is demand trending, and how volatile is it month to month?
-- Techniques: GROUP BY month, LAG() for month-over-month growth, AVG() OVER a 3-month window.

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT o.order_id)                      AS orders,
        COUNT(*)                                        AS units,
        ROUND(SUM(oi.price), 0)                         AS revenue
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01'
    GROUP BY 1
)
SELECT
    CAST(order_month AS DATE)                                              AS order_month,
    orders,
    units,
    revenue,
    ROUND(100.0 * (orders - LAG(orders) OVER (ORDER BY order_month))
          / LAG(orders) OVER (ORDER BY order_month), 1)                    AS mom_growth_pct,
    ROUND(AVG(orders) OVER (ORDER BY order_month
                            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0)  AS orders_3mo_avg
FROM monthly
ORDER BY order_month;
