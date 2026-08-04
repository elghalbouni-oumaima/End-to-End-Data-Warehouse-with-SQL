/*==============================================================================
  Procedure Name : gold.load_gold
  Layer          : Gold (Star Schema)
  Type           : ETL Load Procedure (Incremental / MERGE-based)

  Description:
  Materializes the Gold star schema (dim_customers, dim_products, fact_sales)
  as physical tables, loaded incrementally from Silver via MERGE.

  Load order matters:
    1. dim_customers  - no dependencies
    2. dim_products   - no dependencies
    3. fact_sales     - depends on dim_customers and dim_products already
                         being up to date, since it looks up their surrogate
                         keys. Each MERGE commits before the next runs, so
                         this works correctly within a single procedure call
                         as long as the order stays customers -> products -> sales.

  Execution:
      EXEC gold.load_gold;
==============================================================================*/
CREATE OR ALTER PROCEDURE gold.load_gold AS
DECLARE
    @end_time DATETIME, @start_time DATETIME,
    @batch_end_time DATETIME, @batch_start_time DATETIME,
    @rows_inserted INT, @rows_updated INT, @current_table VARCHAR(100);
DECLARE @merge_output TABLE (action_type VARCHAR(10));

BEGIN
BEGIN TRY

    PRINT '===========================================================================';
    PRINT 'LOADING GOLD LAYER';
    PRINT '===========================================================================';
    SET @batch_start_time = GETDATE();

    /* ======================================================================
       DIM: dim_customers   (key: customer_id -> customer_key IDENTITY)
    ====================================================================== */
    SET @current_table = 'dim_customers';
    SET @start_time = GETDATE();
    PRINT '>> MERGING TABLE gold.dim_customers';

    ;WITH customer_source AS (
        SELECT
            m.cst_id            AS customer_id,
            m.cst_key           AS customer_number,
            m.cst_firstname     AS firstname,
            m.cst_lastname      AS lastname,
            m.cst_marital_status AS marital_status,
            b.cntry              AS country,
            CASE WHEN m.cst_gndr <> 'n/a' THEN m.cst_gndr
                 ELSE COALESCE(a.gen, 'n/a') END AS gender,
            a.bdate               AS birthdate,
            m.cst_create_date     AS create_date
        FROM silver.crm_cust_info m
        LEFT JOIN silver.erp_cust_az12 a ON m.cst_key = a.cid
        LEFT JOIN silver.erp_loc_a101 b  ON b.cid = m.cst_key
    )
    MERGE INTO gold.dim_customers AS target
    USING customer_source AS source
          ON target.customer_id = source.customer_id
    WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
            target.customer_number, target.firstname, target.lastname, target.marital_status,
            ISNULL(target.country,''), target.gender, ISNULL(CONVERT(VARCHAR(10), target.birthdate, 120),''),
            CONVERT(VARCHAR(10), target.create_date, 120)))
        <> HASHBYTES('SHA2_256', CONCAT_WS('|',
            source.customer_number, source.firstname, source.lastname, source.marital_status,
            ISNULL(source.country,''), source.gender, ISNULL(CONVERT(VARCHAR(10), source.birthdate, 120),''),
            CONVERT(VARCHAR(10), source.create_date, 120)))
    THEN UPDATE SET
        customer_number = source.customer_number,
        firstname        = source.firstname,
        lastname         = source.lastname,
        marital_status   = source.marital_status,
        country          = source.country,
        gender           = source.gender,
        birthdate        = source.birthdate,
        create_date      = source.create_date
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (customer_id, customer_number, firstname, lastname, marital_status, country, gender, birthdate, create_date)
        VALUES (source.customer_id, source.customer_number, source.firstname, source.lastname,
                source.marital_status, source.country, source.gender, source.birthdate, source.create_date)
    OUTPUT $action INTO @merge_output(action_type);

    SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
    SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
    SET @end_time = GETDATE();
    UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
        rows_inserted = @rows_inserted, rows_updated = @rows_updated,
        run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
    WHERE table_name = @current_table AND layer = 'gold';
    PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
    DELETE FROM @merge_output;
    PRINT '-----------------------------------------';

    /* ======================================================================
       DIM: dim_products   (key: product_id -> product_key IDENTITY)
    ====================================================================== */
    SET @current_table = 'dim_products';
    SET @start_time = GETDATE();
    PRINT '>> MERGING TABLE gold.dim_products';

    ;WITH product_source AS (
        SELECT
            m.prd_id       AS product_id,
            m.prd_key      AS product_number,
            m.prd_nm       AS product_name,
            m.cat_id       AS category_id,
            a.cat          AS category,
            a.subcat       AS subcategory,
            a.maintenance  AS maintenance,
            m.prd_cost     AS product_cost,
            m.prd_line     AS product_line,
            m.prd_start_dt AS product_start_date
        FROM silver.crm_prd_info AS m
        LEFT JOIN silver.erp_px_cat_g1v2 a ON m.cat_id = a.id
        WHERE m.prd_end_dt IS NULL   -- active products only
    )
    MERGE INTO gold.dim_products AS target
    USING product_source AS source
          ON target.product_id = source.product_id
    WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
            target.product_number, target.product_name, ISNULL(target.category_id,''),
            ISNULL(target.category,''), ISNULL(target.subcategory,''), ISNULL(target.maintenance,''),
            CAST(target.product_cost AS VARCHAR), target.product_line,
            CONVERT(VARCHAR(10), target.product_start_date, 120)))
        <> HASHBYTES('SHA2_256', CONCAT_WS('|',
            source.product_number, source.product_name, ISNULL(source.category_id,''),
            ISNULL(source.category,''), ISNULL(source.subcategory,''), ISNULL(source.maintenance,''),
            CAST(source.product_cost AS VARCHAR), source.product_line,
            CONVERT(VARCHAR(10), source.product_start_date, 120)))
    THEN UPDATE SET
        product_number      = source.product_number,
        product_name         = source.product_name,
        category_id          = source.category_id,
        category               = source.category,
        subcategory            = source.subcategory,
        maintenance             = source.maintenance,
        product_cost             = source.product_cost,
        product_line              = source.product_line,
        product_start_date         = source.product_start_date,
        updated_at                  = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (product_id, product_number, product_name, category_id, category, subcategory,
                maintenance, product_cost, product_line, product_start_date, updated_at)
        VALUES (source.product_id, source.product_number, source.product_name, source.category_id,
                source.category, source.subcategory, source.maintenance, source.product_cost,
                source.product_line, source.product_start_date, SYSUTCDATETIME())
    OUTPUT $action INTO @merge_output(action_type);

    SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
    SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
    SET @end_time = GETDATE();
    UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
        rows_inserted = @rows_inserted, rows_updated = @rows_updated,
        run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
    WHERE table_name = @current_table AND layer = 'gold';
    PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
    DELETE FROM @merge_output;
    PRINT '-----------------------------------------';

    /* ======================================================================
       FACT: fact_sales   (key: order_number + product_key)
       Depends on dim_customers and dim_products already being current -
       must run AFTER both blocks above.
    ====================================================================== */
    SET @current_table = 'fact_sales';
    SET @start_time = GETDATE();
    PRINT '>> MERGING TABLE gold.fact_sales';

    ;WITH order_source AS (
        SELECT
            m.sls_ord_num  AS order_number,
            b.product_key,
            a.customer_key,
            m.sls_order_dt AS order_date,
            m.sls_ship_dt  AS shipping_date,
            m.sls_due_dt   AS due_date,
            m.sls_sales    AS sales_amount,
            m.sls_quantity AS quantity,
            m.sls_price    AS price
        FROM silver.crm_sales_details m
        LEFT JOIN gold.dim_customers a ON a.customer_id = m.sls_cust_id
        LEFT JOIN gold.dim_products b  ON b.product_number = m.sls_prd_key
    )
    MERGE INTO gold.fact_sales AS target
    USING order_source AS source
          ON target.order_number = source.order_number
         AND ISNULL(target.product_key,-1) = ISNULL(source.product_key,-1)
    WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
            ISNULL(target.customer_key,-1), CONVERT(VARCHAR(10), target.order_date, 120),
            CONVERT(VARCHAR(10), target.shipping_date, 120), CONVERT(VARCHAR(10), target.due_date, 120),
            CAST(target.sales_amount AS VARCHAR), CAST(target.quantity AS VARCHAR), CAST(target.price AS VARCHAR)))
        <> HASHBYTES('SHA2_256', CONCAT_WS('|',
            ISNULL(source.customer_key,-1), CONVERT(VARCHAR(10), source.order_date, 120),
            CONVERT(VARCHAR(10), source.shipping_date, 120), CONVERT(VARCHAR(10), source.due_date, 120),
            CAST(source.sales_amount AS VARCHAR), CAST(source.quantity AS VARCHAR), CAST(source.price AS VARCHAR)))
    THEN UPDATE SET
        customer_key   = source.customer_key,
        order_date      = source.order_date,
        shipping_date    = source.shipping_date,
        due_date          = source.due_date,
        sales_amount       = source.sales_amount,
        quantity             = source.quantity,
        price                 = source.price
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (order_number, product_key, customer_key, order_date, shipping_date, due_date, sales_amount, quantity, price)
        VALUES (source.order_number, source.product_key, source.customer_key, source.order_date,
                source.shipping_date, source.due_date, source.sales_amount, source.quantity, source.price)
    OUTPUT $action INTO @merge_output(action_type);

    SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
    SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
    SET @end_time = GETDATE();
    UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
        rows_inserted = @rows_inserted, rows_updated = @rows_updated,
        run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
    WHERE table_name = @current_table AND layer = 'gold';
    PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
    DELETE FROM @merge_output;
    PRINT '-----------------------------------------';

    SET @batch_end_time = GETDATE();
    PRINT '===========================================================================';
    PRINT 'LOADING GOLD LAYER IS COMPLETED';
    PRINT '> Total Load Duration: ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + ' seconds.';
    PRINT '===========================================================================';

END TRY
BEGIN CATCH
    UPDATE dbo.etl_control
    SET last_run_status = 'FAILED', run_started_at = @start_time,
        run_ended_at = GETDATE(), error_message = ERROR_MESSAGE()
    WHERE table_name = @current_table AND layer = 'gold';

    PRINT '===========================================================================';
    PRINT 'ERROR LOADING GOLD LAYER - failed on table: ' + ISNULL(@current_table, '(unknown)');
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT '===========================================================================';
END CATCH
END;
GO
--EXEC gold.load_gold;