-- 05_late_delivery_by_lane.sql
-- Business question: which shipping lanes (seller state -> customer state) produce the most late orders?
-- Ranked by the number of late orders, since that is where a fix removes the most failures.
-- Techniques: window aggregates over a GROUP BY (SUM(COUNT(*)) OVER ()), QUALIFY to filter after windows.
-- An order can ship from several sellers, so lanes are built at the order-item level.

WITH lane_items AS (
    SELECT DISTINCT
        d.order_id,
        s.seller_state,
        d.customer_state,
        d.on_time,
        d.lead_time_days
    FROM delivered_orders d
    JOIN order_items oi USING (order_id)
    JOIN sellers s      USING (seller_id)
)
SELECT
    seller_state || ' -> ' || customer_state         AS lane,
    COUNT(*)                                         AS orders,
    CAST(SUM(1 - on_time) AS INTEGER)                AS late_orders,
    ROUND(100.0 * (1 - AVG(on_time)), 1)             AS late_pct,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)               AS pct_of_all_orders,
    ROUND(100.0 * SUM(1 - on_time) / SUM(SUM(1 - on_time)) OVER (), 1) AS pct_of_all_late_orders,
    ROUND(AVG(lead_time_days), 1)                    AS avg_lead_time_days
FROM lane_items
GROUP BY seller_state, customer_state
QUALIFY COUNT(*) >= 300          -- keep lanes with enough volume (after shares are computed on all lanes)
ORDER BY late_orders DESC
LIMIT 15;
