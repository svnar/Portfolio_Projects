# E-Commerce Customer Growth Analytics

## Project Overview

An end-to-end customer growth, retention and revenue analytics project built using the **Olist Brazilian E-Commerce Public Dataset**.

The project combines **MySQL** for data preparation and analytical modeling, **Python** for exploratory and statistical analysis, and **Power BI** for interactive business reporting. The analysis focuses on revenue performance, customer acquisition, repeat behavior, RFM segmentation, cohort retention and category-level retention.

## Business Objective

The objective was to understand:

- How revenue and order activity evolved over time
- The balance between new and repeat customers
- How strongly customers return after their first purchase
- Which customer segments contribute the most value
- How retention changes across customer cohorts
- Which product categories show relatively stronger repeat behavior
- Which first-order characteristics are associated with repeat purchasing
- What practical actions could improve customer retention and lifetime value

## Tools & Technologies

- **MySQL 8** — data preparation, analytical tables and business queries
- **Python** — exploratory analysis and statistical retention-driver testing
- **Power BI** — dashboard, DAX measures and interactive visualization
- **SQL** — joins, aggregations, CTEs, window functions and cohort preparation
- **RFM Analysis** — customer segmentation using Recency, Frequency and Monetary behavior
- **Cohort Analysis** — first-purchase cohorts and subsequent-month retention
- **Statistical Testing** — Mann-Whitney U, Chi-square, Cramér's V and rank-biserial effect size

## Analytical Approach

The analysis follows a layered workflow:

1. Build order-item, payment and review summaries from the raw Olist tables.
2. Create an order-level analytical summary combining transaction, payment, review and delivery metrics.
3. Restrict customer-growth and retention analysis to **delivered orders**.
4. Aggregate delivered orders to the unique-customer level.
5. Classify customers as one-time or repeat and create customer value bands.
6. Calculate RFM scores and business-friendly customer segments.
7. Analyse repeat behavior by product category.
8. Build first-purchase cohorts and monthly cohort retention.
9. Use Python to test potential retention drivers and report effect sizes alongside statistical significance.
10. Present the results through a two-page Power BI dashboard and business recommendations.

## Dashboard

### 1. Executive Overview

Covers:
- Delivered revenue trend
- Delivered order trend
- Average order value trend
- Customer acquisition mix
- Monthly repeat customer rate
- RFM customer segmentation
- Executive KPI summary

### 2. Customer Retention

Covers:
- Customer value by RFM segment
- Repeat rate by product category
- Cohort retention heatmap

**Power BI file:** [`dashboard/Ecommerce_Customer_Growth_Analytics.pbix`](dashboard/Ecommerce_Customer_Growth_Analytics.pbix)

## Key Results

- **Delivered orders:** 96,478
- **Delivered customers:** 93,358
- **Delivered product revenue:** 13.22M
- **Delivered freight revenue:** 2.20M
- **Delivered gross order value:** 15.42M
- **Delivered AOV:** 159.83
- **Overall repeat customer rate:** approximately 3%
- **Orders per delivered customer:** approximately 1.03

## Key Business Insights

### 1. Retention is the largest growth opportunity

The overall delivered repeat-customer rate is only about **3%**, while the average delivered customer places approximately **1.03 orders**. This indicates that the business is heavily dependent on first-time purchases rather than repeat purchasing.

### 2. A large high-value one-time customer pool exists

The **High-Value One-Time** segment contains 21,623 customers and contributes approximately **7.33M** in customer value. This is a major reactivation opportunity: these customers have already demonstrated willingness to spend but have not returned.

### 3. Champions and loyal customers are comparatively more engaged

Champions show a substantially higher repeat rate than the overall customer base. These customers should be protected through retention-oriented experiences rather than treated like the broader acquisition audience.

### 4. Customer value is concentrated

The lower-value customer bands contain the majority of customers, while a relatively small group of higher-value customers contributes a disproportionately large share of value. Customer lifecycle strategies should therefore be differentiated by value and engagement.

### 5. Cohort retention drops sharply after the first purchase

Cohort analysis validates 100% retention in month 0 by definition, but subsequent-month retention is very low across cohorts. This reinforces the need for a structured post-purchase retention journey.

