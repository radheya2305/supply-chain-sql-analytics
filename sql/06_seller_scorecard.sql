-- 06_seller_scorecard.sql
-- Business question: which sellers (suppliers) should we review first?
-- Builds a supplier scorecard: volume, on-time %, handoff to carrier, review score,
-- then ranks sellers and splits them into performance quartiles.
-- Techniques: multiple CTEs, LEFT JOIN, RANK() and NTILE() window functions.

WITH seller_orders AS (
    SELECT DISTINCT oi.seller_id, d.order_id, d.on_time
    FROM delivered_orders d
    JOIN order_items oi USING (order_id)
),
seller_handoff AS (
    -- Did the seller hand the item to the carrier by its own shipping deadline?
    SELECT oi.seller_id,
           AVG(CASE WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date THEN 1 ELSE 0 END) AS handoff_on_time
    FROM order_items oi
    JOIN delivered_orders o USING (order_id)
    WHERE o.order_delivered_carrier_date IS NOT NULL
    GROUP BY oi.seller_id
),
seller_reviews AS (
    SELECT so.seller_id, AVG(r.review_score) AS avg_review
    FROM seller_orders so
    JOIN reviews r USING (order_id)
    GROUP BY so.seller_id
),
scorecard AS (
    SELECT
        so.seller_id,
        s.seller_state,
        COUNT(*)                                  AS orders,
        ROUND(100.0 * AVG(so.on_time), 1)         AS on_time_pct,
        ROUND(100.0 * MAX(h.handoff_on_time), 1)  AS handoff_on_time_pct,
        ROUND(MAX(r.avg_review), 2)               AS avg_review
    FROM seller_orders so
    JOIN sellers s             USING (seller_id)
    LEFT JOIN seller_handoff h USING (seller_id)
    LEFT JOIN seller_reviews r USING (seller_id)
    GROUP BY so.seller_id, s.seller_state
    HAVING COUNT(*) >= 100              -- only sellers with enough volume to judge
)
SELECT
    RANK()  OVER (ORDER BY on_time_pct ASC, orders DESC) AS review_priority,
    NTILE(4) OVER (ORDER BY on_time_pct DESC)            AS on_time_quartile,  -- 1 = best
    seller_id,
    seller_state,
    orders,
    on_time_pct,
    handoff_on_time_pct,
    avg_review
FROM scorecard
ORDER BY review_priority;
