# Customer Churn Prediction — Design Log & Case Study

This document captures the full churn prediction feature built on top of the
Gold layer of the SQL Data Warehouse project: what was built, and — more
importantly — **why each decision was made**. Written to be re-readable
months later, e.g. before a technical interview, without needing to
reconstruct the reasoning from scratch.

---

## 1. Why churn prediction belongs here

The Gold layer (`dim_customers`, `dim_products`, `dim_dates`, `fact_sales`)
is a conformed star schema — exactly the kind of clean, join-ready data that
data science work depends on. Rather than treating the warehouse as an
endpoint, this extends it one layer further: **Data Engineering → Data
Science → BI**, with the Gold layer acting as the shared foundation for both
downstream consumers.

---

## 2. Two foundational decisions (get these wrong and the model lies to us)

### 2.1 Defining "churn" behaviorally

This dataset has no subscription end date or cancellation event — customers
either keep buying or gradually stop. So churn has to be defined
behaviorally: **a customer is "churned" if they don't return to buy within
some window of days.** The hard part isn't the definition, it's picking the
right window — solved with data in section 4.

### 2.2 Avoiding label leakage

**The mistake to avoid:** if churn is defined as "no purchase in the last N
days," and "days since last purchase" (`recency_days`) is also used as a
model *feature*, the model doesn't learn anything — it just rediscovers its
own label definition. This is the single most common churn-modeling mistake.

**The fix — a time-based snapshot split:**

```
|<---- feature window (before snapshot) ---->|<---- label window (after snapshot) ---->|
earliest_order                          snapshot_date                            latest_order
```

- Features (`recency_days`, `frequency`, `monetary`, etc.) are computed using
  only data **before** a chosen snapshot date.
- The label (`churned`) is based on whether the customer **actually came
  back** and bought something in the window **after** the snapshot.

This makes it a genuine forward-looking prediction — the model predicts
future behavior from past behavior, rather than restating its own label.

---

## 3. Feature engineering — SQL, and why it went through two schema versions

### 3.1 First version (raw dates)

The first version of `gold.fact_sales` stored `order_date`, `shipping_date`,
`due_date` as plain `DATE` columns. Features were computed by filtering
directly on those columns.

### 3.2 Schema evolved to a proper date dimension

The Gold layer was later upgraded to snowflake dates through `gold.dim_dates`
(a full calendar dimension: day/week/month/quarter, weekend flags, etc.),
with `fact_sales` storing surrogate `order_date_key` / `shipping_date_key` /
`due_date_key` integers (`YYYYMMDD` format) instead of raw dates.

**This required updating every churn query that used dates:**

- Filtering: `f.order_date_key <= @snapshot_date_key` — comparing integers
  directly works because `YYYYMMDD` ordering matches date ordering, and it's
  faster than joining to `dim_dates` just to filter.
- Getting an actual date value (e.g. for `DATEDIFF`): requires
  `JOIN gold.dim_dates od ON od.date_key = f.order_date_key`, then using
  `od.full_date`.

**Lesson:** feature-engineering SQL is coupled to the warehouse schema. When
the star schema changes shape, every downstream ML query needs to be
re-verified, not just the BI/reporting layer.

### 3.3 Final feature set (per customer)

| Feature | Definition |
|---|---|
| `recency_days` | Days between last order and snapshot date |
| `frequency` | Count of distinct orders |
| `monetary` | Total sales amount |
| `avg_order_value` | `monetary / frequency` |
| `tenure_days` | Days between customer creation and snapshot date |
| `age` | Computed from `birth_date` |
| `gender`, `marital_status`, `country` | Demographic, one-hot encoded at training time |

### 3.4 Two separate feature tables, on purpose

- **`gold.customer_churn_training`** — features as of a *past* snapshot date,
  with a real label (used to train and evaluate the model).
- **`gold.customer_churn_scoring`** — the same features, computed as of *now*
  (the latest date in the data), with **no label** — because the future
  hasn't happened yet. This is what the trained model actually predicts on,
  to flag real customers as at-risk today.

