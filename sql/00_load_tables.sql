-- 00_load_tables.sql
-- Loads the raw Olist CSV files into tables and builds one cleaned view
-- that every later query uses. Run from the project root.

CREATE OR REPLACE TABLE orders      AS SELECT * FROM read_csv_auto('data/olist_orders_dataset.csv');
CREATE OR REPLACE TABLE order_items AS SELECT * FROM read_csv_auto('data/olist_order_items_dataset.csv');
CREATE OR REPLACE TABLE products    AS SELECT * FROM read_csv_auto('data/olist_products_dataset.csv');
CREATE OR REPLACE TABLE sellers     AS SELECT * FROM read_csv_auto('data/olist_sellers_dataset.csv');
CREATE OR REPLACE TABLE customers   AS SELECT * FROM read_csv_auto('data/olist_customers_dataset.csv');
CREATE OR REPLACE TABLE reviews     AS SELECT * FROM read_csv_auto('data/olist_order_reviews_dataset.csv');
CREATE OR REPLACE TABLE category_translation AS
    SELECT * FROM read_csv_auto('data/product_category_name_translation.csv');

-- Delivered orders only, with the delivery metrics computed once.
-- On time = delivered on or before the date promised to the customer.
-- Window: Jan 2017 to Aug 2018 (2016 and Sep-Oct 2018 have too few orders to trust).
CREATE OR REPLACE VIEW delivered_orders AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    DATE_TRUNC('month', o.order_purchase_timestamp)                         AS order_month,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATE_DIFF('day', o.order_purchase_timestamp, o.order_delivered_customer_date) AS lead_time_days,
    DATE_DIFF('day', CAST(o.order_estimated_delivery_date AS DATE),
                     CAST(o.order_delivered_customer_date AS DATE))         AS days_late,
    CASE WHEN CAST(o.order_delivered_customer_date AS DATE)
              <= CAST(o.order_estimated_delivery_date AS DATE) THEN 1 ELSE 0 END AS on_time
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
  AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01';
