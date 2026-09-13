"""Customer Growth Analysis - Olist E-Commerce project.

This script reproduces the main Python-side exploratory analysis used alongside
 the MySQL analytical layer. It loads order-level data, restricts customer-growth
metrics to delivered orders, builds customer-level metrics, calculates lifecycle
and value bands, and performs a frequency/value relationship check.

Environment variables:
    MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD

The script intentionally contains no credentials or raw data files.
"""

import os
from pathlib import Path

import mysql.connector
import pandas as pd
from scipy.stats import spearmanr


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": "ecommerce_customer_analytics",
}

OUTPUT_DIR = Path("outputs")

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

    df["purchase_date"] = pd.to_datetime(df["purchase_date"], errors="coerce")
    for column in ["product_revenue", "freight_revenue", "gross_order_value"]:
        df[column] = pd.to_numeric(df[column], errors="coerce").fillna(0)
    return df


def build_customer_summary(delivered: pd.DataFrame) -> pd.DataFrame:
    """Aggregate delivered orders to the unique-customer level."""
    customer_orders = (
        delivered.groupby("customer_unique_id")
        .agg(
            orders=("order_id", "nunique"),
            customer_value=("gross_order_value", "sum"),
            product_revenue=("product_revenue", "sum"),
            freight_revenue=("freight_revenue", "sum"),
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
    return customer_orders


def build_monthly_summary(delivered: pd.DataFrame) -> pd.DataFrame:
    """Create monthly delivered-order growth metrics."""
    data = delivered.copy()
    data["order_month"] = data["purchase_date"].dt.to_period("M").astype(str)

    monthly = (
        data.groupby("order_month")
        .agg(
            orders=("order_id", "nunique"),
            customers=("customer_unique_id", "nunique"),
            revenue=("gross_order_value", "sum"),
            product_revenue=("product_revenue", "sum"),
            freight_revenue=("freight_revenue", "sum"),
            average_order_value=("gross_order_value", "mean"),
        )
        .reset_index()
    )
    monthly["mom_order_growth_pct"] = monthly["orders"].pct_change() * 100
    monthly["mom_revenue_growth_pct"] = monthly["revenue"].pct_change() * 100
    return monthly


def add_value_bands(customer_orders: pd.DataFrame) -> pd.DataFrame:
    """Assign the project value bands to customers."""
    value_bins = [-float("inf"), 100, 250, 500, 1000, float("inf")]
    value_labels = ["<100", "100-249", "250-499", "500-999", "1000+"]
    customer_orders = customer_orders.copy()
    customer_orders["value_band"] = pd.cut(
        customer_orders["customer_value"],
        bins=value_bins,
        labels=value_labels,
        right=False,
    )
    return customer_orders


def build_value_summary(customer_orders: pd.DataFrame) -> pd.DataFrame:
    """Summarize customers and revenue by customer value band."""
    return (
        customer_orders.groupby("value_band", observed=True)
        .agg(
            customers=("customer_unique_id", "nunique"),
            total_revenue=("customer_value", "sum"),
            average_customer_value=("customer_value", "mean"),
            median_customer_value=("customer_value", "median"),
        )
        .reset_index()
    )


def build_lifecycle_summary(customer_orders: pd.DataFrame) -> pd.DataFrame:
    """Summarize one-time versus repeat customer behavior."""
    return (
        customer_orders.groupby("customer_type")
        .agg(
            customers=("customer_unique_id", "count"),
            avg_orders=("orders", "mean"),
            avg_customer_value=("customer_value", "mean"),
            median_customer_value=("customer_value", "median"),
            avg_lifetime_days=("lifetime_days", "mean"),
            total_revenue=("customer_value", "sum"),
        )
        .reset_index()
    )


def frequency_value_analysis(customer_orders: pd.DataFrame) -> tuple[float, float]:
    """Measure monotonic association between purchase frequency and value."""
    rho, p_value = spearmanr(
        customer_orders["orders"],
        customer_orders["customer_value"],
    )
    return float(rho), float(p_value)


def save_outputs(
    monthly: pd.DataFrame,
    lifecycle: pd.DataFrame,
    value_summary: pd.DataFrame,
    customer_orders: pd.DataFrame,
) -> None:
    """Save reproducible CSV outputs for review or downstream analysis."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    monthly.to_csv(OUTPUT_DIR / "monthly_customer_growth.csv", index=False)
    lifecycle.to_csv(OUTPUT_DIR / "customer_lifecycle_summary.csv", index=False)
    value_summary.to_csv(OUTPUT_DIR / "customer_value_bands.csv", index=False)
    customer_orders.to_csv(OUTPUT_DIR / "customer_growth_customer_level.csv", index=False)


def analyze(df: pd.DataFrame) -> None:
    """Run the complete customer-growth analysis and print key outputs."""
    delivered = df[df["order_status"].eq("delivered")].copy()
    delivered = delivered.dropna(subset=["customer_unique_id", "purchase_date"])

    monthly = build_monthly_summary(delivered)
    customer_orders = build_customer_summary(delivered)
    customer_orders = add_value_bands(customer_orders)
    lifecycle = build_lifecycle_summary(customer_orders)
    value_summary = build_value_summary(customer_orders)
    rho, p_value = frequency_value_analysis(customer_orders)

    delivered_orders = delivered["order_id"].nunique()
    delivered_customers = delivered["customer_unique_id"].nunique()
    delivered_revenue = delivered["gross_order_value"].sum()
    delivered_aov = delivered["gross_order_value"].mean()
    repeat_rate = customer_orders["customer_type"].eq("Repeat").mean() * 100
    orders_per_customer = customer_orders["orders"].mean()

    print("=" * 70)
    print("CUSTOMER GROWTH ANALYSIS")
    print("=" * 70)
    print(f"Delivered orders: {delivered_orders:,}")
    print(f"Delivered customers: {delivered_customers:,}")
    print(f"Delivered gross revenue: {delivered_revenue:,.2f}")
    print(f"Average order value: {delivered_aov:,.2f}")
    print(f"Overall repeat rate: {repeat_rate:.2f}%")
    print(f"Orders per customer: {orders_per_customer:.2f}")
    print(f"Frequency/value Spearman rho: {rho:.4f}")
    print(f"Frequency/value p-value: {p_value:.6g}")

    print("\nMONTHLY TREND")
    print(monthly.to_string(index=False))

    print("\nCUSTOMER LIFECYCLE")
    print(lifecycle.to_string(index=False))

    print("\nCUSTOMER VALUE BANDS")
    print(value_summary.to_string(index=False))

    save_outputs(monthly, lifecycle, value_summary, customer_orders)
    print(f"\nOutputs saved to: {OUTPUT_DIR.resolve()}")


def main() -> None:
    """Application entry point."""
    df = load_orders()
    analyze(df)


if __name__ == "__main__":
    main()
