/*==============================================================================
  CHURN PREDICTION - FEATURE ENGINEERING (CORRECTED for dim_dates schema)
  ------------------------------------------------------------------------
  What changed from the original version:
  gold.fact_sales no longer stores order_date/shipping_date/due_date as
  DATE values directly - it stores order_date_key/shipping_date_key/
  due_date_key, which are surrogate INT keys into gold.dim_dates. Every
  place that used to filter or compare on f.order_date now needs to
  either (a) join to dim_dates to get the actual full_date, or
  (b) compare date_key integers directly, which works because date_key
  is formatted as YYYYMMDD - so date_key ordering matches date ordering.
  This script uses (b) for filtering (faster, no extra join needed) and
  (a) only where we need the actual date value (e.g. MAX(last order date)).

  Also: dim_customers column names are birth_date (not birthdate) and
  created_date (not create_date) - matching the corrected table schema.
==============================================================================*/

CREATE TABLE gold.customer_churn_training (
    customer_id     INT PRIMARY KEY,
    recency_days    INT,
    frequency       INT,
    monetary        DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    tenure_days     INT,
    age             INT,
    gender          VARCHAR(20),
    marital_status  VARCHAR(20),
    country         VARCHAR(50),
    churned         BIT
);
GO

CREATE TABLE gold.customer_churn_scoring (
    customer_id     INT PRIMARY KEY,
    recency_days    INT,
    frequency       INT,
    monetary        DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    tenure_days     INT,
    age             INT,
    gender          VARCHAR(20),
    marital_status  VARCHAR(20),
    country         VARCHAR(50)
);
GO

CREATE TABLE gold.customer_churn_predictions (
    customer_id        INT PRIMARY KEY,
    churn_probability  DECIMAL(5,4),
    risk_tier          VARCHAR(10),
    scored_at          DATETIME
);
GO

CREATE TABLE gold.churn_feature_importance (
    feature_name VARCHAR(100),
    importance   DECIMAL(10,6),
    trained_at   DATETIME
);

CREATE OR ALTER VIEW gold.vw_customer_risk_detail AS
SELECT
    p.customer_id, p.churn_probability, p.risk_tier, p.scored_at,
    s.recency_days, s.frequency, s.monetary, s.avg_order_value, s.tenure_days, s.age
FROM gold.customer_churn_predictions p
JOIN gold.customer_churn_scoring s ON s.customer_id = p.customer_id;

/* ==========================================================================
   PROCEDURE: gold.build_churn_training_data
========================================================================== */
CREATE OR ALTER PROCEDURE gold.build_churn_training_data AS
BEGIN
    -- Resolve the actual max order date via dim_dates, not directly off fact_sales
    DECLARE @max_date_key INT = (SELECT MAX(order_date_key) FROM gold.fact_sales);
    DECLARE @max_date DATE = (SELECT full_date FROM gold.dim_dates WHERE date_key = @max_date_key);

    DECLARE @churn_window_days INT = 365;
    DECLARE @snapshot_date DATE = DATEADD(DAY, -@churn_window_days, @max_date);
    DECLARE @snapshot_date_key INT = (SELECT date_key FROM gold.dim_dates WHERE full_date = @snapshot_date);

    PRINT '>> Building churn TRAINING set';
    PRINT '   Snapshot date : ' + CAST(@snapshot_date AS VARCHAR) + ' (date_key ' + CAST(@snapshot_date_key AS VARCHAR) + ')';
    PRINT '   Label window  : ' + CAST(@snapshot_date AS VARCHAR) + ' to ' + CAST(@max_date AS VARCHAR);

    TRUNCATE TABLE gold.customer_churn_training;

    ;WITH features_before AS (
        SELECT
            c.customer_id,
            MAX(od.full_date)                                    AS last_order_date,
            DATEDIFF(DAY, MAX(od.full_date), @snapshot_date)      AS recency_days,
            COUNT(DISTINCT f.order_number)                        AS frequency,
            SUM(f.sales_amount)                                    AS monetary,
            SUM(f.sales_amount) / NULLIF(COUNT(DISTINCT f.order_number),0) AS avg_order_value,
            DATEDIFF(DAY, c.created_date, @snapshot_date)          AS tenure_days,
            DATEDIFF(YEAR, c.birth_date, @snapshot_date)            AS age,
            c.gender, c.marital_status, c.country
        FROM gold.dim_customers c
        JOIN gold.fact_sales f ON f.customer_key = c.customer_key      -- NULL customer_key rows naturally excluded
        JOIN gold.dim_dates od ON od.date_key = f.order_date_key
        WHERE f.order_date_key <= @snapshot_date_key                    -- integer compare, YYYYMMDD preserves date order
        GROUP BY c.customer_id, c.created_date, c.birth_date, c.gender, c.marital_status, c.country
    ),
    label_after AS (
        SELECT DISTINCT c.customer_id
        FROM gold.dim_customers c
        JOIN gold.fact_sales f ON f.customer_key = c.customer_key
        WHERE f.order_date_key > @snapshot_date_key AND f.order_date_key <= @max_date_key
    )
    INSERT INTO gold.customer_churn_training
        (customer_id, recency_days, frequency, monetary, avg_order_value, tenure_days, age, gender, marital_status, country, churned)
    SELECT
        fb.customer_id, fb.recency_days, fb.frequency, fb.monetary, fb.avg_order_value,
        fb.tenure_days, fb.age, fb.gender, fb.marital_status, fb.country,
        CASE WHEN la.customer_id IS NULL THEN 1 ELSE 0 END AS churned
    FROM features_before fb
    LEFT JOIN label_after la ON la.customer_id = fb.customer_id;

    PRINT '>> Training rows: ' + CAST(@@ROWCOUNT AS VARCHAR);
