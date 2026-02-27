 
CREATE OR ALTER PROCEDURE bronze.load_bronze AS 
DECLARE @end_time DATETIME,@start_time DATETIME, @batch_end_time DATETIME, @batch_start_time DATETIME;
BEGIN

BEGIN TRY

PRINT '===========================================================================';
PRINT 'LOADING BRONZE LAYER ';
PRINT '===========================================================================';

PRINT '---------------------------------------------------------------------------';
PRINT 'LOADING CRM TABLES ';
PRINT '---------------------------------------------------------------------------';
SET @batch_start_time = GETDATE();

SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.crm_cust_info';
TRUNCATE TABLE bronze.crm_cust_info;

PRINT '>> INSERTING TABLE bronze.crm_cust_info';
BULK INSERT bronze.crm_cust_info
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_crm\cust_info.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
PRINT '-----------------------------------------';

SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.crm_prd_info';
TRUNCATE TABLE bronze.crm_prd_info;

PRINT '>> INSERTING TABLE bronze.crm_prd_info';
BULK INSERT bronze.crm_prd_info
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_crm\prd_info.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
PRINT '-----------------------------------------';

SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.crm_sales_details';
TRUNCATE TABLE bronze.crm_sales_details;

PRINT '>> INSERTING TABLE bronze.crm_sales_details';
BULK INSERT bronze.crm_sales_details
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_crm\sales_details.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';


PRINT '---------------------------------------------------------------------------';
PRINT 'LOADING ERP TABLES ';
PRINT '---------------------------------------------------------------------------';

SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.erp_cust_az12';
TRUNCATE TABLE bronze.erp_cust_az12;

PRINT '>> INSERTING TABLE bronze.erp_cust_az12';
BULK INSERT bronze.erp_cust_az12
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_erp\CUST_AZ12.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
PRINT '-----------------------------------------';

SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.erp_loc_a101';
TRUNCATE TABLE bronze.erp_loc_a101;

PRINT '>> INSERTING TABLE bronze.erp_loc_a101';
BULK INSERT bronze.erp_loc_a101
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_erp\LOC_A101.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';
PRINT '-----------------------------------------';
SET @start_time = GETDATE();
PRINT '>> TRUNCATING TABLE bronze.erp_px_cat_g1v2';
TRUNCATE TABLE bronze.erp_px_cat_g1v2;

PRINT '>> INSERTING TABLE bronze.erp_px_cat_g1v2';
BULK INSERT bronze.erp_px_cat_g1v2
FROM 'C:\Users\dell\Desktop\s4-BigData-NLP-JEE\projects\End-to-End-Data-Warehouse-with-SQL\datasets\source_erp\PX_CAT_G1V2.csv'
WITH (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);
SET @end_time = GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + ' seconds.';

SET @batch_end_time = GETDATE();

PRINT '===========================================================================';
PRINT 'LOADING BRONZE LAYER IS COMPLETED ';
PRINT '> Tatal Load Duration :  ' +  CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + ' seconds.';
PRINT '===========================================================================';


END TRY
BEGIN CATCH

	PRINT '===========================================================================';
	PRINT 'ERROR : LOADING BRONZE LAYER! ';
	PRINT 'Error Message :' + ERROR_MESSAGE(); 
	PRINT '===========================================================================';

END CATCH

END;
EXEC  bronze.load_bronze;