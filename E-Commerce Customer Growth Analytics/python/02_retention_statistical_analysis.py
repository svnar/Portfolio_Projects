"""Retention-driver statistical analysis for the Olist customer project.

Expected input: a CSV exported from the MySQL analytical layer containing one
row per delivered customer and first-order retention attributes. The script
keeps the statistical tests separate from the dashboard layer so the results
can be independently reviewed.

Required columns:
    customer_unique_id, first_order_value, first_delivery_days,
    first_review_score, total_orders, product_category_name

Optional delivery-delay column:
    first_delivery_delay_days
"""

from pathlib import Path
import pandas as pd
from scipy.stats import mannwhitneyu, chi2_contingency


INPUT_FILE = Path("../outputs/customer_retention_analysis.csv")


def cramers_v(table: pd.DataFrame) -> float:
    """Calculate Cramer's V from a contingency table."""
    chi2, _, _, _ = chi2_contingency(table)
    n = table.to_numpy().sum()
    r, k = table.shape
    return (chi2 / (n * min(k - 1, r - 1))) ** 0.5


def compare_numeric(df: pd.DataFrame, column: str) -> None:
    """Compare a numeric first-order attribute between one-time and repeat customers."""
    repeat = df.loc[df["total_orders"] > 1, column].dropna()
    one_time = df.loc[df["total_orders"] == 1, column].dropna()
    stat, p_value = mannwhitneyu(repeat, one_time, alternative="two-sided")
    print(f"{column}: Mann-Whitney U={stat:.2f}, p-value={p_value:.6g}")


def compare_categorical(df: pd.DataFrame, column: str) -> None:
    """Test association between a categorical attribute and repeat status."""
    table = pd.crosstab(df[column], df["total_orders"] > 1)
    chi2, p_value, _, _ = chi2_contingency(table)
    print(
        f"{column}: chi-square={chi2:.2f}, p-value={p_value:.6g}, "
        f"Cramer's V={cramers_v(table):.4f}"
    )


def main() -> None:
    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input not found: {INPUT_FILE}. Export the analytical table from MySQL "
            "to the expected outputs folder before running this script."
        )

    df = pd.read_csv(INPUT_FILE)
    df["first_order_value"] = pd.to_numeric(df["first_order_value"], errors="coerce")
    df["first_review_score"] = pd.to_numeric(df["first_review_score"], errors="coerce")
    df["total_orders"] = pd.to_numeric(df["total_orders"], errors="coerce")

    print("Rows:", len(df))
    print("Repeat customers:", int((df["total_orders"] > 1).sum()))
    print("One-time customers:", int((df["total_orders"] == 1).sum()))
    print("\nNUMERIC RETENTION DRIVERS")
    compare_numeric(df, "first_order_value")
    compare_numeric(df, "first_review_score")

    print("\nCATEGORICAL RETENTION DRIVERS")
    compare_categorical(df, "product_category_name")

    if "first_delivery_delay_days" in df.columns:
        df["delivery_group"] = df["first_delivery_delay_days"].fillna(0).gt(0).map(
            {True: "Delayed", False: "On Time"}
        )
        compare_categorical(df, "delivery_group")


if __name__ == "__main__":
    main()
