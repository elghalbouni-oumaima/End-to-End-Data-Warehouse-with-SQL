"""
app.py - Customer Churn Demo App
-------------------------------------------------------------------------
A small interactive front end over the FastAPI churn service. Built for
a portfolio demo video - three screens that each show a different real
part of the pipeline actually working, not just static charts.

Setup:
    pip install streamlit requests pandas

IMPORTANT - two things must be running at the same time for this to work:
    1. The FastAPI backend:  uvicorn ml.customer_churn.api.main:app --reload
    2. This app:              streamlit run ml/customer_churn/app/app.py

Run this AFTER the API is already up, or every call below will fail with
a connection error.
-------------------------------------------------------------------------
"""

import requests
import pandas as pd
import streamlit as st

API_BASE_URL = "http://127.0.0.1:8000"

st.set_page_config(page_title="Customer Churn Demo", page_icon="📉", layout="wide")

TIER_COLORS = {"Low": "🟢", "Medium": "🟡", "High": "🔴"}


def call_api(method: str, path: str, **kwargs):
    """Thin wrapper so every screen handles a down API the same way,
    instead of each screen needing its own try/except block."""
    try:
        response = requests.request(method, f"{API_BASE_URL}{path}", timeout=5, **kwargs)
        response.raise_for_status()
        return response.json(), None
    except requests.exceptions.ConnectionError:
        return None, "Can't reach the API. Is `uvicorn main:app --reload` running?"
    except requests.exceptions.HTTPError as e:
        return None, f"API error: {e.response.status_code} - {e.response.json().get('detail', '')}"
    except Exception as e:
        return None, f"Unexpected error: {e}"


st.title("📉 Customer Churn Prediction")
st.caption("Demo app built on top of a SQL Server warehouse, a scikit-learn model, and a FastAPI service.")

tab1, tab2, tab3 = st.tabs(["🔍 Customer Lookup", "📋 At-Risk Watchlist", "🧪 Live What-If Predictor"])
# ==========================================================================
# SCREEN 1: Customer Lookup
# ==========================================================================
with tab1:
    st.header("🔍 Look Up a Customer's Risk")
    st.write("Pulls the customer's most recent prediction, already computed by the batch scoring pipeline.")

    customer_id = st.number_input("Customer ID", min_value=1, step=1, value=1)

    if st.button("Look up", type="primary"):
        data, error = call_api("GET", f"/customers/{customer_id}/risk")

        if error:
            st.error(error)
        else:
            col1, col2, col3 = st.columns(3)
            col1.metric("Risk Tier", f"{TIER_COLORS.get(data['risk_tier'],'')} {data['risk_tier']}")
            col2.metric("Churn Probability", f"{data['churn_probability']:.1%}")
            col3.metric("Last Scored", data["scored_at"][:10])

            st.progress(min(data["churn_probability"], 1.0))

# ==========================================================================
# SCREEN 2: At-Risk Watchlist
# ==========================================================================
with tab2:
    st.header("📋 At-Risk Customer Watchlist")
    st.write("Live view of customers flagged by the model, sorted by revenue at stake.")

    col1, col2 = st.columns([1, 3])
    with col1:
        tier_filter = st.selectbox("Risk tier", ["High", "Medium", "Low", "All"])
        limit = st.slider("Max results", min_value=10, max_value=200, value=50, step=10)

    params = {"limit": limit}
    if tier_filter != "All":
        params["tier"] = tier_filter

    data, error = call_api("GET", "/customers/at-risk", params=params)

    if error:
        st.error(error)
    else:
        st.write(f"**{data['count']} customers found**")
        df = pd.DataFrame(data["customers"])
        if not df.empty:
            df["churn_probability"] = df["churn_probability"].apply(lambda p: f"{p:.1%}")
            df["monetary"] = df["monetary"].apply(lambda m: f"${m:,.2f}")
            st.dataframe(
                df[["customer_id", "risk_tier", "churn_probability", "monetary", "recency_days"]],
                use_container_width=True,
                hide_index=True,
            )
        else:
            st.info("No customers match this filter.")

# ==========================================================================
# SCREEN 3: Live What-If Predictor
# ==========================================================================
with tab3:
    st.header("🧪 Live What-If Prediction")
    st.write("Runs the trained model directly on hypothetical customer data - no database lookup involved.")

    with st.form("predict_form"):
        col1, col2 = st.columns(2)
        with col1:
            recency_days = st.number_input("Days since last order", min_value=0, value=90)
            frequency = st.number_input("Number of orders", min_value=0, value=3)
            monetary = st.number_input("Total spend ($)", min_value=0.0, value=500.0)
            avg_order_value = st.number_input("Average order value ($)", min_value=0.0, value=150.0)
        with col2:
            tenure_days = st.number_input("Days since account created", min_value=0, value=400)
            age = st.number_input("Age", min_value=18, max_value=100, value=35)
            gender = st.selectbox("Gender", ["Male", "Female", "n/a"])
            marital_status = st.selectbox("Marital status", ["Single", "Married", "n/a"])
            country = st.selectbox(
                "Country",
                ["United States", "Canada", "United Kingdom", "Germany", "France", "Australia", "n/a"],
            )

        submitted = st.form_submit_button("Predict churn risk", type="primary")

    if submitted:
        payload = {
            "recency_days": recency_days,
            "frequency": frequency,
            "monetary": monetary,
            "avg_order_value": avg_order_value,
            "tenure_days": tenure_days,
            "age": age,
            "gender": gender,
            "marital_status": marital_status,
            "country": country,
        }
        data, error = call_api("POST", "/predict", json=payload)

        if error:
            st.error(error)
        else:
            st.divider()
            col1, col2 = st.columns(2)
            col1.metric("Predicted Risk Tier", f"{TIER_COLORS.get(data['risk_tier'],'')} {data['risk_tier']}")
            col2.metric("Churn Probability", f"{data['churn_probability']:.1%}")
            st.progress(min(data["churn_probability"], 1.0))