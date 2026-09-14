import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, KFold, cross_val_score
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

# Use the Week 3 simulated logistics dataset.
df = pd.read_csv("../week-3/week3_hypothetical_logistics_data.csv")

df["Distance_km"] = df["Distance_km"].fillna(df["Distance_km"].median())
df["Transport_Cost"] = df["Transport_Cost"].fillna(df["Transport_Cost"].median())

features = [
    "Region", "Shipping_Mode", "Product_Category",
    "Shipment_Volume", "Distance_km",
    "Transport_Cost", "Shipment_Value"
]
target = "Delivery_Days"

X = df[features]
y = df[target]

categorical = ["Region", "Shipping_Mode", "Product_Category"]
numeric = ["Shipment_Volume", "Distance_km", "Transport_Cost", "Shipment_Value"]

preprocessor = ColumnTransformer([
    ("cat", OneHotEncoder(handle_unknown="ignore"), categorical),
    ("num", StandardScaler(), numeric)
])

models = {
    "Linear Regression": Pipeline([
        ("preprocessor", preprocessor),
        ("model", LinearRegression())
    ]),
    "Random Forest": Pipeline([
        ("preprocessor", preprocessor),
        ("model", RandomForestRegressor(
            n_estimators=250,
            max_depth=12,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=-1
        ))
    ])
}

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.20, random_state=42
)

results = []
for name, model in models.items():
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    results.append({
        "Model": name,
        "MAE": mean_absolute_error(y_test, pred),
        "RMSE": np.sqrt(mean_squared_error(y_test, pred)),
        "R2": r2_score(y_test, pred)
    })

print(pd.DataFrame(results))

# Cross-validation for the selected model
selected_model = models["Linear Regression"]
cv = KFold(n_splits=5, shuffle=True, random_state=42)

cv_rmse = np.sqrt(-cross_val_score(
    selected_model, X, y, cv=cv, scoring="neg_mean_squared_error"
))
cv_mae = -cross_val_score(
    selected_model, X, y, cv=cv, scoring="neg_mean_absolute_error"
)
cv_r2 = cross_val_score(selected_model, X, y, cv=cv, scoring="r2")

print("5-fold CV RMSE:", cv_rmse.mean())
print("5-fold CV MAE:", cv_mae.mean())
print("5-fold CV R2:", cv_r2.mean())

# Example operational scenario
selected_model.fit(X_train, y_train)
representative = pd.DataFrame([{
    "Region": "East",
    "Shipping_Mode": "Standard",
    "Product_Category": "Electronics",
    "Shipment_Volume": 4,
    "Distance_km": 300,
    "Transport_Cost": df["Transport_Cost"].median(),
    "Shipment_Value": df["Shipment_Value"].median()
}])

for mode in ["Standard", "Express", "Same Day"]:
    scenario = representative.copy()
    scenario["Shipping_Mode"] = mode
    prediction = selected_model.predict(scenario)[0]
    print(f"Predicted delivery time - {mode}: {prediction:.2f} days")
