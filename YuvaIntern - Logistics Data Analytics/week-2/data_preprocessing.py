import pandas as pd
import numpy as np

# Replace this path with the downloaded DataCo dataset file.
INPUT_FILE = "DataCoSupplyChainDataset.csv"
OUTPUT_FILE = "cleaned_logistics_data.csv"

# Load data
df = pd.read_csv(INPUT_FILE, encoding="latin1")

print("Shape:", df.shape)
print("Missing values:\n", df.isna().sum())
print("Duplicate rows:", df.duplicated().sum())

# Remove exact duplicate records
df = df.drop_duplicates().copy()

# Standardize column names for easier use in Python
df.columns = (
    df.columns
      .str.strip()
      .str.lower()
      .str.replace(" ", "_", regex=False)
      .str.replace("-", "_", regex=False)
)

# Convert selected numeric fields when they exist
numeric_columns = [
    "days_for_shipping_real",
    "days_for_shipment_scheduled",
    "benefit_per_order",
    "sales_per_customer",
    "order_item_quantity",
    "sales",
    "order_profit_per_order"
]

for column in numeric_columns:
    if column in df.columns:
        df[column] = pd.to_numeric(df[column], errors="coerce")

# Median imputation for selected numerical fields
for column in numeric_columns:
    if column in df.columns and df[column].isna().any():
        df[column] = df[column].fillna(df[column].median())

# IQR-based outlier flags for selected measures
for column in ["sales", "order_profit_per_order", "benefit_per_order"]:
    if column in df.columns:
        q1 = df[column].quantile(0.25)
        q3 = df[column].quantile(0.75)
        iqr = q3 - q1
        lower = q1 - 1.5 * iqr
        upper = q3 + 1.5 * iqr
        df[f"{column}_outlier"] = (df[column] < lower) | (df[column] > upper)

# Save the prepared dataset
df.to_csv(OUTPUT_FILE, index=False)
print("Cleaned dataset saved to:", OUTPUT_FILE)
