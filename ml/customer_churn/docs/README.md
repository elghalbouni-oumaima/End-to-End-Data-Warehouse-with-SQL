# Customer Churn Prediction

## Overview

A machine learning component was developed to predict customer churn based on historical purchasing behavior and customer characteristics.

The objective is to:

* Identify customers with a high probability of churn.
* Understand the main factors associated with churn.
* Assign customers to **Low**, **Medium**, and **High** risk tiers.
* Store predictions back in the Gold layer.
* Make the predictions available for visualization in Power BI.

The churn prediction pipeline uses the following Gold-layer tables:

```text
gold.customer_churn_training
        │
        ▼
   ML Training
        │
        ▼
 Random Forest
        │
        ├── Evaluation
        │
        ├── Feature Importance
        │
        ▼
gold.customer_churn_scoring
        │
        ▼
 Customer Risk Scoring
        │
        ▼
gold.customer_churn_predictions
        │
        ▼
    Power BI
```

---

## 1. Churn Dataset

The training dataset contains **5,671 customers**.

The target variable is:

```text
churned
```

where:

* `0` → Retained customer
* `1` → Churned customer

The observed churn rate is:

```text
15.8%
```

The dataset contains behavioral, financial, demographic, and customer-lifecycle features.

### Features

| Feature           | Description                                       |
| ----------------- | ------------------------------------------------- |
| `recency_days`    | Number of days since the customer's last purchase |
| `frequency`       | Number of orders placed by the customer           |
| `monetary`        | Total amount spent                                |
| `avg_order_value` | Average value of an order                         |
| `tenure_days`     | Number of days the customer has been registered   |
| `age`             | Customer age                                      |
| `gender`          | Customer gender                                   |
| `marital_status`  | Customer marital status                           |
| `country`         | Customer country                                  |

---

# 2. Model Selection

Several classification models were evaluated using cross-validation:

* Logistic Regression
* Random Forest
* Gradient Boosting
* XGBoost

The final model selected for the churn prediction pipeline is **Random Forest Classifier**.

### Why Random Forest?

Random Forest was selected because:

* It achieved strong predictive performance.
* Its results were close to Gradient Boosting.
* It provides feature importance, which helps explain the model.
* It handles nonlinear relationships between customer characteristics and churn.
* It provides churn probabilities required for customer risk scoring.
* It was relatively quick to train and execute compared with the alternatives tested.

The goal was therefore not simply to select the model with the highest metric, but to choose a model providing a good balance between **performance, interpretability, and execution efficiency**.

---

# 3. Final Model Performance

The final Random Forest model was trained on:

```text
5,671 customers
```

with:

```text
15.8% churn rate
```

The test set contained:

```text
1,135 customers
```

### Classification Results

| Class                | Precision | Recall | F1-score |   Support |
| -------------------- | --------: | -----: | -------: | --------: |
| Retained             |      0.97 |   0.97 |     0.97 |       955 |
| Churned              |      0.84 |   0.84 |     0.84 |       180 |
| **Overall Accuracy** |  **0.95** |        |          | **1,135** |

Additional metrics:

```text
Accuracy : 0.95
ROC-AUC  : 0.985
```

The ROC-AUC of **0.985** indicates that the model has a strong ability to distinguish between retained and churned customers.

---

# 4. Confusion Matrix

The model produced the following confusion matrix:

```text
                 Predicted
                 Retained  Churned
Actual Retained     925       30
Actual Churned       28      152
```

This means:

* **925** retained customers were correctly classified.
* **30** retained customers were incorrectly classified as churned.
* **152** churned customers were correctly identified.
* **28** churned customers were missed by the model.

The model therefore successfully identified:

```text
152 / 180 ≈ 84.4%
```

of the churned customers in the test set.

---

# 5. Feature Importance

The Random Forest model was also used to identify the features that contributed most strongly to its predictions.

### Top Features

| Feature                 | Importance |
| ----------------------- | ---------: |
| `recency_days`          |     0.2927 |
| `tenure_days`           |     0.2776 |
| `monetary`              |     0.0786 |
| `country_Australia`     |     0.0669 |
| `age`                   |     0.0599 |
| `avg_order_value`       |     0.0565 |
| `frequency`             |     0.0464 |
| `country_Canada`        |     0.0443 |
| `country_United States` |     0.0312 |
| `country_France`        |     0.0086 |

The two strongest features were:

```text
recency_days
tenure_days
```

This suggests that **customer inactivity and customer lifecycle duration were particularly influential features in the trained model**.

