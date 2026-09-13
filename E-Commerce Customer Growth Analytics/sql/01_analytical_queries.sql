-- E-Commerce Customer Growth Analytics
-- MySQL 8 analytical SQL for the Olist Brazilian E-Commerce Public Dataset.
-- Raw data inserts are intentionally excluded.

USE analytics;

-- 1. Order item summary
DROP TABLE IF EXISTS order_item_summary;
CREATE TABLE order_item_summary AS
SELECT
    oi.order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT oi.product_id) AS unique_product_count,
    COUNT(DISTINCT oi.seller_id) AS unique_seller_count,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_revenue,
    SUM(oi.price + oi.freight_value) AS gross_order_value
FROM ecommerce_customer_analytics.olist_order_items oi
GROUP BY oi.order_id;

-- 2. Payment summary
DROP TABLE IF EXISTS order_payment_summary;
CREATE TABLE order_payment_summary AS
SELECT order_id,
       COUNT(*) AS payment_count,
       SUM(payment_value) AS payment_value,
       COUNT(DISTINCT payment_type) AS payment_type_count
FROM ecommerce_customer_analytics.olist_order_payments
GROUP BY order_id;

-- 3. Review summary
DROP TABLE IF EXISTS order_review_summary;
CREATE TABLE order_review_summary AS
SELECT order_id,
       COUNT(*) AS review_count,
       AVG(review_score) AS avg_review_score,
       MIN(review_score) AS min_review_score,
       MAX(review_score) AS max_review_score
FROM ecommerce_customer_analytics.olist_order_reviews
GROUP BY order_id;

-- 4. Order-level analytical summary
DROP TABLE IF EXISTS order_summary;
CREATE TABLE order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    DATE(o.order_purchase_timestamp) AS purchase_date,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    COALESCE(i.item_count,0) AS item_count,
    COALESCE(i.unique_product_count,0) AS unique_product_count,
    COALESCE(i.unique_seller_count,0) AS unique_seller_count,
    COALESCE(i.product_revenue,0) AS product_revenue,
    COALESCE(i.freight_revenue,0) AS freight_revenue,
    COALESCE(i.gross_order_value,0) AS gross_order_value,
    COALESCE(p.payment_count,0) AS payment_count,
    COALESCE(p.payment_value,0) AS payment_value,
    COALESCE(r.review_count,0) AS review_count,
    r.avg_review_score,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN DATEDIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp)) END AS delivery_days,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN DATEDIFF(DATE(o.order_delivered_customer_date), DATE(o.order_estimated_delivery_date)) END AS delivery_delay_days
FROM ecommerce_customer_analytics.olist_orders o
LEFT JOIN order_item_summary i ON i.order_id = o.order_id
LEFT JOIN order_payment_summary p ON p.order_id = o.order_id
LEFT JOIN order_review_summary r ON r.order_id = o.order_id;

-- 5. Delivered customer-order analytical layer
DROP TABLE IF EXISTS customer_order_summary;
CREATE TABLE customer_order_summary AS
SELECT
    c.customer_unique_id,
    o.order_id,
    o.customer_id,
    o.purchase_date,
    o.product_revenue,
    o.freight_revenue,
    o.gross_order_value,
    o.item_count,
    o.unique_product_count,
    o.unique_seller_count,
    o.payment_value,
    o.payment_count,
    o.avg_review_score,
    o.delivery_days,
    o.delivery_delay_days
FROM order_summary o
JOIN ecommerce_customer_analytics.olist_customers c
  ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';

-- 6. Customer-level summary
DROP TABLE IF EXISTS customer_summary;
CREATE TABLE customer_summary AS
SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id) AS total_orders,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,
    DATEDIFF(MAX(purchase_date), MIN(purchase_date)) AS customer_lifetime_days,
    SUM(product_revenue) AS total_product_revenue,
    SUM(freight_revenue) AS total_freight_revenue,
    SUM(gross_order_value) AS total_customer_value,
    AVG(gross_order_value) AS average_order_value,
    SUM(item_count) AS total_items,
    AVG(avg_review_score) AS average_review_score,
    AVG(delivery_days) AS average_delivery_days,
    AVG(delivery_delay_days) AS average_delivery_delay_days
FROM customer_order_summary
GROUP BY customer_unique_id;

-- 7. First delivered order per customer
DROP TABLE IF EXISTS customer_first_order;
CREATE TABLE customer_first_order AS
WITH ranked_orders AS (
    SELECT cos.*,
           ROW_NUMBER() OVER (
               PARTITION BY customer_unique_id
               ORDER BY purchase_date, order_id
           ) AS rn
    FROM customer_order_summary cos
)
SELECT customer_unique_id, order_id, purchase_date,
       gross_order_value, product_revenue, freight_revenue,
       item_count, unique_product_count, unique_seller_count,
       avg_review_score, delivery_days, delivery_delay_days
FROM ranked_orders
WHERE rn = 1;

-- 8. Customer type and repeat-rate validation
SELECT
    CASE WHEN total_orders = 1 THEN 'One-Time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    AVG(total_orders) AS avg_orders,
    AVG(total_customer_value) AS avg_customer_value
FROM customer_summary
GROUP BY customer_type;

SELECT COUNT(*) AS total_customers,
       SUM(total_orders > 1) AS repeat_customers,
       ROUND(100 * SUM(total_orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM customer_summary;

-- 9. Customer value bands
SELECT
    CASE
        WHEN total_customer_value < 100 THEN '<100'
        WHEN total_customer_value < 250 THEN '100-249'
        WHEN total_customer_value < 500 THEN '250-499'
        WHEN total_customer_value < 1000 THEN '500-999'
        ELSE '1000+'
    END AS value_band,
    COUNT(*) AS customers,
    SUM(total_customer_value) AS total_revenue,
    AVG(total_customer_value) AS average_customer_value
FROM customer_summary
GROUP BY value_band
ORDER BY MIN(total_customer_value);
