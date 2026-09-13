-- E-Commerce Customer Growth Analytics
-- Complete retention, RFM and cohort analysis
-- MySQL 8

USE analytics;

-- ============================================================
-- 1. RFM BASE METRICS
-- ============================================================
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

-- ============================================================
-- 2. RFM QUINTILE SCORING
-- Recency is reversed: lower recency = better score.
-- Frequency and monetary are higher-is-better.
-- ============================================================
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

-- ============================================================
-- 3. BUSINESS-FRIENDLY RFM SEGMENTS
-- ============================================================
DROP TABLE IF EXISTS customer_rfm_segments_v2;
CREATE TABLE customer_rfm_segments_v2 AS
SELECT
    customer_unique_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        WHEN f_score = 1 AND m_score >= 4 THEN 'High-Value One-Time'
        ELSE 'Other'
    END AS customer_segment
FROM customer_rfm_scored;

-- ============================================================
-- 4. RFM SEGMENT SUMMARY
-- ============================================================
SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM customer_rfm_segments_v2), 2) AS customer_pct,
    ROUND(AVG(monetary), 2) AS avg_customer_value,
    ROUND(SUM(monetary), 2) AS segment_revenue,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(recency), 2) AS avg_recency_days
FROM customer_rfm_segments_v2
GROUP BY customer_segment
ORDER BY segment_revenue DESC;

-- ============================================================
-- 5. CATEGORY-LEVEL REPEAT RATE
-- ============================================================
DROP TABLE IF EXISTS category_retention_analysis;
CREATE TABLE category_retention_analysis AS
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS product_category_name,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(DISTINCT CASE
        WHEN cs.total_orders > 1 THEN c.customer_unique_id
    END) AS repeat_customers,
    ROUND(
        100 * COUNT(DISTINCT CASE
            WHEN cs.total_orders > 1 THEN c.customer_unique_id
        END)
        / COUNT(DISTINCT c.customer_unique_id),
        2
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

-- Category ranking with a minimum customer base.
SELECT
    product_category_name,
    customers,
    repeat_customers,
    repeat_rate
FROM category_retention_analysis
WHERE customers >= 100
ORDER BY repeat_rate DESC;

-- ============================================================
-- 6. CUSTOMER RETENTION DRIVER TABLE
-- ============================================================
DROP TABLE IF EXISTS customer_retention_analysis;
CREATE TABLE customer_retention_analysis AS
SELECT
    cfo.customer_unique_id,
    cfo.order_id AS first_order_id,
    cfo.purchase_date AS first_purchase_date,
    cfo.gross_order_value AS first_order_value,
    cfo.product_revenue AS first_product_revenue,
    cfo.freight_revenue AS first_freight_revenue,
    cfo.item_count AS first_item_count,
    cfo.unique_product_count AS first_unique_products,
    cfo.unique_seller_count AS first_unique_sellers,
    cfo.avg_review_score AS first_review_score,
    cfo.delivery_days AS first_delivery_days,
    cfo.delivery_delay_days AS first_delivery_delay_days,
    cs.total_orders,
    CASE WHEN cs.total_orders > 1 THEN 'Repeat' ELSE 'One-Time' END AS customer_type
FROM customer_first_order cfo
JOIN customer_summary cs
    ON cs.customer_unique_id = cfo.customer_unique_id;

-- ============================================================
-- 7. FIRST-ORDER VALUE BANDS
-- ============================================================
SELECT
    CASE
        WHEN first_order_value < 100 THEN '<100'
        WHEN first_order_value < 250 THEN '100-249'
        WHEN first_order_value < 500 THEN '250-499'
        WHEN first_order_value < 1000 THEN '500-999'
        ELSE '1000+'
    END AS first_order_value_band,
    COUNT(*) AS customers,
    SUM(total_orders > 1) AS repeat_customers,
    ROUND(100 * SUM(total_orders > 1) / COUNT(*), 2) AS repeat_rate
FROM customer_retention_analysis
GROUP BY first_order_value_band
ORDER BY MIN(first_order_value);

-- ============================================================
-- 8. CUSTOMER COHORT ASSIGNMENT
-- ============================================================
DROP TABLE IF EXISTS customer_cohort;
CREATE TABLE customer_cohort AS
SELECT
    customer_unique_id,
    first_purchase_date,
    DATE_FORMAT(first_purchase_date, '%Y-%m-01') AS cohort_month
FROM customer_summary;

-- ============================================================
-- 9. MONTHLY COHORT ACTIVITY
-- ============================================================
DROP TABLE IF EXISTS customer_cohort_activity;
CREATE TABLE customer_cohort_activity AS
SELECT DISTINCT
    co.customer_unique_id,
    co.cohort_month,
    DATE_FORMAT(cos.purchase_date, '%Y-%m-01') AS purchase_month,
    TIMESTAMPDIFF(
        MONTH,
        STR_TO_DATE(CONCAT(co.cohort_month, '-01'), '%Y-%m-%d'),
        STR_TO_DATE(
            CONCAT(DATE_FORMAT(cos.purchase_date, '%Y-%m-01'), '-01'),
            '%Y-%m-%d'
        )
    ) AS cohort_month_number
FROM customer_cohort co
JOIN customer_order_summary cos
    ON cos.customer_unique_id = co.customer_unique_id;

-- ============================================================
-- 10. FINAL COHORT RETENTION TABLE
-- ============================================================
DROP TABLE IF EXISTS cohort_retention_final;
CREATE TABLE cohort_retention_final AS
WITH cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
),
activity AS (
    SELECT
        cohort_month,
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

-- ============================================================
-- 11. COHORT MONTH-0 VALIDATION
-- Expected result: 100% for every cohort.
-- ============================================================
SELECT
    cohort_month,
    cohort_size,
    active_customers,
    retention_rate
FROM cohort_retention_final
WHERE cohort_month_number = 0
ORDER BY cohort_month;

-- ============================================================
-- 12. MONTH-1 RETENTION BENCHMARK
-- ============================================================
SELECT
    cohort_month,
    cohort_size,
    active_customers,
    retention_rate
FROM cohort_retention_final
WHERE cohort_month_number = 1
ORDER BY cohort_month;

-- ============================================================
-- 13. WEIGHTED RETENTION BY MONTH NUMBER
-- ============================================================
SELECT
    cohort_month_number,
    SUM(active_customers) AS active_customers,
    SUM(cohort_size) AS cohort_base,
    ROUND(100 * SUM(active_customers) / SUM(cohort_size), 2) AS weighted_retention_rate
FROM cohort_retention_final
GROUP BY cohort_month_number
ORDER BY cohort_month_number;

-- ============================================================
-- 14. RETENTION DATA QUALITY CHECKS
-- ============================================================
SELECT COUNT(*) AS invalid_month0_rows
FROM cohort_retention_final
WHERE cohort_month_number = 0
  AND ABS(retention_rate - 100) > 0.01;

SELECT COUNT(*) AS negative_cohort_month_numbers
FROM cohort_retention_final
WHERE cohort_month_number < 0;

SELECT COUNT(*) AS duplicate_cohort_activity_rows
FROM (
    SELECT customer_unique_id, purchase_month
    FROM customer_cohort_activity
    GROUP BY customer_unique_id, purchase_month
    HAVING COUNT(*) > 1
) x;