Using one dataset for both would either leak the label into "current" scoring
(impossible — there's no future data yet) or apply stale, outdated features to
training (wrong window). Keeping them as two separate builds keeps each
correct for its purpose.

---

## 4. Choosing the churn window — data-driven, not guessed

### 4.1 Initial guess: 180 days

Started as a reasonable-sounding default, not a measured value.

### 4.2 Diagnostic: measuring real reorder gaps

```sql
;WITH customer_orders AS (
    SELECT DISTINCT f.customer_key, od.full_date AS order_date
    FROM gold.fact_sales f
    JOIN gold.dim_dates od ON od.date_key = f.order_date_key
    WHERE f.customer_key IS NOT NULL
),
order_gaps AS (
    SELECT
        customer_key, order_date,
        DATEDIFF(DAY, LAG(order_date) OVER (PARTITION BY customer_key ORDER BY order_date), order_date) AS days_since_prev_order
    FROM customer_orders
)
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev_order) OVER () AS median_gap_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_since_prev_order) OVER () AS p90_gap_days
FROM order_gaps
WHERE days_since_prev_order IS NOT NULL;
```

**Bug caught along the way:** the first version of this query didn't
deduplicate `fact_sales` down to one row per order first — since `fact_sales`
is at the *order line* grain (multiple products per order = multiple rows,
same date), `LAG()` compared line items within the *same* order to each
other, producing a flood of artificial `0`-day gaps and dragging the median
to `0`. Fixed with `SELECT DISTINCT (customer_key, order_date)` before
computing gaps. **Lesson:** always know the grain of the table we're
aggregating over before applying window functions.

**Result:** `median_gap_days = 255`, `p90_gap_days = 702`.

Interpretation: this is a durable-goods retailer (bikes) — a *typical*
repeat customer only reorders roughly twice a year. A churn window that
looks aggressive for, say, a subscription business is actually normal here.

### 4.3 Feasibility check: does the data span enough history?

A churn window `W` requires roughly `2 × W` days of total order history (a
feature window before the snapshot, and a full label window of length `W`
after it). Checked with:

```sql
SELECT DATEDIFF(DAY, MIN(od.full_date), MAX(od.full_date)) AS total_days_span
FROM gold.fact_sales f
JOIN gold.dim_dates od ON od.date_key = f.order_date_key;
```

**Result:** `total_days_span = 1126` days (~3.1 years).

Using `p90 = 702` would need `~1404` days minimum — **not available**. Even
if it barely fit, it would leave only `1126 − 702 = 424` days of feature
history — under 2 reorder cycles given the 255-day median, too little to
compute a meaningful `frequency`/`monetary`.

### 4.4 Final decision: 365 days

Landed between the median (255) and the infeasible p90 (702):
- Comfortably above the median — a customer flagged as churned has genuinely
  gone quiet beyond their normal rhythm.
- Leaves `1126 − 365 = 761` days of feature window — about 3 reorder cycles,
  enough for `frequency`/`monetary` to carry real signal.

```sql
DECLARE @churn_window_days INT = 365;
```

**Lesson:** the "right" threshold is a negotiation between statistical
ideal (p90) and what your actual data volume can support — not a fixed
industry rule.

---

## 5. Class balance

```sql
SELECT churned, COUNT(*) FROM gold.customer_churn_training GROUP BY churned;
```

**Result:** 15.8% churned / 84.2% retained — realistic for this kind of
business, and not severely imbalanced.

Two safeguards built into the training script specifically because of this:
- `train_test_split(..., stratify=y)` — keeps the same 15.8/84.2 ratio in
  both train and test sets, so the test set isn't accidentally starved of
  churned examples.
- `class_weight="balanced"` in `RandomForestClassifier` — forces the model
  to weight the minority (churned) class proportionally more, preventing the
  lazy shortcut of mostly predicting "not churned" while still looking
  falsely "accurate."

**Why accuracy alone would be misleading here:** a model that always
predicts "not churned" would already score 84.2% accuracy while being
completely useless. This is why evaluation used `classification_report`
(precision/recall/F1 per class) and ROC-AUC instead of relying on plain
accuracy.

---

## 6. Model, training, and results

**Model:** `RandomForestClassifier(n_estimators=300, max_depth=8,
class_weight="balanced", random_state=42)`

### Results

```
              precision    recall  f1-score   support
    Retained       0.99      0.94      0.97       955
     Churned       0.76      0.97      0.85       180
    accuracy                           0.95      1135

ROC-AUC: 0.984

Confusion matrix:
[[900  55]
 [  6 174]]
```

**How to read this:**
- **Recall on Churned = 0.97** is the headline number for this use case —
  out of 180 truly churned customers in the test set, 174 were correctly
  caught. Missing a churner is costlier than a false alarm (we can't win
  back someone we never flagged), so high recall on the minority class
  matters more than raw accuracy.
- **Precision on Churned = 0.76** — of everyone flagged as churn-risk, 76%
  actually were. The other 24% are false alarms, a reasonable and expected
  trade-off from prioritizing recall via `class_weight="balanced"`.
- **ROC-AUC = 0.984** — near-ceiling separation between the two classes
  across all thresholds, indicating the engineered features carry strong,
  genuine predictive signal (not overfit noise).

### Feature importance

```
tenure_days               0.32
recency_days              0.28
country_Australia         0.076
monetary                  0.069
avg_order_value           0.063
country_Canada            0.052
frequency                 0.044
country_United States     0.038
age                       0.019
country_United Kingdom    0.009
```

`tenure_days` and `recency_days` together drive ~60% of the model's
decisions — intuitive for a business with an infrequent purchase cycle.

**Caveat investigated and resolved:** `country_Australia` ranked above
`monetary` and `frequency` in feature importance, which was unusual enough
to verify rather than trust outright — a single country outranking how much
or how often someone spends could easily be a small-sample artifact, where a
tree latches onto a low-count category by chance. Checked with:

```sql
SELECT country, COUNT(*) AS customers, AVG(CAST(churned AS FLOAT)) AS churn_rate
FROM gold.customer_churn_training
GROUP BY country
ORDER BY customers DESC;
```

**Result:** Australia is the largest country segment (1,916 of 5,671
training customers, ~34%) with a churn rate of 4.0% — well below the 15.8%
baseline. Large sample, large deviation from baseline: the importance score
is a genuine signal, not noise.

---

## 7. Scoring current customers and the risk-tier bug

### 7.1 First attempt: fixed probability thresholds

```python
score_df["risk_tier"] = pd.cut(
    score_df["churn_probability"],
    bins=[0, 0.4, 0.7, 1.0],
    labels=["Low", "Medium", "High"],
)
```

**Result:** 17,908 Low / 573 Medium / **1 High** — clearly broken for a
dataset with a 15.8% churn rate.

### 7.2 Diagnosis

Checked the actual probability distribution:

```sql
SELECT TOP 1
    MIN(churn_probability) OVER() AS min_prob,
    AVG(churn_probability) OVER() AS avg_prob,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY churn_probability) OVER() AS median_prob,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY churn_probability) OVER() AS p90_prob,
    MAX(churn_probability) OVER() AS max_prob
FROM gold.customer_churn_predictions;
```

**Result:** `min=0.0046, median=0.1724, p90=0.2616, max=0.7084`.

The entire probability distribution sat well under the 0.4 "Medium"
threshold — `RandomForestClassifier` tends to produce compressed, less
spread-out probabilities than something like logistic regression, so fixed
thresholds picked without seeing the real distribution were simply wrong for
this model's output range.

### 7.3 Fix: percentile-based tiers

```python
score_df["risk_tier"] = pd.qcut(
    score_df["churn_probability"],
    q=[0, 0.70, 0.90, 1.0],
    labels=["Low", "Medium", "High"],
    duplicates="drop",
)
```

Ranks customers **relative to each other** instead of against an absolute
number — bottom 70% = Low, next 20% = Medium, top 10% = High. This also
matches how a retention team would actually want to use this ("who are our
riskiest customers right now") rather than an arbitrary universal cutoff.

**Result after fix:** 12,941 Low / 3,692 Medium / 1,849 High — matching the
intended 70/20/10 split almost exactly (70/20/10 of 18,482 ≈
12,937/3,696/1,848). Now genuinely usable as a "customers at risk" list.

**Lesson:** always inspect the actual output distribution of a probabilistic
model before setting business-facing thresholds on it. A threshold that
sounds reasonable in the abstract ("above 70% risk = High") can be
completely miscalibrated for a specific model's real output range.

---

## 8. Operational note: SQL Server connection troubleshooting

Ran into `pyodbc.OperationalError: Named Pipes Provider: Could not open a
connection` when first running the Python script. Root cause: SQL Server
Express uses a **named instance** (`localhost\SQLEXPRESS`) by default, not
a blank/default instance — the initial connection string only specified
`localhost`. Fixed by:
1. Confirming the real server name from SSMS's login screen.
2. Building the connection string as a raw ODBC string and URL-encoding it
   for SQLAlchemy, rather than embedding the instance name directly in a
   SQLAlchemy URL (backslashes in named instances don't play well with plain
   URL syntax).

Not a modeling decision, but a real deployment/environment lesson worth
remembering: **local dev database connections often silently assume a
default instance that doesn't actually exist on Express installs.**

---

## 9. Full pipeline, end to end

```
Raw CSVs (CRM/ERP)
    → Bronze (full reload, BULK INSERT)
    → Silver (incremental MERGE, cleansing, dedup, business rules)
    → Gold (star schema: dim_customers, dim_products, dim_dates, fact_sales;
             incremental MERGE with surrogate IDENTITY keys)
    → Data Quality checks (19 automated checks across completeness,
             uniqueness, validity, referential integrity, consistency)
    → Churn feature engineering (leakage-free time-split)
    → Model training + evaluation (RandomForest, stratified split,
             class-balanced)
    → Scoring (percentile-based risk tiers)
    → Predictions written back to gold.customer_churn_predictions
    → Power BI dashboard (customer analytics + "Customers at Risk" page)
```

## 10. Open follow-ups (not yet done)

- [ ] Decide and document a re-run cadence for the churn scoring script
      (manual vs. run automatically after every `gold.load_gold`).
- [ ] Consider comparing `RandomForestClassifier` against a simpler
      `LogisticRegression` baseline — easier to explain to a non-technical
      stakeholder ("higher recency + lower frequency = higher churn odds"),
      and worth reporting which one was chosen and why.