> Feature importance indicates how much the model relied on a feature during prediction. It should not automatically be interpreted as a causal relationship.

---

# 6. Model Artifact

After training, the model was serialized using `joblib`:

```text
churn_model.joblib
```

The saved artifact contains:

```text
Random Forest model
+
Preprocessing / feature column information
```

This allows the trained model to be reused for future customer scoring without retraining it every time.

---

# 7. Customer Scoring

After evaluating the model, the pipeline loads the current customers from:

```text
gold.customer_churn_scoring
```

The model calculates a churn probability for each customer:

```text
churn_probability
```

The probability is then transformed into a customer risk tier.

### Risk Tiers

```text
Low Risk
Medium Risk
High Risk
```

The final predictions are written to:

```text
gold.customer_churn_predictions
```

with the following information:

| Column              | Description                                 |
| ------------------- | ------------------------------------------- |
| `customer_id`       | Customer identifier                         |
| `churn_probability` | Predicted probability of churn              |
| `risk_tier`         | Low / Medium / High                         |
| `scored_at`         | Timestamp when the prediction was generated |

---

# 8. Current Customer Risk Distribution

The trained model was applied to:

```text
18,482 customers
```

The resulting risk distribution was:

| Risk Tier |  Customers | Percentage |
| --------- | ---------: | ---------: |
| 🟢 Low    |     13,130 |      71.1% |
| 🟠 Medium |      3,877 |      21.0% |
| 🔴 High   |      1,475 |       8.0% |
| **Total** | **18,482** |   **100%** |

This gives the business a way to prioritize customers according to their predicted churn risk.

---

# 9. End-to-End ML Pipeline

The complete workflow is:

```text
                 GOLD LAYER
                     │
                     ▼
       customer_churn_training
                     │
                     ▼
          Data preprocessing
                     │
                     ▼
           Random Forest
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
      Evaluation          Feature Importance
          │                     │
          └──────────┬──────────┘
                     ▼
             churn_model.joblib
                     │
                     ▼
       customer_churn_scoring
                     │
                     ▼
           Churn Probability
                     │
                     ▼
               Risk Tier
                     │
                     ▼
       customer_churn_predictions
                     │
                     ▼
                 Power BI
```

---

# 10. Power BI Integration

The predictions generated by the ML pipeline are consumed by Power BI.

This allows the dashboard to provide a **Customers at Risk** page containing:

### KPIs

* Total Customers
* At Risk Customers
* High Risk Customers
* Average Churn Probability
* Customers to Recover

### Visualizations

* Customers by Risk Tier
* At Risk Customers Over Time
* At Risk Customers by Country
* Churn Probability Distribution
* Top Risk Factors
* Top High-Risk Customers

This creates a connection between the **Data Warehouse → Machine Learning → Business Intelligence** layers.

```text
SQL Data Warehouse
        │
        ▼
    Gold Layer
        │
        ▼
 Machine Learning
        │
        ▼
 Churn Predictions
        │
        ▼
    Power BI
        │
        ▼
 Business Insights
```

---

## 11. Project Structure

I recommend organizing the ML part of your repository like this:

```text
DataWarehouse/
│
├── datasets/
│
├── scripts/
│   ├── bronze/
│   ├── silver/
│   └── gold/
│       ├── gold_tables.sql
│       ├── gold_customer_churn.sql
│       └── gold_churn_predictions.sql
│
├── ml/
│   └── customer_churn/
│       ├── notebooks/
│       │   ├── 01_churn_eda.ipynb
│       │   ├── 02_churn_model_comparison.ipynb
│       │   └── 03_churn_model_training.ipynb
│       │
│       ├── model/
│       │   └── churn_model.joblib
│       │
│       └── README.md
│
├── powerbi/
│   └── Customer_Analytics.pbix
│
└── README.md
```

For GitHub, **don't commit the `.joblib` model if it is large**. If it's small, you can include it, but for a portfolio project I'd usually document the model artifact and provide the training notebook/script rather than unnecessarily storing binaries.

---

## 12. Final Project Summary


> **Customer Churn Prediction** extends the data warehouse with a machine learning layer capable of identifying customers at risk of churn. A Random Forest classifier achieved **95% accuracy and 0.985 ROC-AUC**, with an **84% precision and recall for the churned class**. The model was selected as a balance between predictive performance, interpretability, and execution efficiency. Predictions are stored in the Gold layer and integrated into Power BI to provide actionable customer-risk insights.

