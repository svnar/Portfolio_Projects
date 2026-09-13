# Python Analysis

Python is used as a supporting analytical layer alongside MySQL and Power BI.

## Scope

The Python workflow covers:

1. MySQL connection and order-level extraction
2. Delivered-order filtering
3. Monthly order, customer and revenue trends
4. Customer lifecycle classification
5. Customer value and value-band analysis
6. Frequency-versus-value correlation
7. Retention-driver statistical testing
8. Cohort-retention validation
9. Reproducible console summaries

## Scripts

- `01_customer_growth_analysis.py` — extracts delivered order data from MySQL and calculates monthly growth, customer lifecycle, value bands and frequency/value correlation.
- `02_retention_statistical_analysis.py` — applies Mann-Whitney U and chi-square/Cramer's V tests to retention drivers and reports effect-size-aware results.

## Dependencies

```text
pandas
mysql-connector-python
scipy
```

Install with:

```bash
pip install -r requirements.txt
```

## Configuration

Database credentials are supplied through environment variables:

```text
MYSQL_HOST
MYSQL_PORT
MYSQL_USER
MYSQL_PASSWORD
```

No credentials are stored in the repository.

## Analytical Outputs

The analysis supports the dashboard and business recommendations with metrics including delivered orders, delivered customers, revenue, AOV, repeat rate, customer value bands, lifecycle metrics, correlation and retention-driver tests.

The underlying project analysis found 96,478 delivered orders, 93,358 delivered customers, approximately 15.42M delivered gross order value and an overall repeat customer rate of about 3%.
