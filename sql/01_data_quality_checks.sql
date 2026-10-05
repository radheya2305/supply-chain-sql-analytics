-- 01_data_quality_checks.sql
-- Business question: can we trust this data before we analyze it?
-- Checks row counts, order status mix, missing delivery dates, and impossible timestamps.

SELECT 'orders: total rows' AS check_name, COUNT(*) AS value FROM orders
UNION ALL
SELECT 'orders: duplicate order_id', COUNT(*) - COUNT(DISTINCT order_id) FROM orders
UNION ALL
SELECT 'orders: status = delivered', COUNT(*) FROM orders WHERE order_status = 'delivered'
UNION ALL
SELECT 'delivered but no delivery date', COUNT(*) FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT 'delivered before purchase (bad timestamp)', COUNT(*) FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp
UNION ALL
SELECT 'handed to carrier before approval (bad timestamp)', COUNT(*) FROM orders
WHERE order_delivered_carrier_date < order_approved_at
UNION ALL
SELECT 'order_items: rows', COUNT(*) FROM order_items
UNION ALL
SELECT 'products with no category', COUNT(*) FROM products WHERE product_category_name IS NULL
UNION ALL
SELECT 'delivered orders in analysis window (Jan 2017 - Aug 2018)', COUNT(*) FROM delivered_orders;
