-- E-Commerce Customer Growth Analytics
-- Business KPI, segmentation, retention and data-quality queries
-- MySQL 8

USE analytics;

-- ============================================================
-- 1. EXECUTIVE KPI SUMMARY
-- ============================================================
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(SUM(freight_revenue), 2) AS freight_revenue,
    ROUND(SUM(gross_order_value), 2) AS gross_order_value,
    ROUND(AVG(gross_order_value), 2) AS average_order_value
FROM order_summary
WHERE order_status = 'delivered';

-- ============================================================
-- 2. ORDER STATUS DISTRIBUTION
-- ============================================================
SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM order_summary), 2) AS order_pct
FROM order_summary
GROUP BY order_status
ORDER BY orders DESC;

-- ============================================================
-- 3. CUSTOMER LIFECYCLE SUMMARY
-- ============================================================
SELECT
    CASE WHEN total_orders = 1 THEN 'One-Time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(AVG(total_orders), 2) AS avg_orders,
    ROUND(AVG(total_customer_value), 2) AS avg_customer_value,
    ROUND(AVG(customer_lifetime_days), 2) AS avg_lifetime_days,
    ROUND(SUM(total_customer_value), 2) AS customer_revenue
FROM customer_summary
GROUP BY customer_type;

-- ============================================================
-- 4. OVERALL CUSTOMER RETENTION KPI
-- ============================================================
SELECT
    COUNT(*) AS total_customers,
    SUM(total_orders > 1) AS repeat_customers,
    SUM(total_orders = 1) AS one_time_customers,
    ROUND(100 * SUM(total_orders > 1) / COUNT(*), 2) AS repeat_rate_pct,
    ROUND(AVG(total_orders), 2) AS orders_per_customer
FROM customer_summary;

-- ============================================================
-- 5. CUSTOMER VALUE DISTRIBUTION
-- ============================================================
SELECT
    CASE
        WHEN total_customer_value < 100 THEN '<100'
        WHEN total_customer_value < 250 THEN '100-249'
        WHEN total_customer_value < 500 THEN '250-499'
        WHEN total_customer_value < 1000 THEN '500-999'
        ELSE '1000+'
    END AS value_band,
    COUNT(*) AS customers,
    ROUND(SUM(total_customer_value), 2) AS revenue,
    ROUND(AVG(total_customer_value), 2) AS avg_customer_value
FROM customer_summary
GROUP BY value_band
ORDER BY MIN(total_customer_value);

-- ============================================================
-- 6. RFM SEGMENT DISTRIBUTION
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
-- 7. CATEGORY RETENTION RANKING
-- ============================================================
SELECT
    product_category_name,
    customers,
    repeat_customers,
    repeat_rate
FROM category_retention_analysis
WHERE customers >= 100
ORDER BY repeat_rate DESC;

-- ============================================================
-- 8. TOP CATEGORIES BY REPEAT CUSTOMER COUNT
-- ============================================================
SELECT
    product_category_name,
    customers,
    repeat_customers,
    repeat_rate
FROM category_retention_analysis
WHERE customers >= 100
ORDER BY repeat_customers DESC
LIMIT 20;

-- ============================================================
-- 9. MONTHLY DELIVERED PERFORMANCE
-- ============================================================
SELECT
    DATE_FORMAT(purchase_date, '%Y-%m-01') AS order_month,
    COUNT(DISTINCT order_id) AS delivered_orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    ROUND(SUM(gross_order_value), 2) AS revenue,
    ROUND(AVG(gross_order_value), 2) AS average_order_value
FROM customer_order_summary
GROUP BY DATE_FORMAT(purchase_date, '%Y-%m-01')
ORDER BY order_month;

-- ============================================================
-- 10. MONTHLY NEW VS REPEAT CUSTOMER MIX
-- ============================================================
WITH customer_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        purchase_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY purchase_date, order_id
        ) AS order_number
    FROM customer_order_summary
)
SELECT
    DATE_FORMAT(purchase_date, '%Y-%m-01') AS order_month,
    CASE WHEN order_number = 1 THEN 'One-Time/New' ELSE 'Repeat' END AS customer_order_type,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM customer_orders
GROUP BY
    DATE_FORMAT(purchase_date, '%Y-%m-01'),
    CASE WHEN order_number = 1 THEN 'One-Time/New' ELSE 'Repeat' END
ORDER BY order_month, customer_order_type;

-- ============================================================
-- 11. DELIVERY PERFORMANCE
-- ============================================================
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(delivery_delay_days), 2) AS avg_delivery_delay_days,
    SUM(delivery_delay_days > 0) AS delayed_orders,
    ROUND(100 * SUM(delivery_delay_days > 0) / COUNT(*), 2) AS delayed_order_pct
FROM order_summary
WHERE order_status = 'delivered';

-- ============================================================
-- 12. REVIEW PERFORMANCE
-- ============================================================
SELECT
    ROUND(AVG(avg_review_score), 2) AS average_review_score,
    COUNT(*) AS reviewed_orders,
    SUM(avg_review_score <= 2) AS low_review_orders,
    ROUND(100 * SUM(avg_review_score <= 2) / COUNT(*), 2) AS low_review_pct
FROM order_summary
WHERE order_status = 'delivered'
  AND avg_review_score IS NOT NULL;

-- ============================================================
-- 13. COHORT RETENTION BENCHMARK
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
-- 14. MONTH-1 COHORT RETENTION
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
-- 15. RFM SEGMENTS REQUIRING ATTENTION
-- ============================================================
SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(SUM(monetary), 2) AS revenue,
    ROUND(AVG(monetary), 2) AS avg_customer_value
FROM customer_rfm_segments_v2
WHERE customer_segment IN ('At Risk', 'Hibernating', 'High-Value One-Time')
GROUP BY customer_segment
ORDER BY revenue DESC;

-- ============================================================
-- 16. DATA QUALITY: DUPLICATE CUSTOMER ROWS
-- ============================================================
SELECT COUNT(*) AS duplicate_customer_rows
FROM (
    SELECT customer_unique_id
    FROM customer_summary
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) x;

-- ============================================================
-- 17. DATA QUALITY: COHORT MONTH-0 VALIDATION
-- Expected: zero invalid rows.
-- ============================================================
SELECT COUNT(*) AS invalid_cohort_month0_rows
FROM cohort_retention_final
WHERE cohort_month_number = 0
  AND ABS(retention_rate - 100) > 0.01;

-- ============================================================
-- 18. DATA QUALITY: NEGATIVE VALUES
-- ============================================================
SELECT COUNT(*) AS negative_order_values
FROM order_summary
WHERE gross_order_value < 0;

SELECT COUNT(*) AS negative_customer_values
FROM customer_summary
WHERE total_customer_value < 0;

-- ============================================================
-- 19. DATA QUALITY: DELIVERED ORDER COMPLETENESS
-- ============================================================
SELECT
    COUNT(*) AS delivered_orders,
    SUM(purchase_date IS NULL) AS missing_purchase_dates,
    SUM(gross_order_value IS NULL) AS missing_order_values
FROM order_summary
WHERE order_status = 'delivered';
