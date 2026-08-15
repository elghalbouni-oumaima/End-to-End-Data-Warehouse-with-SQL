"""
train_and_score_churn.py
-------------------------------------------------------------------------
Trains a churn classifier on gold.customer_churn_training, evaluates it,
then scores gold.customer_churn_scoring and writes the results back to
gold.customer_churn_predictions - which your Power BI dashboard can then
read directly (a "Customers at Risk" page, sitting right next to the
"Customers Over Time" page you already built).

Setup:
    pip install pandas scikit-learn sqlalchemy pyodbc joblib

Before running:
    - Update CONNECTION_STRING below with your server/database.
    - Run EXEC gold.build_churn_training_data; and
      EXEC gold.build_churn_scoring_data; in SQL Server first.
-------------------------------------------------------------------------
"""

import pandas as pd
import joblib
import urllib.parse
from datetime import datetime
from sqlalchemy import create_engine, text
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, roc_auc_score, confusion_matrix
from sklearn.pipeline import make_pipeline,Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.utils.class_weight import compute_sample_weight
# --------------------------------------------------------------------------
# 1. CONNECTION - update this for your environment
# --------------------------------------------------------------------------
odbc_str = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=DESKTOP-NRD95P9\SQLEXPRESS;"       
    "DATABASE=DataWarehouse;"           
    "Trusted_Connection=yes;"
)
params = urllib.parse.quote_plus(odbc_str)
CONNECTION_STRING = f"mssql+pyodbc:///?odbc_connect={params}"
engine = create_engine(CONNECTION_STRING)

CATEGORICAL_COLS = ["gender", "marital_status", "country"]
FEATURE_COLS = ["recency_days", "frequency", "monetary", "avg_order_value", "tenure_days", "age"]

# --------------------------------------------------------------------------
# 2. LOAD TRAINING DATA
# --------------------------------------------------------------------------
print(">> Loading training data...")
train_df = pd.read_sql("SELECT * FROM gold.customer_churn_training", engine)
print(f"   {len(train_df)} customers | churn rate: {train_df['churned'].mean():.1%}")
model_columns = [c for c in train_df.columns if c not in ("customer_id", "churned")]

X = train_df[model_columns]
y = train_df["churned"]

# --------------------------------------------------------------------------
# 3. TRAIN / TEST SPLIT + MODEL
# --------------------------------------------------------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Numerical features
numerical_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="median")),
    ("scaler", StandardScaler())
])

# Categorical features
categorical_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="most_frequent")),
    ("encoder", OneHotEncoder(
        handle_unknown="ignore",
        sparse_output=False
    ))
])

# Combine preprocessing
preprocessor = ColumnTransformer(
    transformers=[
        ("num", numerical_pipeline, FEATURE_COLS),
        ("cat", categorical_pipeline, CATEGORICAL_COLS)
    ],
    remainder="drop"
)

# Create the model
gb_model = RandomForestClassifier(
    random_state=42
)

# Create the pipeline
model = make_pipeline(preprocessor, gb_model)

# Train on the entire training set
sample_weights = compute_sample_weight(class_weight="balanced", y=y_train)
model.fit(X_train, y_train, randomforestclassifier__sample_weight=sample_weights)

# --------------------------------------------------------------------------
# 4. EVALUATE
# --------------------------------------------------------------------------
y_pred = model.predict(X_test)
y_proba = model.predict_proba(X_test)[:, 1]

print("\n>> Classification report:")
print(classification_report(y_test, y_pred, target_names=["Retained", "Churned"]))

print(f">> ROC-AUC: {roc_auc_score(y_test, y_proba):.3f}")

print("\n>> Confusion matrix (rows=actual, cols=predicted):")
print(confusion_matrix(y_test, y_pred))

print("\n>> Top feature importances:")
gb_step = model.named_steps["randomforestclassifier"]
feature_names = model.named_steps["columntransformer"].get_feature_names_out()
importances = pd.Series(gb_step.feature_importances_, index=feature_names).sort_values(ascending=False)
print(importances.head(10).to_string())
# --------------------------------------------------------------------------
# Save ALL feature importances to the warehouse, not just the top 10 printed
# --------------------------------------------------------------------------
importance_df = importances.reset_index()
importance_df.columns = ["feature_name", "importance"]
importance_df["trained_at"] = datetime.now()

with engine.begin() as conn:
    conn.execute(text("TRUNCATE TABLE gold.churn_feature_importance"))
importance_df.to_sql("churn_feature_importance", engine, schema="gold", if_exists="append", index=False)

print(f"\n>> Saved {len(importance_df)} feature importances to gold.churn_feature_importance")

# --------------------------------------------------------------------------
# 5. SAVE THE MODEL
# --------------------------------------------------------------------------
joblib.dump({"model": model, "columns": model_columns}, "ml/customer_churn/model/churn_model.joblib")
print("\n>> Model saved to churn_model.joblib")

# --------------------------------------------------------------------------
# 6. SCORE CURRENT CUSTOMERS
# --------------------------------------------------------------------------
print("\n>> Loading scoring data...")
score_df = pd.read_sql("SELECT * FROM gold.customer_churn_scoring", engine)

score_encoded = pd.get_dummies(score_df, columns=CATEGORICAL_COLS, drop_first=False)

# Critical step: the scoring set may not contain every category the training
# set saw (e.g. a country with no recent orders), or vice versa. reindex()
# forces the columns to match exactly what the model was trained on, filling
# any missing ones with 0 - without this, predict() will throw a shape error
# or silently misalign columns.
score_X = score_encoded.reindex(columns=model_columns, fill_value=0)

score_df["churn_probability"] = model.predict_proba(score_X)[:, 1]
score_df["risk_tier"] = pd.qcut(
    score_df["churn_probability"],
    q=[0, 0.70, 0.90, 1.0],
    labels=["Low", "Medium", "High"],
    duplicates="drop",
)
score_df["scored_at"] = datetime.now()

# --------------------------------------------------------------------------
# 7. WRITE PREDICTIONS BACK TO THE WAREHOUSE
# --------------------------------------------------------------------------
print(">> Writing predictions to gold.customer_churn_predictions...")
with engine.begin() as conn:
    conn.execute(text("TRUNCATE TABLE gold.customer_churn_predictions"))

output = score_df[["customer_id", "churn_probability", "risk_tier", "scored_at"]]
output.to_sql("customer_churn_predictions", engine, schema="gold", if_exists="append", index=False)

print(f">> Done. Scored {len(output)} customers.")
print(output["risk_tier"].value_counts())
