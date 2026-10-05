-- 11_freight_cost_by_region.sql
-- Business question: where is freight eating into margin?
-- Freight as a share of item price, by customer region (Brazil's five macro-regions).

WITH region_map AS (
    SELECT * FROM (VALUES
        ('SP','Southeast'),('RJ','Southeast'),('MG','Southeast'),('ES','Southeast'),
        ('PR','South'),('SC','South'),('RS','South'),
        ('DF','Center-West'),('GO','Center-West'),('MT','Center-West'),('MS','Center-West'),
        ('BA','Northeast'),('PE','Northeast'),('CE','Northeast'),('MA','Northeast'),('PB','Northeast'),
        ('RN','Northeast'),('AL','Northeast'),('SE','Northeast'),('PI','Northeast'),
        ('PA','North'),('AM','North'),('RO','North'),('TO','North'),('AP','North'),('AC','North'),('RR','North')
    ) AS t(state, region)
)
SELECT
    rm.region,
    COUNT(*)                                             AS items,
    ROUND(AVG(oi.price), 2)                              AS avg_item_price,
    ROUND(AVG(oi.freight_value), 2)                      AS avg_freight,
    ROUND(100.0 * SUM(oi.freight_value) / SUM(oi.price), 1) AS freight_pct_of_price,
    ROUND(100.0 * AVG(d.on_time), 1)                     AS on_time_pct
FROM delivered_orders d
JOIN order_items oi USING (order_id)
JOIN region_map rm  ON rm.state = d.customer_state
GROUP BY rm.region
ORDER BY freight_pct_of_price DESC;
