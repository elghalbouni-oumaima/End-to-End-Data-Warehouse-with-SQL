/*==============================================================================
  Procedure Name : silver.load_silver
  Layer          : Silver
  Type           : ETL Transformation Procedure
  Description    :
  
  This stored procedure loads and transforms data from the Bronze layer 
  (raw data) into the Silver layer (cleaned and standardized data).

  The procedure applies data cleansing, normalization, deduplication,
  and business rule transformations to CRM and ERP source tables.

  Key Operations Performed:
  - Truncate-and-load strategy to ensure idempotency
  - Removal of duplicate records using ROW_NUMBER()
  - Data standardization (gender, marital status, product line)
  - Null handling and default value replacement
  - Date validation and correction
  - Sales recalculation when inconsistencies are detected
  - String trimming and formatting corrections
  - Basic referential and structural cleanup

  The procedure includes:
  - Execution time tracking for each table
  - Batch duration measurement
  - TRY...CATCH error handling for reliability

  Design Principle:
  The Silver layer represents cleaned, validated, and transformation-ready
  data that serves as the foundation for the Gold (business) layer.

  Execution:
      EXEC silver.load_silver;

  Notes:
  - This procedure follows an idempotent full reload strategy 
    (TRUNCATE + INSERT).
  - Designed for batch ETL processing in a layered data warehouse architecture.
==============================================================================*/ 
CREATE OR ALTER PROCEDURE silver.load_silver AS 
DECLARE @end_time DATETIME,@start_time DATETIME, @batch_end_time DATETIME, @batch_start_time DATETIME;
DECLARE @rows_inserted INT, @rows_updated INT, @current_table VARCHAR(100);
DECLARE @merge_output TABLE (action_type VARCHAR(10));
BEGIN

BEGIN TRY

PRINT '===========================================================================';
PRINT 'LOADING Silver LAYER ';
PRINT '===========================================================================';

PRINT '---------------------------------------------------------------------------';
PRINT 'LOADING CRM TABLES ';
PRINT '---------------------------------------------------------------------------';
SET @batch_start_time = GETDATE();

SET @current_table = 'crm_cust_info';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.crm_cust_info';

;WITH cleansed AS (
	SELECT 
		cst_id, 
		cst_key, 
		TRIM(cst_firstname) AS cst_firstname, 
		TRIM(cst_lastname) AS cst_lastname, 
		CASE UPPER(TRIM(cst_marital_status)) 
			WHEN 'S' THEN 'Single'
			WHEN 'M' THEN 'Married'
			ELSE 'n/a'
		END AS cst_marital_status,-- Normalize marital status values to readable format
		CASE UPPER(TRIM(cst_gndr)) 
			WHEN 'S' THEN 'Female'
			WHEN 'M' THEN 'Male'
			ELSE 'n/a'
		END AS cst_gndr,-- Normalize gender values to readable format
		cst_create_date,
		ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rw
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
)
MERGE INTO silver.crm_cust_info AS target
USING (SELECT * FROM cleansed WHERE rw = 1) AS source
      ON target.cst_id = source.cst_id
WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
        target.cst_key, target.cst_firstname, target.cst_lastname,
        target.cst_marital_status, target.cst_gndr, CAST(target.cst_create_date AS VARCHAR)))
    <> HASHBYTES('SHA2_256', CONCAT_WS('|',
        source.cst_key, source.cst_firstname, source.cst_lastname,
        source.cst_marital_status, source.cst_gndr, CAST(source.cst_create_date AS VARCHAR)))
THEN UPDATE SET
    cst_key = source.cst_key, cst_firstname = source.cst_firstname,
    cst_lastname = source.cst_lastname, cst_marital_status = source.cst_marital_status,
    cst_gndr = source.cst_gndr, cst_create_date = source.cst_create_date
WHEN NOT MATCHED BY TARGET THEN
    INSERT (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
    VALUES (source.cst_id, source.cst_key, source.cst_firstname, source.cst_lastname,
            source.cst_marital_status, source.cst_gndr, source.cst_create_date)
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();
UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';

SET @current_table = 'crm_prd_info';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.crm_prd_info';

;WITH cleansed AS (
    
SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key,1,5),'-','_')AS cat_id, -- Extract category ID
	SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,-- Extract category key
	TRIM(prd_nm) AS prd_nm,
	ISNULL(prd_cost,0) AS prd_cost,
	CASE UPPER(TRIM(prd_line)) 
		WHEN 'S' THEN 'Other Sales'
		WHEN 'M' THEN 'Mountain'
		WHEN 'R' THEN 'Road'
		WHEN 'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,-- Normalize prd_nm values to readable format
	CAST(prd_start_dt AS DATE) AS prd_start_dt ,
	CAST(
		DATEADD(
			DAY,
			-1,
			LEAD(prd_start_dt) 
			OVER (PARTITION BY prd_key ORDER BY prd_start_dt)
		)
	AS DATE) AS prd_end_dt -- - Calculate end date as one day before the next start date
