-- 07_late_order_pareto_by_seller.sql
-- Business question: are late deliveries spread evenly, or concentrated in a few sellers?
-- Techniques: running total with SUM() OVER (ORDER BY ...), share of total, ROW_NUMBER().

WITH late_by_seller AS (
    SELECT oi.seller_id, COUNT(DISTINCT d.order_id) AS late_orders
    FROM delivered_orders d
    JOIN order_items oi USING (order_id)
    WHERE d.on_time = 0
    GROUP BY oi.seller_id
),
active_sellers AS (   -- every seller with at least one delivered order, late or not
    SELECT COUNT(DISTINCT oi.seller_id) AS n
    FROM delivered_orders d
    JOIN order_items oi USING (order_id)
),
ranked AS (
    SELECT
        seller_id,
        late_orders,
        ROW_NUMBER() OVER (ORDER BY late_orders DESC, seller_id)                AS seller_rank,
        SUM(late_orders) OVER (ORDER BY late_orders DESC, seller_id)            AS cum_late_orders,
        SUM(late_orders) OVER ()                                                AS total_late_orders
    FROM late_by_seller
)
SELECT
    seller_rank,
    seller_id,
    late_orders,
    ROUND(100.0 * seller_rank / (SELECT n FROM active_sellers), 1) AS pct_of_active_sellers,
    ROUND(100.0 * cum_late_orders / total_late_orders, 1)   AS cum_pct_of_late_orders
FROM ranked
ORDER BY seller_rank;
