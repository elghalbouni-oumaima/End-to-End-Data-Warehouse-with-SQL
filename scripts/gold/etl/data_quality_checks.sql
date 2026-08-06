/*==============================================================================
  DATA QUALITY FRAMEWORK - GOLD LAYER
  ------------------------------------------------------------------------
  Contains:
    1. dq_check_results  - stores the outcome of every check, every run
    2. gold.run_data_quality_checks - runs all checks, logs results, prints
       a summary

  Design:
  Each check counts how many rows VIOLATE a rule. 0 violations = PASS.
  Every check writes one row to dq_check_results, tagged with a run_id so
  you can see the full result set of a single execution together, and
  compare results across runs over time.

  Categories used (standard DQ dimensions):
    Completeness         - is data missing where it shouldn't be?
    Uniqueness            - are keys actually unique?
    Validity                - do values fall within expected domains/ranges?
    Referential Integrity     - do foreign keys resolve to real parent rows?
    Consistency                - do related fields agree with each other?

  Severity:
    CRITICAL - breaks joins, breaks aggregates, or is structurally invalid.
               Worth failing a pipeline / blocking a report over.
    WARNING  - real data quality issue, but not immediately dangerous.

  Execution:
      EXEC gold.run_data_quality_checks;
      -- Then review results:
      SELECT * FROM dq_check_results WHERE run_id = (SELECT TOP 1 run_id FROM dq_check_results ORDER BY executed_at DESC) ORDER BY status, severity DESC;
==============================================================================*/

