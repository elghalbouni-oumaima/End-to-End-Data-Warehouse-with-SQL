
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


SELECT DATEDIFF(DAY, MIN(od.full_date), MAX(od.full_date)) AS total_days_span
FROM gold.fact_sales f
JOIN gold.dim_dates od ON od.date_key = f.order_date_key;

SELECT country, COUNT(*) AS customers, AVG(CAST(churned AS FLOAT)) AS churn_rate
FROM gold.customer_churn_training
GROUP BY country
ORDER BY customers DESC;

