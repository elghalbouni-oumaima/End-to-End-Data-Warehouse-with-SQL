DECLARE @StartDate DATE = '2010-01-01';
DECLARE @EndDate   DATE = '2035-12-31';

WHILE @StartDate <= @EndDate
BEGIN

    INSERT INTO gold.dim_dates
    (
        date_key,
        full_date,

        day_number,
        day_name,
        day_short,
        day_of_week,
        day_of_year,

        week_of_year,

        month_number,
        month_name,
        month_short,

        quarter_number,
        quarter_name,

        year_number,

        year_month,
        month_year,
        month_year_sort,

        is_weekend,
        is_month_start,
        is_month_end,
        is_quarter_start,
        is_quarter_end,
        is_year_start,
        is_year_end,
        is_business_day
    )

    VALUES
    (
        YEAR(@StartDate) * 10000 + MONTH(@StartDate) * 100 + DAY(@StartDate), -- CONVERT(INT, FORMAT(@StartDate,'yyyyMMdd')) IS SLOW
        @StartDate,

        DAY(@StartDate),
        DATENAME(WEEKDAY,@StartDate),
        LEFT(DATENAME(WEEKDAY,@StartDate),3),
        DATEPART(WEEKDAY,@StartDate),
        DATEPART(DAYOFYEAR,@StartDate),

        DATEPART(WEEK,@StartDate),

        MONTH(@StartDate),
        DATENAME(MONTH,@StartDate),
        LEFT(DATENAME(MONTH,@StartDate),3),

        DATEPART(QUARTER,@StartDate),
        CONCAT('Q',DATEPART(QUARTER,@StartDate)),

        YEAR(@StartDate),

        CONVERT(CHAR(7), @StartDate, 126),
        CONCAT(
            LEFT(DATENAME(MONTH,@StartDate),3),
            ' ',
            YEAR(@StartDate)
        ),
        YEAR(@StartDate) * 100 + MONTH(@StartDate),

        CASE WHEN DATEPART(WEEKDAY,@StartDate) IN (1,7) THEN 1 ELSE 0 END,

        CASE WHEN DAY(@StartDate)=1 THEN 1 ELSE 0 END,

        CASE WHEN @StartDate=EOMONTH(@StartDate) THEN 1 ELSE 0 END,

        CASE
            WHEN MONTH(@StartDate) IN (1,4,7,10)
             AND DAY(@StartDate)=1
            THEN 1 ELSE 0
        END,

        CASE
            WHEN @StartDate IN
            (
                EOMONTH(DATEFROMPARTS(YEAR(@StartDate),3,1)),
                EOMONTH(DATEFROMPARTS(YEAR(@StartDate),6,1)),
                EOMONTH(DATEFROMPARTS(YEAR(@StartDate),9,1)),
                EOMONTH(DATEFROMPARTS(YEAR(@StartDate),12,1))
            )
            THEN 1 ELSE 0
        END,

        CASE
            WHEN MONTH(@StartDate)=1
             AND DAY(@StartDate)=1
            THEN 1 ELSE 0
        END,

        CASE
            WHEN MONTH(@StartDate)=12
             AND DAY(@StartDate)=31
            THEN 1 ELSE 0
        END,
        CASE
            WHEN DATEPART(WEEKDAY,@StartDate) IN (1,7)
            THEN 0
            ELSE 1
        END

    );

    SET @StartDate = DATEADD(DAY,1,@StartDate);

END;