/* ------------------------------------------------------------------------
   1. Results table
------------------------------------------------------------------------ */
CREATE TABLE dq_check_results (
    check_id           INT IDENTITY(1,1) PRIMARY KEY,
    run_id             UNIQUEIDENTIFIER NOT NULL,
    layer              VARCHAR(20)   NOT NULL,
    table_name         VARCHAR(100)  NOT NULL,
    check_name         VARCHAR(200)  NOT NULL,
    check_category     VARCHAR(50)   NOT NULL,
    severity           VARCHAR(20)   NOT NULL,
    failed_records     INT           NOT NULL,
    status             VARCHAR(10)   NOT NULL,   -- PASS / FAIL
    check_description  NVARCHAR(500) NULL,
    executed_at        DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

/* ------------------------------------------------------------------------
   2. Check runner procedure
------------------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE gold.run_data_quality_checks AS
DECLARE
    @run_id UNIQUEIDENTIFIER = NEWID(),
    @failed_count INT,
    @total_checks INT = 0,
    @passed_checks INT = 0,
    @failed_checks INT = 0,
    @critical_failures INT = 0;

BEGIN
BEGIN TRY

    PRINT '===========================================================================';
    PRINT 'RUNNING DATA QUALITY CHECKS - GOLD LAYER';
    PRINT '===========================================================================';

    /* ======================================================================
       DIM_CUSTOMERS
    ====================================================================== */

    -- Check 1: duplicate business keys (should be impossible given UNIQUE constraint,
    -- but this is a regression check - the constraint is the guardrail, this is the alarm)
    SELECT @failed_count = COUNT(*) FROM (
        SELECT customer_id FROM gold.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1
    ) t;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_customers', 'Duplicate customer_id', 'Uniqueness', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'customer_id must be unique - duplicates indicate a broken MERGE match condition.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 2: missing customer_number
    SELECT @failed_count = COUNT(*) FROM gold.dim_customers WHERE customer_number IS NULL OR LTRIM(RTRIM(customer_number)) = '';
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_customers', 'Missing customer_number', 'Completeness', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Every customer should have a business-facing customer_number.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 3: invalid gender values
    SELECT @failed_count = COUNT(*) FROM gold.dim_customers WHERE gender NOT IN ('Male','Female','n/a') OR gender IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_customers', 'Invalid gender value', 'Validity', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'gender must be one of: Male, Female, n/a.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 4: birthdate in the future
    SELECT @failed_count = COUNT(*) FROM gold.dim_customers WHERE birthdate > GETDATE();
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_customers', 'Future birthdate', 'Validity', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'birthdate should never be later than today.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 5: missing country
    SELECT @failed_count = COUNT(*) FROM gold.dim_customers WHERE country IS NULL OR country = 'n/a';
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_customers', 'Missing country', 'Completeness', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Customers with no resolvable country - informational, may be expected for some source rows.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    /* ======================================================================
       DIM_PRODUCTS
    ====================================================================== */

    -- Check 6: duplicate business keys
    SELECT @failed_count = COUNT(*) FROM (
        SELECT product_id FROM gold.dim_products GROUP BY product_id HAVING COUNT(*) > 1
    ) t;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_products', 'Duplicate product_id', 'Uniqueness', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'product_id must be unique - duplicates indicate a broken MERGE match condition.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 7: negative product cost
    SELECT @failed_count = COUNT(*) FROM gold.dim_products WHERE product_cost < 0;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_products', 'Negative product_cost', 'Validity', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'product_cost cannot be negative.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 8: missing product name
    SELECT @failed_count = COUNT(*) FROM gold.dim_products WHERE product_name IS NULL OR LTRIM(RTRIM(product_name)) = '';
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_products', 'Missing product_name', 'Completeness', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Every product should have a display name.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 9: invalid product line
    SELECT @failed_count = COUNT(*) FROM gold.dim_products WHERE product_line NOT IN ('Other Sales','Mountain','Road','Touring','n/a') OR product_line IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'dim_products', 'Invalid product_line', 'Validity', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'product_line must be one of the 5 standardized categories.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    /* ======================================================================
       FACT_SALES
    ====================================================================== */

    -- Check 10: orphaned customer_key (points to a row that doesn't exist)
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales f
    WHERE f.customer_key IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key);
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Orphaned customer_key', 'Referential Integrity', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Every non-null customer_key in fact_sales must exist in dim_customers.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 11: orphaned product_key
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales f
    WHERE f.product_key IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key);
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Orphaned product_key', 'Referential Integrity', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Every non-null product_key in fact_sales must exist in dim_products.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 12: unmatched customer lookups (NULL customer_key rate)
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE customer_key IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Unmatched customer lookup', 'Completeness', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Sales rows where sls_cust_id did not match any dim_customers.customer_id.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 13: unmatched product lookups (NULL product_key rate)
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE product_key IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Unmatched product lookup', 'Completeness', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Sales rows where sls_prd_key did not match any dim_products.product_number.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 14: negative or zero sales_amount
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE sales_amount <= 0 OR sales_amount IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Non-positive sales_amount', 'Validity', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'sales_amount must be a positive number.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 15: negative or zero quantity
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE quantity <= 0 OR quantity IS NULL;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Non-positive quantity', 'Validity', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'quantity must be a positive whole number.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 16: sales_amount doesn't equal quantity x price (beyond rounding tolerance)
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales
    WHERE ABS(ISNULL(sales_amount,0) - (ISNULL(quantity,0) * ISNULL(price,0))) > 0.01;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'sales_amount <> quantity x price', 'Consistency', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'sales_amount should equal quantity multiplied by price, within rounding tolerance.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 17: duplicate order lines (same order + product appearing more than once)
    SELECT @failed_count = COUNT(*) FROM (
        SELECT order_number, product_key FROM gold.fact_sales GROUP BY order_number, product_key HAVING COUNT(*) > 1
    ) t;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'Duplicate order line', 'Uniqueness', 'CRITICAL', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'The same order_number + product_key combination should appear at most once. Note: SQL Server unique constraints allow multiple NULLs, so NULL product_key duplicates can slip past the table constraint - this check catches those.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE BEGIN SET @failed_checks += 1; SET @critical_failures += 1; END

    -- Check 18: shipping_date before order_date
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE shipping_date < order_date;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'shipping_date before order_date', 'Validity', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'A product cannot ship before it was ordered.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    -- Check 19: due_date before order_date
    SELECT @failed_count = COUNT(*) FROM gold.fact_sales WHERE due_date < order_date;
    INSERT INTO dq_check_results (run_id, layer, table_name, check_name, check_category, severity, failed_records, status, check_description)
    VALUES (@run_id, 'gold', 'fact_sales', 'due_date before order_date', 'Validity', 'WARNING', @failed_count,
        CASE WHEN @failed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        'An order cannot be due before it was placed.');
    SET @total_checks += 1; IF @failed_count = 0 SET @passed_checks += 1; ELSE SET @failed_checks += 1;

    /* ======================================================================
       SUMMARY
    ====================================================================== */
    PRINT '===========================================================================';
    PRINT 'DATA QUALITY SUMMARY';
    PRINT '  Total checks run : ' + CAST(@total_checks AS VARCHAR);
    PRINT '  Passed           : ' + CAST(@passed_checks AS VARCHAR);
    PRINT '  Failed           : ' + CAST(@failed_checks AS VARCHAR);
    PRINT '  Critical failures: ' + CAST(@critical_failures AS VARCHAR);
    PRINT '  Run ID           : ' + CAST(@run_id AS VARCHAR(50));
    PRINT '===========================================================================';

    IF @critical_failures > 0
        PRINT '>> WARNING: One or more CRITICAL checks failed. Review dq_check_results before trusting this data for reporting.';
    ELSE
        PRINT '>> All critical checks passed.';

    -- Show the failing checks immediately, if any
    SELECT table_name, check_name, check_category, severity, failed_records, status, check_description
    FROM dq_check_results
    WHERE run_id = @run_id AND status = 'FAIL'
    ORDER BY severity DESC, table_name;

END TRY
BEGIN CATCH
    PRINT '===========================================================================';
    PRINT 'ERROR RUNNING DATA QUALITY CHECKS';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT '===========================================================================';
END CATCH
END;
GO
--EXEC gold.run_data_quality_checks;