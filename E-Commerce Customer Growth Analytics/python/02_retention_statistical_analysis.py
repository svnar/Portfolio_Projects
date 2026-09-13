"""Retention-driver statistical analysis for the Olist customer project.

Expected input: a CSV exported from the MySQL analytical layer containing one
row per delivered customer and first-order retention attributes.

The analysis compares repeat versus one-time customers using non-parametric
and categorical tests. Effect sizes are reported alongside p-values because
statistical significance alone does not indicate business importance.

Required columns:
    customer_unique_id, first_order_value, first_delivery_days,
    first_review_score, total_orders, product_category_name

Optional column:
    first_delivery_delay_days
"""

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import chi2_contingency, mannwhitneyu


INPUT_FILE = Path("../outputs/customer_retention_analysis.csv")
OUTPUT_FILE = Path("../outputs/retention_statistical_results.csv")


def cramers_v(table: pd.DataFrame) -> float:
    """Calculate Cramer's V from a contingency table."""
    chi2, _, _, _ = chi2_contingency(table)
    n = table.to_numpy().sum()
    r, k = table.shape
    denominator = n * min(k - 1, r - 1)
    if denominator == 0:
        return float("nan")
    return float(np.sqrt(chi2 / denominator))


def rank_biserial_from_u(u_stat: float, n_repeat: int, n_one_time: int) -> float:
    """Calculate rank-biserial correlation from a Mann-Whitney U statistic."""
    if n_repeat == 0 or n_one_time == 0:
        return float("nan")
    return float(2 * u_stat / (n_repeat * n_one_time) - 1)


def compare_numeric(df: pd.DataFrame, column: str) -> dict:
    """Compare a numeric first-order attribute between customer types."""
    repeat = df.loc[df["total_orders"] > 1, column].dropna()
    one_time = df.loc[df["total_orders"] == 1, column].dropna()

    if repeat.empty or one_time.empty:
        return {
            "variable": column,
            "test": "Mann-Whitney U",
            "statistic": np.nan,
            "p_value": np.nan,
            "effect_size": np.nan,
            "effect_name": "rank-biserial correlation",
        }

    stat, p_value = mannwhitneyu(
        repeat,
        one_time,
        alternative="two-sided",
    )
    effect = rank_biserial_from_u(stat, len(repeat), len(one_time))
    return {
        "variable": column,
        "test": "Mann-Whitney U",
        "statistic": float(stat),
        "p_value": float(p_value),
        "effect_size": effect,
        "effect_name": "rank-biserial correlation",
    }


def compare_categorical(df: pd.DataFrame, column: str) -> dict:
    """Test association between a categorical attribute and repeat status."""
    working = df[[column, "total_orders"]].dropna().copy()
    working["repeat_status"] = working["total_orders"] > 1
    table = pd.crosstab(working[column], working["repeat_status"])

    if table.shape[0] < 2 or table.shape[1] < 2:
        return {
            "variable": column,
            "test": "Chi-square",
            "statistic": np.nan,
            "p_value": np.nan,
            "effect_size": np.nan,
            "effect_name": "Cramer's V",
        }

    chi2, p_value, _, _ = chi2_contingency(table)
    return {
        "variable": column,
        "test": "Chi-square",
        "statistic": float(chi2),
        "p_value": float(p_value),
        "effect_size": cramers_v(table),
        "effect_name": "Cramer's V",
    }


def first_order_value_band_analysis(df: pd.DataFrame) -> dict:
    """Test whether first-order value bands are associated with repeat status."""
    working = df[["first_order_value", "total_orders"]].dropna().copy()
    bins = [-np.inf, 100, 250, 500, 1000, np.inf]
    labels = ["<100", "100-249", "250-499", "500-999", "1000+"]
    working["first_order_value_band"] = pd.cut(
        working["first_order_value"],
        bins=bins,
        labels=labels,
        right=False,
    )
    working["repeat_status"] = working["total_orders"] > 1
    table = pd.crosstab(working["first_order_value_band"], working["repeat_status"])
    chi2, p_value, _, _ = chi2_contingency(table)
    return {
        "variable": "first_order_value_band",
        "test": "Chi-square",
        "statistic": float(chi2),
        "p_value": float(p_value),
        "effect_size": cramers_v(table),
        "effect_name": "Cramer's V",
    }


def run_analysis(df: pd.DataFrame) -> pd.DataFrame:
    """Run the full statistical retention-driver analysis."""
    numeric_columns = [
        "first_order_value",
        "first_delivery_days",
        "first_review_score",
    ]

    results = [compare_numeric(df, column) for column in numeric_columns]
    results.append(first_order_value_band_analysis(df))
    results.append(compare_categorical(df, "product_category_name"))

    if "first_delivery_delay_days" in df.columns:
        df = df.copy()
        df["delivery_group"] = (
            df["first_delivery_delay_days"]
            .fillna(0)
            .gt(0)
            .map({True: "Delayed", False: "On Time"})
        )
        results.append(compare_categorical(df, "delivery_group"))

    return pd.DataFrame(results)


def print_summary(df: pd.DataFrame, results: pd.DataFrame) -> None:
    """Print sample composition and statistical results."""
    repeat = int((df["total_orders"] > 1).sum())
    one_time = int((df["total_orders"] == 1).sum())

    print("=" * 70)
    print("RETENTION DRIVER STATISTICAL ANALYSIS")
    print("=" * 70)
    print(f"Rows: {len(df):,}")
    print(f"Repeat customers: {repeat:,}")
    print(f"One-time customers: {one_time:,}")
    print("\nTEST RESULTS")
    print(results.to_string(index=False))

    print("\nINTERPRETATION GUIDE")
    print("- p-value < 0.05 indicates statistical evidence of association/difference.")
    print("- Effect size should be considered before calling a relationship meaningful.")
    print("- Category analysis is exploratory and does not establish causality.")


def main() -> None:
    """Load input data, run tests and save results."""
    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input not found: {INPUT_FILE}. Export the analytical customer "
            "retention table from MySQL before running this script."
        )

    df = pd.read_csv(INPUT_FILE)

    numeric_columns = [
        "first_order_value",
        "first_delivery_days",
        "first_review_score",
        "total_orders",
    ]
    for column in numeric_columns:
        if column in df.columns:
            df[column] = pd.to_numeric(df[column], errors="coerce")

    required = {
        "first_order_value",
        "first_delivery_days",
        "first_review_score",
        "total_orders",
        "product_category_name",
    }
    missing = required.difference(df.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    results = run_analysis(df)
    print_summary(df, results)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    results.to_csv(OUTPUT_FILE, index=False)
    print(f"\nResults saved to: {OUTPUT_FILE.resolve()}")


if __name__ == "__main__":
    main()
