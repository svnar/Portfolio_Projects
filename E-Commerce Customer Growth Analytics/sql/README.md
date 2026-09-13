# SQL Analysis

This folder contains the core SQL analysis used to build the analytical layer for the E-Commerce Customer Growth Analytics project.

## Files

- `01_analytical_queries.sql` — order, payment, review, customer and first-order analytical layers plus customer lifecycle and value-band analysis.
- `02_retention_rfm_cohort.sql` — RFM metrics/scoring, category-level repeat analysis and cohort retention analysis.
- `03_business_kpi_queries.sql` — business KPI validation, segment summaries, category rankings and data-quality checks.

## Analytical workflow

1. Aggregate order items into order-level revenue and fulfillment metrics.
2. Aggregate payments and reviews to order level.
3. Combine order, item, payment and review data into an analytical order layer.
4. Restrict customer-retention analysis to delivered orders.
5. Build customer-level lifetime value, frequency and lifecycle metrics.
6. Identify first orders and classify one-time versus repeat customers.
7. Calculate RFM metrics and quintile scores.
8. Measure repeat behavior by product category.
9. Assign customers to acquisition cohorts and calculate month-over-month retention.
10. Validate the resulting KPIs before Power BI reporting.

The scripts use MySQL 8 and the Olist Brazilian E-Commerce Public Dataset. Raw data inserts are intentionally excluded from the repository.