END;
GO

/* ==========================================================================
   PROCEDURE: gold.build_churn_scoring_data
========================================================================== */
CREATE OR ALTER PROCEDURE gold.build_churn_scoring_data AS
BEGIN
    DECLARE @max_date_key INT = (SELECT MAX(order_date_key) FROM gold.fact_sales);
    DECLARE @max_date DATE = (SELECT full_date FROM gold.dim_dates WHERE date_key = @max_date_key);

    PRINT '>> Building churn SCORING set as of ' + CAST(@max_date AS VARCHAR);

    TRUNCATE TABLE gold.customer_churn_scoring;

    INSERT INTO gold.customer_churn_scoring
        (customer_id, recency_days, frequency, monetary, avg_order_value, tenure_days, age, gender, marital_status, country)
    SELECT
        c.customer_id,
        DATEDIFF(DAY, MAX(od.full_date), @max_date)  AS recency_days,
        COUNT(DISTINCT f.order_number)                 AS frequency,
        SUM(f.sales_amount)                              AS monetary,
        SUM(f.sales_amount) / NULLIF(COUNT(DISTINCT f.order_number),0) AS avg_order_value,
        DATEDIFF(DAY, c.created_date, @max_date)          AS tenure_days,
        DATEDIFF(YEAR, c.birth_date, @max_date)             AS age,
        c.gender, c.marital_status, c.country
    FROM gold.dim_customers c
    JOIN gold.fact_sales f ON f.customer_key = c.customer_key
    JOIN gold.dim_dates od ON od.date_key = f.order_date_key
    GROUP BY c.customer_id, c.created_date, c.birth_date, c.gender, c.marital_status, c.country;

    PRINT '>> Scoring rows: ' + CAST(@@ROWCOUNT AS VARCHAR);
END;
GO

EXEC gold.build_churn_training_data;
EXEC gold.build_churn_scoring_data;
SELECT churned, COUNT(*) as perct FROM gold.customer_churn_training GROUP BY churned;


/* ==========================================================================
   DIAGNOSTIC: run first to sanity-check the 180-day churn window assumption.
========================================================================== */
/*
;WITH order_gaps AS (
    SELECT
        f.customer_key,
        od.full_date AS order_date,
        DATEDIFF(DAY, LAG(od.full_date) OVER (PARTITION BY f.customer_key ORDER BY od.full_date), od.full_date) AS days_since_prev_order
    FROM gold.fact_sales f
    JOIN gold.dim_dates od ON od.date_key = f.order_date_key
    WHERE f.customer_key IS NOT NULL
)
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev_order) OVER () AS median_gap_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_since_prev_order) OVER () AS p90_gap_days
FROM order_gaps
WHERE days_since_prev_order IS NOT NULL;
*/