-- 12_late_root_cause_seller_vs_carrier.sql
-- Business question: when an order is late, is it the seller's fault (slow handoff)
-- or the carrier's (slow transit)? This decides whether to fix supplier SLAs or carriers.
-- Seller late  = handed to carrier after the seller's shipping limit date.
-- Carrier late = seller handed off on time, but the order still missed the promised date.

WITH order_handoff AS (
    SELECT
        d.order_id,
        d.on_time,
        MAX(CASE WHEN d.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END) AS seller_handoff_late
    FROM delivered_orders d
    JOIN order_items oi USING (order_id)
    WHERE d.order_delivered_carrier_date IS NOT NULL
    GROUP BY d.order_id, d.on_time
)
SELECT
    CASE
        WHEN on_time = 1 AND seller_handoff_late = 0 THEN 'On time'
        WHEN on_time = 1 AND seller_handoff_late = 1 THEN 'On time despite late seller handoff'
        WHEN on_time = 0 AND seller_handoff_late = 1 THEN 'Late - seller handed off late'
        ELSE                                              'Late - seller on time, transit missed'
    END                                                   AS outcome,
    COUNT(*)                                              AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_orders
FROM order_handoff
GROUP BY 1
ORDER BY 1;