FROM bronze.crm_prd_info
)
MERGE INTO silver.crm_prd_info AS target
USING  cleansed AS source
      ON target.prd_id = source.prd_id
WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
        target.cat_id, target.prd_key, target.prd_nm,
        target.prd_cost, target.prd_line, CAST(target.prd_start_dt AS VARCHAR),CAST(target.prd_end_dt AS VARCHAR)))
    <> HASHBYTES('SHA2_256', CONCAT_WS('|',
        source.cat_id, source.prd_key, source.prd_nm,
        source.prd_cost, source.prd_line, CAST(source.prd_start_dt AS VARCHAR),CAST(source.prd_end_dt AS VARCHAR)))
THEN UPDATE SET
    cat_id = source.cat_id,
    prd_key = source.prd_key, prd_nm = source.prd_nm,
    prd_cost = source.prd_cost, prd_line = source.prd_line,
    prd_start_dt = source.prd_start_dt, prd_end_dt = source.prd_end_dt
WHEN NOT MATCHED BY TARGET THEN
    INSERT (prd_id,cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt , prd_end_dt)
    VALUES (source.prd_id, source.cat_id, source.prd_key, source.prd_nm, source.prd_cost, source.prd_line,source.prd_start_dt ,source.prd_end_dt )
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();
UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';



SET @current_table = 'crm_sales_details';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.crm_sales_details';

;WITH cleansed AS (
    SELECT
 
	TRIM(sls_ord_num) AS sls_ord_num,
	TRIM(sls_prd_key) AS sls_prd_key,
	sls_cust_id,
	CASE 
		WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
		ELSE CAST(CAST (sls_order_dt AS VARCHAR ) AS DATE)
	END AS sls_order_dt,
	CASE 
		WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
		ELSE CAST(CAST (sls_ship_dt AS VARCHAR ) AS DATE)
	END AS sls_ship_dt,
	CASE 
		WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
		ELSE CAST(CAST (sls_due_dt AS VARCHAR ) AS DATE)
	END AS sls_due_dt,
	CASE 
		WHEN sls_sales < 0 OR sls_sales != sls_quantity * ABS(sls_price) OR sls_sales IS NULL  THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE 
		WHEN sls_price < 0 OR sls_price IS NULL  THEN sls_sales / NULLIF(sls_quantity, 0)
		ELSE sls_price
	END AS sls_price
FROM bronze.crm_sales_details)
MERGE INTO silver.crm_sales_details AS target
USING cleansed  AS source
      ON target.sls_prd_key = source.sls_prd_key AND target.sls_ord_num = source.sls_ord_num
WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
        target.sls_cust_id,
        CAST(target.sls_order_dt AS VARCHAR),
		CAST(target.sls_ship_dt AS VARCHAR), CAST(target.sls_due_dt AS VARCHAR),
		target.sls_sales,target.sls_quantity, target.sls_price))
    <> HASHBYTES('SHA2_256', CONCAT_WS('|',
         source.sls_cust_id,
        CAST(source.sls_order_dt AS VARCHAR),
		CAST(source.sls_ship_dt AS VARCHAR),CAST(source.sls_due_dt AS VARCHAR),
		source.sls_sales, source.sls_quantity, source.sls_price))
THEN UPDATE SET
    sls_quantity = source.sls_quantity, sls_sales = source.sls_sales,
    sls_cust_id = source.sls_cust_id, sls_price = source.sls_price,
    sls_order_dt = source.sls_order_dt,
	sls_ship_dt = source.sls_ship_dt, sls_due_dt = source.sls_due_dt
WHEN NOT MATCHED BY TARGET THEN
    INSERT (sls_ord_num, sls_prd_key, sls_cust_id, sls_quantity, sls_sales, sls_price, sls_order_dt, sls_ship_dt, sls_due_dt)
    VALUES (source.sls_ord_num, source.sls_prd_key, source.sls_cust_id, source.sls_quantity, source.sls_sales,
	source.sls_price, source.sls_order_dt, source.sls_ship_dt, source.sls_due_dt)
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();

UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR ) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';