### 6. Product category appears to matter, but not as a standalone explanation

Category-level repeat behavior varies considerably. Statistical testing found category to have the strongest association among the tested first-order retention drivers, although the effect size remains small. Category should therefore be treated as a useful segmentation variable rather than a causal explanation.

## Statistical Evidence

Python analysis was used to distinguish statistical significance from practical business importance.

- First-order value showed a statistically significant difference between repeat and one-time customers, but the effect size was very small.
- Delivery performance showed a statistically significant association with repeat status, but the effect size was very weak.
- First-order value bands were statistically associated with repeat status, but the effect size was very small.
- Review score grouping did not show statistically significant evidence of association.
- Product category showed the strongest association among the tested retention drivers, while the effect size remained small.

These results are exploratory and should be used to prioritize experiments rather than interpreted as causal evidence.

## Recommendations

1. **Build a first-to-second-order conversion program**
   - Trigger post-purchase communication shortly after delivery.
   - Introduce personalized product recommendations.
   - Use time-bound second-order incentives where economically justified.

2. **Prioritize High-Value One-Time customers**
   - Create a dedicated reactivation audience.
   - Recommend complementary products based on the first purchase.
   - Test targeted offers instead of blanket discounts.

3. **Protect Champions and Loyal Customers**
   - Introduce loyalty benefits, early access or personalized recommendations.
   - Monitor inactivity and intervene before customers become dormant.

4. **Use category behavior in retention campaigns**
   - Identify categories with stronger repeat behavior.
   - Promote cross-category recommendations for customers from weaker-repeat categories.
   - Test category-specific lifecycle campaigns.

5. **Improve post-delivery engagement**
   - Use delivery completion as a trigger for review requests, recommendations and second-purchase messaging.

6. **Measure retention as a core growth KPI**
   - Track repeat customer rate, second-order conversion, cohort retention and customer value alongside revenue and order volume.

## Analytical Caveat

The retention-driver tests show statistical associations, but several effect sizes are weak. Category-level analysis is particularly useful for segmentation and experimentation, but does not establish causality. The project therefore treats the findings as evidence for prioritizing business experiments rather than definitive causal conclusions.

## Project Structure

```text
E-Commerce Customer Growth Analytics/
├── README.md
├── business-insights-and-recommendations.md
├── sql/
│   ├── README.md
│   ├── 01_analytical_queries.sql
│   ├── 02_retention_rfm_cohort.sql
│   └── 03_business_kpi_queries.sql
├── python/
│   ├── README.md
│   ├── requirements.txt
│   ├── 01_customer_growth_analysis.py
│   └── 02_retention_statistical_analysis.py
└── dashboard/
    └── Ecommerce_Customer_Growth_Analytics.pbix
```

## SQL Analysis

The SQL layer documents the transformation from raw Olist order, payment, review, customer and product data into customer-level analytical datasets and business-facing analysis tables used by the dashboard.

- [`01_analytical_queries.sql`](sql/01_analytical_queries.sql) — analytical data layer, customer metrics and core validation
- [`02_retention_rfm_cohort.sql`](sql/02_retention_rfm_cohort.sql) — RFM, category retention, retention drivers and cohort analysis
- [`03_business_kpi_queries.sql`](sql/03_business_kpi_queries.sql) — executive KPIs, segmentation, trends and data-quality checks

## Python Analysis

The Python layer provides reproducible analysis outside the dashboard, including customer growth trends, lifecycle/value analysis and statistical testing of potential retention drivers.

- [`01_customer_growth_analysis.py`](python/01_customer_growth_analysis.py) — customer growth, lifecycle, value bands and frequency/value relationship
- [`02_retention_statistical_analysis.py`](python/02_retention_statistical_analysis.py) — retention-driver hypothesis testing and effect-size analysis
- [`requirements.txt`](python/requirements.txt) — Python dependencies

## Business Insights & Recommendations

Detailed findings, statistical evidence and recommended business actions are documented in [`business-insights-and-recommendations.md`](business-insights-and-recommendations.md).

## Dataset

**Olist Brazilian E-Commerce Public Dataset.** The raw dataset is not included in this repository. The SQL and Python scripts expect the source/analytical tables to be available locally and contain no credentials or raw customer data.
