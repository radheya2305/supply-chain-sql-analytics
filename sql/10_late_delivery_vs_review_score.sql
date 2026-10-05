-- 10_late_delivery_vs_review_score.sql
-- Business question: what does a late delivery cost us in customer satisfaction?
-- Buckets each delivered order by how early/late it arrived and compares review scores.

WITH order_review AS (
    SELECT d.order_id, d.days_late, AVG(r.review_score) AS review_score
    FROM delivered_orders d
    JOIN reviews r USING (order_id)
    GROUP BY d.order_id, d.days_late
)
SELECT
    CASE
        WHEN days_late <= 0  THEN '1. On time or early'
        WHEN days_late <= 3  THEN '2. 1-3 days late'
        WHEN days_late <= 7  THEN '3. 4-7 days late'
        WHEN days_late <= 14 THEN '4. 8-14 days late'
        ELSE                      '5. 15+ days late'
    END                                                     AS delivery_bucket,
    COUNT(*)                                                AS orders,
    ROUND(AVG(review_score), 2)                             AS avg_review_score,
    ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END), 1) AS pct_1_or_2_star
FROM order_review
GROUP BY 1
ORDER BY 1;
