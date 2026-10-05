-- 04_lead_time_distribution_by_state.sql
-- Business question: which customer regions wait longest, and how unpredictable is the wait?
-- Averages hide the tail, so this reports the median (P50) and P90 lead time per state.
-- Techniques: QUANTILE_CONT for percentiles, HAVING to drop states with too few orders.

SELECT
    customer_state,
    COUNT(*)                                         AS delivered_orders,
    ROUND(QUANTILE_CONT(lead_time_days, 0.5), 1)     AS p50_lead_time_days,
    ROUND(QUANTILE_CONT(lead_time_days, 0.9), 1)     AS p90_lead_time_days,
    ROUND(100.0 * AVG(on_time), 1)                   AS on_time_pct
FROM delivered_orders
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY p90_lead_time_days DESC;
