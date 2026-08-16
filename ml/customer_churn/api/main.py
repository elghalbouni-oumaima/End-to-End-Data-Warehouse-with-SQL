"""
main.py - Churn Prediction API
-------------------------------------------------------------------------
Exposes the churn pipeline as a live API instead of a batch-only script.

Two kinds of endpoints:
  1. Read endpoints - fast lookups against predictions already computed
     by train_and_score_churn.py and sitting in gold.customer_churn_predictions.
  2. A live scoring endpoint - runs the saved model on NEW feature values
     supplied in the request, without touching the warehouse at all.

Setup:
    pip install fastapi uvicorn[standard]

Run:
    uvicorn ml.customer_churn.api.main:app --reload

Then open http://127.0.0.1:8000/docs - FastAPI auto-generates interactive
API documentation from the type hints below. This is one of the main
reasons it's worth learning: we get a working, testable API explorer
for free, with zero extra code.
-------------------------------------------------------------------------
"""

import urllib.parse
import joblib
import pandas as pd
from contextlib import asynccontextmanager
from typing import Optional
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, text

# --------------------------------------------------------------------------
# CONNECTION - same pattern as train_and_score_churn.py
# --------------------------------------------------------------------------
odbc_str = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=DESKTOP-NRD95P9\\SQLEXPRESS;"
    "DATABASE=DataWarehouse;"
    "Trusted_Connection=yes;"
)
CONNECTION_STRING = f"mssql+pyodbc:///?odbc_connect={urllib.parse.quote_plus(odbc_str)}"
engine = create_engine(CONNECTION_STRING)

MODEL_PATH = "ml/customer_churn/model/churn_model.joblib"

# --------------------------------------------------------------------------
# Load the model ONCE at startup, not per-request.
# Loading a joblib file involves disk I/O and deserialization - doing that
# on every API call would make each request needlessly slow. Loading once
# and keeping it in memory for the app's lifetime is the standard pattern.
# --------------------------------------------------------------------------
model_bundle = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    print(">> Loading model...")
    bundle = joblib.load(MODEL_PATH)
    model_bundle["model"] = bundle["model"]
    model_bundle["columns"] = bundle["columns"]
    print(">> Model loaded.")
    yield
    model_bundle.clear()

app = FastAPI(
    title="Customer Churn API",
    description="Serves churn predictions from the Gold layer warehouse and live model scoring.",
    version="1.0.0",
    lifespan=lifespan,
)

# --------------------------------------------------------------------------
# Request / response schemas
# Pydantic models double as both input validation AND auto-generated docs -
# if a request is missing a field or sends the wrong type, FastAPI rejects
# it with a clear error before your code even runs.
# --------------------------------------------------------------------------
class CustomerRisk(BaseModel):
    customer_id: int
    churn_probability: float
    risk_tier: str
    scored_at: str

class CustomerFeatures(BaseModel):
    recency_days: int = Field(..., ge=0, description="Days since last order")
    frequency: int = Field(..., ge=0, description="Number of distinct orders")
    monetary: float = Field(..., ge=0, description="Total lifetime spend")
    avg_order_value: float = Field(..., ge=0)
    tenure_days: int = Field(..., ge=0, description="Days since account creation")
    age: int = Field(..., ge=0, le=120)
    gender: str
    marital_status: str
    country: str

class PredictionResult(BaseModel):
    churn_probability: float
    risk_tier: str

# --------------------------------------------------------------------------
# 1. Health check - lets you (or a monitoring tool) confirm the API and
#    its DB connection are actually working, not just that the process
#    is running.
# --------------------------------------------------------------------------
@app.get("/health")
def health_check():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected", "model_loaded": "model" in model_bundle}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database unreachable: {e}")

# --------------------------------------------------------------------------
# 2. Look up a single customer's already-computed risk (batch predictions)
# --------------------------------------------------------------------------
@app.get("/customers/{customer_id}/risk", response_model=CustomerRisk)
def get_customer_risk(customer_id: int):
    query = text("""
        SELECT customer_id, churn_probability, risk_tier, scored_at
        FROM gold.customer_churn_predictions
        WHERE customer_id = :customer_id
    """)
    with engine.connect() as conn:
        row = conn.execute(query, {"customer_id": customer_id}).mappings().first()

    if row is None:
        raise HTTPException(status_code=404, detail=f"No prediction found for customer_id {customer_id}")

    return CustomerRisk(
        customer_id=row["customer_id"],
        churn_probability=float(row["churn_probability"]),
        risk_tier=row["risk_tier"],
        scored_at=str(row["scored_at"]),
    )

# --------------------------------------------------------------------------
# 3. List at-risk customers, sorted by revenue at stake - mirrors the
#    watchlist table on your Power BI page, but callable from any system.
# --------------------------------------------------------------------------
@app.get("/customers/at-risk")
def list_at_risk_customers(
    tier: Optional[str] = Query(None, description="Filter by risk_tier: Low, Medium, High"),
    limit: int = Query(50, ge=1, le=500),
):
    base_query = """
        SELECT p.customer_id, p.churn_probability, p.risk_tier, s.monetary, s.recency_days
        FROM gold.customer_churn_predictions p
        JOIN gold.customer_churn_scoring s ON s.customer_id = p.customer_id
    """
    params = {}
    if tier:
        base_query += " WHERE p.risk_tier = :tier"
        params["tier"] = tier

    base_query += " ORDER BY s.monetary DESC OFFSET 0 ROWS FETCH NEXT :limit ROWS ONLY"
    params["limit"] = limit

    with engine.connect() as conn:
        rows = conn.execute(text(base_query), params).mappings().all()

    return {"count": len(rows), "customers": [dict(r) for r in rows]}

# --------------------------------------------------------------------------
# 4. LIVE SCORING - the interesting one. Runs the saved model directly on
#    request data, without needing the warehouse to already contain this
#    customer. Useful for a "what-if" tool, or scoring a brand new
#    customer signup before they've even been through a Gold layer refresh.
# --------------------------------------------------------------------------
@app.post("/predict", response_model=PredictionResult)
def predict_churn(features: CustomerFeatures):
    if "model" not in model_bundle:
        raise HTTPException(status_code=503, detail="Model not loaded")

    input_df = pd.DataFrame([features.model_dump()])

    model = model_bundle["model"]
    probability = float(model.predict_proba(input_df)[:, 1][0])

    # Reuse the same tiering logic conceptually - for a single ad-hoc
    # prediction there's no population to compute percentiles against,
    # so fixed cutoffs are used here as a reasonable approximation.
    # (See the case study for why fixed cutoffs were wrong for the BATCH
    # scoring distribution - for a single live prediction, that problem
    # doesn't apply the same way, since there's no distribution to rank
    # against.)
    if probability >= 0.5:
        tier = "High"
    elif probability >= 0.25:
        tier = "Medium"
    else:
        tier = "Low"

    return PredictionResult(churn_probability=round(probability, 4), risk_tier=tier)