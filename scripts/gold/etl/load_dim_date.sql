/*==============================================================================
  Populate gold.dim_dates
  ------------------------------------------------------------------------
  Generates one row per calendar day across a wide range so it comfortably
  covers the source data's order/ship/due dates. Adjust @start_date /
  @end_date if the data falls outside this window.

  Note on is_weekend: computed by DATENAME(WEEKDAY, ...) matching against
  'Saturday'/'Sunday' rather than a numeric weekday comparison. Numeric
  weekday numbering depends on the server's @@DATEFIRST setting (which
  varies by language/region), so a hardcoded "IN (1,7)" check can silently
  give wrong answers on a server configured differently than expected.
  Comparing day names sidesteps that entirely.
==============================================================================*/

DECLARE @start_date DATE = '2010-01-01';
DECLARE @end_date   DATE = '2035-12-31';

;WITH date_seq AS (
    SELECT @start_date AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM date_seq
    WHERE full_date < @end_date
)
INSERT INTO gold.dim_dates (
    date_key, full_date, day_number, day_name, day_short, day_of_week, day_of_year,
    week_of_year, month_number, month_name, month_short, quarter_number, quarter_name,
    year_number, year_month, month_year, month_year_sort,
    is_weekend, is_business_day, is_month_start, is_month_end,
    is_quarter_start, is_quarter_end, is_year_start, is_year_end
)
SELECT
    CONVERT(INT, FORMAT(full_date, 'yyyyMMdd'))         AS date_key,
    full_date,
    DATEPART(DAY, full_date)                             AS day_number,
    DATENAME(WEEKDAY, full_date)                          AS day_name,
    LEFT(DATENAME(WEEKDAY, full_date), 3)                  AS day_short,
    DATEPART(WEEKDAY, full_date)                            AS day_of_week,
    DATEPART(DAYOFYEAR, full_date)                           AS day_of_year,
    DATEPART(WEEK, full_date)                                 AS week_of_year,
    MONTH(full_date)                                           AS month_number,
    DATENAME(MONTH, full_date)                                  AS month_name,
    LEFT(DATENAME(MONTH, full_date), 3)                          AS month_short,
    DATEPART(QUARTER, full_date)                                  AS quarter_number,
    'Q' + CAST(DATEPART(QUARTER, full_date) AS CHAR(1))            AS quarter_name,
    YEAR(full_date)                                                 AS year_number,
    FORMAT(full_date, 'yyyy-MM')                                     AS year_month,
    FORMAT(full_date, 'MMM yyyy')                                     AS month_year,
    YEAR(full_date) * 100 + MONTH(full_date)                           AS month_year_sort,
    CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday','Sunday') THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday','Sunday') THEN 0 ELSE 1 END AS is_business_day,
    CASE WHEN DAY(full_date) = 1 THEN 1 ELSE 0 END                        AS is_month_start,
    CASE WHEN full_date = EOMONTH(full_date) THEN 1 ELSE 0 END             AS is_month_end,
    CASE WHEN full_date = DATEFROMPARTS(YEAR(full_date), ((DATEPART(QUARTER, full_date)-1)*3)+1, 1) THEN 1 ELSE 0 END AS is_quarter_start,
    CASE WHEN full_date = EOMONTH(DATEFROMPARTS(YEAR(full_date), DATEPART(QUARTER, full_date)*3, 1)) THEN 1 ELSE 0 END AS is_quarter_end,
    CASE WHEN full_date = DATEFROMPARTS(YEAR(full_date), 1, 1) THEN 1 ELSE 0 END   AS is_year_start,
    CASE WHEN full_date = DATEFROMPARTS(YEAR(full_date), 12, 31) THEN 1 ELSE 0 END  AS is_year_end
FROM date_seq
OPTION (MAXRECURSION 0);

PRINT '>> dim_dates populated: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';