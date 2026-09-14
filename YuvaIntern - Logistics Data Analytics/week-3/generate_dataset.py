import numpy as np
import pandas as pd

# Reproducible hypothetical logistics dataset for Weeks 3 and 4.
rng = np.random.default_rng(42)
n = 1200

regions = rng.choice(["North", "South", "East", "West"], n)
shipping_modes = rng.choice(["Standard", "Express", "Same Day"], n, p=[0.55, 0.30, 0.15])
product_categories = rng.choice(["Electronics", "Furniture", "Clothing", "Grocery"], n)
shipment_volume = rng.integers(1, 15, n)
distance = np.maximum(rng.normal(450, 250, n), 25).round(1)
transport_cost = (distance * 0.85 + shipment_volume * 18 + rng.normal(0, 55, n)).clip(40).round(2)
shipment_value = (shipment_volume * rng.uniform(80, 500, n) + rng.normal(0, 100, n)).clip(50).round(2)

mode_effect = np.select(
    [shipping_modes == "Express", shipping_modes == "Same Day"],
    [-0.9, -1.45],
    default=0
)
region_effect = np.select(
    [regions == "East", regions == "West", regions == "South"],
    [0.15, 0.30, -0.10],
    default=0.05
)

delivery_days = (
    1.2 + distance / 240 + shipment_volume * 0.025 + mode_effect + region_effect
    + rng.normal(0, 0.55, n)
).clip(0.5).round(2)

# A shipment is considered late when actual delivery exceeds 3 days.
late_delivery = (delivery_days > 3).astype(int)

df = pd.DataFrame({
    "Region": regions,
    "Shipping_Mode": shipping_modes,
    "Product_Category": product_categories,
    "Shipment_Volume": shipment_volume,
    "Distance_km": distance,
    "Transport_Cost": transport_cost,
    "Shipment_Value": shipment_value,
    "Delivery_Days": delivery_days,
    "Late_Delivery": late_delivery,
})

# Introduce a small amount of missingness for preprocessing practice.
for column in ["Distance_km", "Transport_Cost"]:
    missing_index = rng.choice(df.index, size=12, replace=False)
    df.loc[missing_index, column] = np.nan

df.to_csv("week3_hypothetical_logistics_data.csv", index=False)
print("Created week3_hypothetical_logistics_data.csv with", len(df), "records")
