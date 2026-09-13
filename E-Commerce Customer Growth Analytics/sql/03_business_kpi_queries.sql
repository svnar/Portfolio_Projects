-- Business KPI and validation queries
-- MySQL 8

USE analytics;

-- Delivered-order KPI summary
SELECT
    COUNT(*) AS delivered_orders,
    SUM(product_revenue) AS product_revenue,
    SUM(freight_revenue) AS freight_revenue,
    SUM(gross_order_value) AS gross_order_value,
    ROUND(AVG(gross_order_value), 2) AS average_order_value
FROM order_summary
WHERE order_status = 'delivered';

-- Customer lifecycle summary
SELECT
    CASE WHEN total_orders = 1 THEN 'One-Time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(AVG(total_orders), 2) AS avg_orders,
    ROUND(AVG(total_customer_value), 2) AS avg_customer_value,
    ROUND(AVG(customer_lifetime_days), 2) AS avg_lifetime_days
FROM customer_summary
GROUP BY customer_type;

-- RFM segment distribution after the segment table has been created.
SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_customer_value,
    SUM(monetary) AS segment_revenue
FROM customer_rfm_segments_v2
GROUP BY customer_segment
ORDER BY segment_revenue DESC;

-- Category retention ranking
SELECT
    product_category_name,
    customers,
    repeat_customers,
    repeat_rate
FROM category_retention_analysis
WHERE customers >= 100
ORDER BY repeat_rate DESC;

-- Overall cohort retention benchmark
SELECT
    cohort_month_number,
    SUM(active_customers) AS active_customers,
    SUM(cohort_size) AS cohort_base,
    ROUND(100 * SUM(active_customers) / SUM(cohort_size), 2) AS weighted_retention_rate
FROM cohort_retention_final
GROUP BY cohort_month_number
ORDER BY cohort_month_number;

-- Data-quality checks
SELECT COUNT(*) AS duplicate_customer_rows
FROM (
    SELECT customer_unique_id
    FROM customer_summary
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) x;

SELECT COUNT(*) AS invalid_cohort_month0_rows
FROM cohort_retention_final
WHERE cohort_month_number = 0
  AND ABS(retention_rate - 100) > 0.01;
