import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# The simulated Week 3 dataset is the same dataset used in the report.
df = pd.read_csv("week3_hypothetical_logistics_data.csv")

# Basic inspection
print(df.shape)
print(df.head())
print(df.isna().sum())

# Handle missing numerical values
df["Distance_km"] = df["Distance_km"].fillna(df["Distance_km"].median())
df["Transport_Cost"] = df["Transport_Cost"].fillna(df["Transport_Cost"].median())

# Descriptive statistics
print(df.describe())

# Overall KPIs
print("Average delivery time:", df["Delivery_Days"].mean())
print("Late delivery rate (%):", df["Late_Delivery"].mean() * 100)
print("Average transport cost:", df["Transport_Cost"].mean())

# Shipping-mode summary
mode_summary = df.groupby("Shipping_Mode").agg(
    Avg_Delivery_Days=("Delivery_Days", "mean"),
    Late_Rate=("Late_Delivery", "mean"),
    Avg_Cost=("Transport_Cost", "mean")
)
mode_summary["Late_Rate"] *= 100
print(mode_summary)

# Regional summary
region_summary = df.groupby("Region").agg(
    Avg_Delivery_Days=("Delivery_Days", "mean"),
    Late_Rate=("Late_Delivery", "mean"),
    Avg_Cost=("Transport_Cost", "mean")
)
region_summary["Late_Rate"] *= 100
print(region_summary)

# 1. Delivery-time distribution
plt.figure(figsize=(8, 5))
plt.hist(df["Delivery_Days"], bins=25, edgecolor="black")
plt.title("Distribution of Delivery Time")
plt.xlabel("Delivery time (days)")
plt.ylabel("Number of shipments")
plt.tight_layout()
plt.show()

# 2. Late delivery rate by shipping mode
mode_summary["Late_Rate"].plot(kind="bar", figsize=(8, 5))
plt.title("Late Delivery Rate by Shipping Mode")
plt.ylabel("Late delivery rate (%)")
plt.xticks(rotation=0)
plt.tight_layout()
plt.show()

# 3. Transportation cost versus distance
plt.figure(figsize=(8, 5))
plt.scatter(df["Distance_km"], df["Transport_Cost"], alpha=0.45)
plt.title("Transportation Cost vs Distance")
plt.xlabel("Distance (km)")
plt.ylabel("Transport cost")
plt.tight_layout()
plt.show()

# 4. Correlation matrix
plt.figure(figsize=(9, 6))
sns.heatmap(df.select_dtypes("number").corr(), annot=True, fmt=".2f")
plt.title("Correlation Matrix")
plt.tight_layout()
plt.show()