PRINT '---------------------------------------------------------------------------';
PRINT 'LOADING ERP TABLES ';
PRINT '---------------------------------------------------------------------------';

SET @current_table = 'erp_cust_az12';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.erp_cust_az12';

;WITH cleansed AS ( 
SELECT
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
		ELSE cid
	END AS cid,
	CASE 
		WHEN bdate >GETDATE()  THEN NULL
		ELSE bdate
	END AS bdate,
	CASE 
		WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
		WHEN  UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		WHEN TRIM(gen) ='' THEN 'n/a'
		ELSE  'n/a'
	END AS gen
FROM bronze.erp_cust_az12 ) 

MERGE INTO silver.erp_cust_az12 AS target
USING cleansed  AS source
      ON target.cid = source.cid
WHEN MATCHED
AND (
       ISNULL(target.gen,'') <> ISNULL(source.gen,'')
    OR ISNULL(target.bdate,'19000101') <> ISNULL(source.bdate,'19000101')
)
THEN
UPDATE
SET
    gen = source.gen,
    bdate = source.bdate,
    cid = source.cid 
WHEN NOT MATCHED BY TARGET THEN
    INSERT ( gen, cid, bdate)
    VALUES (source.gen, source.cid, source.bdate)
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();

UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';


SET @current_table = 'erp_loc_a101';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.erp_loc_a101';

;WITH cleansed AS (
	SELECT 
	replace(cid,'-','') as cid ,
	CASE 
		WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		WHEN TRIM(cntry) IN ('US','ÚSA') THEN 'United States'
		WHEN TRIM(cntry) = '' OR cntry IS NULL  THEN  'n/a'
		ELSE TRIM(cntry)
	END AS cntry
FROM bronze.erp_loc_a101)

MERGE INTO silver.erp_loc_a101 AS target
USING cleansed AS source
      ON target.cid = source.cid
WHEN MATCHED AND ISNULL(target.cntry,'') <> ISNULL(source.cntry,'')
THEN UPDATE SET cntry = source.cntry
WHEN NOT MATCHED BY TARGET THEN
    INSERT (cid, cntry)
    VALUES (source.cid, source.cntry)
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();

UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';

SET @current_table = 'erp_px_cat_g1v2';
SET @start_time = GETDATE();
PRINT '>> MERGING TABLE silver.erp_px_cat_g1v2';

;WITH cleansed AS (
	SELECT 
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2)
MERGE INTO silver.erp_px_cat_g1v2 AS target
USING cleansed  AS source
      ON target.id = source.id
WHEN MATCHED AND HASHBYTES('SHA2_256', CONCAT_WS('|',
        target.cat, target.subcat,target.maintenance))
    <> HASHBYTES('SHA2_256', CONCAT_WS('|',
         source.cat, source.subcat, source.maintenance))
THEN UPDATE SET
    maintenance = source.maintenance, subcat = source.subcat, cat = source.cat
WHEN NOT MATCHED BY TARGET THEN
    INSERT ( id, cat, maintenance, subcat)
    VALUES (source.id,source.cat, source.maintenance, source.subcat)
OUTPUT $action INTO @merge_output(action_type);

SELECT @rows_inserted = COUNT(*) FROM @merge_output WHERE action_type = 'INSERT';
SELECT @rows_updated  = COUNT(*) FROM @merge_output WHERE action_type = 'UPDATE';
SET @end_time = GETDATE();

UPDATE dbo.etl_control SET last_loaded_date = GETDATE(), last_run_status = 'SUCCESS',
    rows_inserted = @rows_inserted, rows_updated = @rows_updated,
    run_started_at = @start_time, run_ended_at = @end_time, error_message = NULL
WHERE table_name = @current_table AND layer = 'silver';
PRINT '>> Inserted: ' + CAST(@rows_inserted AS VARCHAR) + ' | Updated: ' + CAST(@rows_updated AS VARCHAR);
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
DELETE FROM @merge_output;
PRINT '-----------------------------------------';

SET @batch_end_time = GETDATE();

PRINT '===========================================================================';
PRINT 'LOADING Silver LAYER IS COMPLETED ';
PRINT '> Tatal Load Duration :  ' +  CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + ' seconds.';
PRINT '===========================================================================';


END TRY
BEGIN CATCH

	PRINT '===========================================================================';
	PRINT 'ERROR : LOADING Silver LAYER! ';
	PRINT 'Error Message :' + ERROR_MESSAGE(); 
	PRINT '===========================================================================';

END CATCH

END;
GO
EXEC silver.load_silver;
