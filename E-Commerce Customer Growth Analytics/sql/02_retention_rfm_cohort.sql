-- Retention, RFM and cohort analysis
-- MySQL 8

USE analytics;

-- 1. RFM base metrics
DROP TABLE IF EXISTS customer_rfm;
CREATE TABLE customer_rfm AS
SELECT
    customer_unique_id,
    DATEDIFF(
        (SELECT MAX(last_purchase_date) FROM customer_summary),
        last_purchase_date
    ) AS recency,
    total_orders AS frequency,
    total_customer_value AS monetary
FROM customer_summary;

-- 2. RFM quintile scores
DROP TABLE IF EXISTS customer_rfm_scored;
CREATE TABLE customer_rfm_scored AS
WITH scored AS (
    SELECT
        customer_unique_id,
        recency,
        frequency,
        monetary,
        6 - NTILE(5) OVER (ORDER BY recency) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
)
SELECT
    customer_unique_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score
FROM scored;

-- 3. Category-level repeat rate
DROP TABLE IF EXISTS category_retention_analysis;
CREATE TABLE category_retention_analysis AS
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS product_category_name,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(DISTINCT CASE WHEN cs.total_orders > 1 THEN c.customer_unique_id END) AS repeat_customers,
    ROUND(
        100 * COUNT(DISTINCT CASE WHEN cs.total_orders > 1 THEN c.customer_unique_id END)
        / COUNT(DISTINCT c.customer_unique_id), 2
    ) AS repeat_rate
FROM ecommerce_customer_analytics.olist_order_items oi
JOIN ecommerce_customer_analytics.olist_orders o
  ON o.order_id = oi.order_id
JOIN ecommerce_customer_analytics.olist_customers c
  ON c.customer_id = o.customer_id
JOIN customer_summary cs
  ON cs.customer_unique_id = c.customer_unique_id
LEFT JOIN ecommerce_customer_analytics.olist_products p
  ON p.product_id = oi.product_id
LEFT JOIN ecommerce_customer_analytics.product_category_translation t
  ON t.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name);

-- 4. Customer cohort assignment
DROP TABLE IF EXISTS customer_cohort;
CREATE TABLE customer_cohort AS
SELECT
    customer_unique_id,
    first_purchase_date,
    DATE_FORMAT(first_purchase_date, '%Y-%m-01') AS cohort_month
FROM customer_summary;

-- 5. Monthly cohort activity
DROP TABLE IF EXISTS customer_cohort_activity;
CREATE TABLE customer_cohort_activity AS
SELECT DISTINCT
    co.customer_unique_id,
    co.cohort_month,
    DATE_FORMAT(cos.purchase_date, '%Y-%m-01') AS purchase_month,
    TIMESTAMPDIFF(
        MONTH,
        STR_TO_DATE(CONCAT(co.cohort_month, '-01'), '%Y-%m-%d'),
        STR_TO_DATE(CONCAT(DATE_FORMAT(cos.purchase_date, '%Y-%m-01'), '-01'), '%Y-%m-%d')
    ) AS cohort_month_number
FROM customer_cohort co
JOIN customer_order_summary cos
  ON cos.customer_unique_id = co.customer_unique_id;

-- 6. Final cohort retention table
DROP TABLE IF EXISTS cohort_retention_final;
CREATE TABLE cohort_retention_final AS
WITH cohort_sizes AS (
    SELECT cohort_month,
           COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
),
activity AS (
    SELECT cohort_month,
           cohort_month_number,
           COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_cohort_activity
    GROUP BY cohort_month, cohort_month_number
)
SELECT
    a.cohort_month,
    a.cohort_month_number,
    a.active_customers,
    cs.cohort_size,
    ROUND(100 * a.active_customers / cs.cohort_size, 2) AS retention_rate
FROM activity a
JOIN cohort_sizes cs
  ON cs.cohort_month = a.cohort_month
ORDER BY a.cohort_month, a.cohort_month_number;

-- 7. Cohort month-0 validation: should be 100% for each cohort.
SELECT cohort_month, cohort_size, active_customers, retention_rate
FROM cohort_retention_final
WHERE cohort_month_number = 0
ORDER BY cohort_month;

-- 8. Month-1 retention benchmark
SELECT
    cohort_month,
    cohort_size,
    active_customers,
    retention_rate
FROM cohort_retention_final
WHERE cohort_month_number = 1
ORDER BY cohort_month;
