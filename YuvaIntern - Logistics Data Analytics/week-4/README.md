# Week 4 – Predictive Modeling and Optimization

## Objective

Week 4 extends the previous descriptive analysis into predictive analytics. The target is to estimate delivery time before a shipment is completed and use the prediction to support logistics decisions.

## Target

**Delivery_Days** is the target variable.

Predictor variables include Region, Shipping_Mode, Product_Category, Shipment_Volume, Distance_km, Transport_Cost and Shipment_Value. Late_Delivery is deliberately excluded because it is derived from the delivery outcome and could introduce target leakage.

## Models

Two regression approaches are compared:

1. Linear Regression – a simple, interpretable baseline.
2. Random Forest Regressor – a tree-based ensemble capable of capturing non-linear relationships and interactions.

## Evaluation

The models are evaluated using:

- MAE – average absolute prediction error in days.
- RMSE – gives more weight to larger errors.
- R² – measures the proportion of target variation explained by the model.
- 5-fold cross-validation – checks performance stability across different data splits.

## Optimization

The predictive output is connected to operational decisions. For example, predicted delivery time can be compared across Standard, Express and Same Day shipping options while considering cost and customer deadlines. A future Vehicle Routing Problem can also incorporate distance, vehicle capacity and delivery time windows.

## Result

For the simulated Week 3 dataset, Linear Regression performed slightly better than Random Forest on the held-out test set. This reinforces the principle that model selection should be based on validation results rather than assuming that a more complex model will always perform better.

## Reference

Google OR-Tools Vehicle Routing:
https://developers.google.com/optimization/routing/vrp
