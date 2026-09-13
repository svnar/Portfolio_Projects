"""Customer Growth Analysis - Olist E-Commerce project.

This script reproduces the Python analysis used alongside the MySQL analytical
layer. Credentials are read from environment variables; no secrets belong in
this repository.

Environment variables:
    MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD
"""

import os
import pandas as pd
import mysql.connector
from scipy.stats import spearmanr


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": "ecommerce_customer_analytics",
}


ORDER_QUERY = """
SELECT
    o.order_id,
    c.customer_unique_id,
    DATE(o.order_purchase_timestamp) AS purchase_date,
    o.order_status,
    COALESCE(SUM(oi.price), 0) AS product_revenue,
    COALESCE(SUM(oi.freight_value), 0) AS freight_revenue,
    COALESCE(SUM(oi.price + oi.freight_value), 0) AS gross_order_value
FROM olist_orders o
JOIN olist_customers c
    ON c.customer_id = o.customer_id
LEFT JOIN olist_order_items oi
    ON oi.order_id = o.order_id
GROUP BY
    o.order_id,
    c.customer_unique_id,
    DATE(o.order_purchase_timestamp),
    o.order_status
"""


def load_orders() -> pd.DataFrame:
    """Load order-level data from MySQL."""
    conn = mysql.connector.connect(**DB_CONFIG)
    try:
        df = pd.read_sql(ORDER_QUERY, conn)
    finally:
        conn.close()

    df["purchase_date"] = pd.to_datetime(df["purchase_date"])
    df["gross_order_value"] = pd.to_numeric(df["gross_order_value"])
    return df


def analyze(df: pd.DataFrame) -> None:
    delivered = df[df["order_status"].eq("delivered")].copy()
    delivered["order_month"] = delivered["purchase_date"].dt.to_period("M").astype(str)

    monthly = (
        delivered.groupby("order_month")
        .agg(
            orders=("order_id", "nunique"),
            customers=("customer_unique_id", "nunique"),
            revenue=("gross_order_value", "sum"),
            average_order_value=("gross_order_value", "mean"),
        )
        .reset_index()
    )
    monthly["mom_order_growth_pct"] = monthly["orders"].pct_change() * 100
    monthly["mom_revenue_growth_pct"] = monthly["revenue"].pct_change() * 100

    customer_orders = (
        delivered.groupby("customer_unique_id")
        .agg(
            orders=("order_id", "nunique"),
            customer_value=("gross_order_value", "sum"),
            first_purchase=("purchase_date", "min"),
            last_purchase=("purchase_date", "max"),
        )
        .reset_index()
    )
    customer_orders["customer_type"] = customer_orders["orders"].gt(1).map(
        {True: "Repeat", False: "One-Time"}
    )
    customer_orders["lifetime_days"] = (
        customer_orders["last_purchase"] - customer_orders["first_purchase"]
    ).dt.days

    rho, p_value = spearmanr(
        customer_orders["orders"], customer_orders["customer_value"]
    )

    value_bins = [-float("inf"), 100, 250, 500, 1000, float("inf")]
    value_labels = ["<100", "100-249", "250-499", "500-999", "1000+"]
    customer_orders["value_band"] = pd.cut(
        customer_orders["customer_value"],
        bins=value_bins,
        labels=value_labels,
        right=False,
    )
    value_summary = (
        customer_orders.groupby("value_band", observed=True)
        .agg(
            customers=("customer_unique_id", "nunique"),
            total_revenue=("customer_value", "sum"),
            average_customer_value=("customer_value", "mean"),
        )
        .reset_index()
    )

    print("Delivered orders:", delivered["order_id"].nunique())
    print("Delivered customers:", delivered["customer_unique_id"].nunique())
    print("Delivered gross revenue: %.2f" % delivered["gross_order_value"].sum())
    print("Average order value: %.2f" % delivered["gross_order_value"].mean())
    print("Overall repeat rate: %.2f%%" % (customer_orders["customer_type"].eq("Repeat").mean() * 100))
    print("Orders per customer: %.2f" % customer_orders["orders"].mean())
    print("Spearman rho (frequency/value): %.4f" % rho)
    print("Spearman p-value: %.6f" % p_value)
    print("\nMonthly trend:\n", monthly.to_string(index=False))
    print("\nCustomer lifecycle:\n", customer_orders.groupby("customer_type").agg(
        customers=("customer_unique_id", "count"),
        avg_orders=("orders", "mean"),
        avg_customer_value=("customer_value", "mean"),
        median_customer_value=("customer_value", "median"),
        avg_lifetime_days=("lifetime_days", "mean"),
    ).to_string())
    print("\nCustomer value bands:\n", value_summary.to_string(index=False))


if __name__ == "__main__":
    analyze(load_orders())
