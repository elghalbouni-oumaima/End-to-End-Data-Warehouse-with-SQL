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

# One-hot encode categoricals
train_encoded = pd.get_dummies(train_df, columns=CATEGORICAL_COLS, drop_first=False)
model_columns = [c for c in train_encoded.columns if c not in ("customer_id", "churned")]

X = train_encoded[model_columns]
y = train_encoded["churned"]

# --------------------------------------------------------------------------
# 3. TRAIN / TEST SPLIT + MODEL
# --------------------------------------------------------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# class_weight='balanced' matters here: churn is usually the minority class,
# and without this the model can get lazy and just predict "not churned" a lot.
model = RandomForestClassifier(
    n_estimators=300,
    max_depth=8,
    class_weight="balanced",
    random_state=42,
    n_jobs=-1,
)
model.fit(X_train, y_train)

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
importances = pd.Series(model.feature_importances_, index=model_columns).sort_values(ascending=False)
print(importances.head(10).to_string())

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
