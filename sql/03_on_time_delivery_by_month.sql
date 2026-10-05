-- 03_on_time_delivery_by_month.sql
-- Business question: are we keeping our delivery promise, and is it getting better or worse?
-- On time = delivered on or before the estimated delivery date shown to the customer.

SELECT
    CAST(order_month AS DATE)                        AS order_month,
    COUNT(*)                                         AS delivered_orders,
    CAST(SUM(on_time) AS INTEGER)                    AS on_time_orders,
    ROUND(100.0 * AVG(on_time), 1)                   AS on_time_pct,
    ROUND(AVG(lead_time_days), 1)                    AS avg_lead_time_days,
    ROUND(AVG(CASE WHEN days_late > 0 THEN days_late END), 1) AS avg_days_late_when_late
FROM delivered_orders
GROUP BY 1
ORDER BY 1;
