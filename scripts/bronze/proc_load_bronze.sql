/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.

    It performs the following actions:
    - Truncates the Bronze tables before loading.
    - Loads CSV files using BULK INSERT.
    - Accepts the dataset directory as a parameter.
    - Measures load duration.
    - Uses a transaction so the complete Bronze refresh is rolled back
      if any load fails.

Parameters:
    @data_path NVARCHAR(500)
        Absolute path to the datasets folder.

Usage Example:
    EXEC bronze.load_bronze
        @data_path = 'C:\sql-data-warehouse-project\datasets';

===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze 
@data_path NVARCHAR(500)
AS

BEGIN 
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @start_time DATETIME2,
		@end_time DATETIME2, 
		@batch_start_time DATETIME2, 
		@batch_end_time DATETIME2,
		@file_path NVARCHAR(1000),
        @sql NVARCHAR(MAX);

	IF RIGHT(@data_path, 1) IN ('\', '/')
    SET @data_path = LEFT(@data_path, LEN(@data_path) - 1);

	BEGIN TRY 
	SET @batch_start_time = SYSDATETIME();
	BEGIN TRANSACTION;
		PRINT '=======================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '=======================================================';

		PRINT '-----------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '-----------------------------------------------------';
		
		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.crm_cust_info '
		TRUNCATE TABLE bronze.crm_cust_info;

		PRINT '>> Inserting Data into: bronze.crm_cust_info '
		
		SET @file_path =
         @data_path + '\source_crm\cust_info.csv';

		SET @sql = '
		BULK INSERT bronze.crm_cust_info
		FROM ''' + REPLACE(@file_path, '''', '''''') + '''
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = '','',
			TABLOCK
		);';

		EXEC sys.sp_executesql @sql;

		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.crm_prd_info '
		TRUNCATE TABLE bronze.crm_prd_info;

		PRINT '>> Inserting Data into: bronze.crm_prd_info '
		SET @file_path =
    @data_path + '\source_crm\prd_info.csv';

SET @sql = '
BULK INSERT bronze.crm_prd_info
FROM ''' + REPLACE(@file_path, '''', '''''') + '''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;
		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.crm_sales_details '
		TRUNCATE TABLE bronze.crm_sales_details;

		PRINT '>> Inserting Data into: bronze.crm_sales_details '
		SET @file_path =
    @data_path + '\source_crm\sales_details.csv';

SET @sql = '
BULK INSERT bronze.crm_sales_details
FROM ''' + REPLACE(@file_path, '''', '''''') + '''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

		PRINT '-----------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '-----------------------------------------------------';

		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.erp_loc_a101 '
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT '>> Inserting Data into: bronze.erp_loc_a101 '
		SET @file_path =
    @data_path + '\source_erp\LOC_A101.csv';

	SET @sql = '
	BULK INSERT bronze.erp_loc_a101
	FROM ''' + REPLACE(@file_path, '''', '''''') + '''
	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = '','',
		TABLOCK
	);';

EXEC sys.sp_executesql @sql;

		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.erp_cust_az12'
		TRUNCATE TABLE bronze.erp_cust_az12;

		PRINT '>> Inserting Data into: bronze.erp_cust_az12 '
		SET @file_path =
    @data_path + '\source_erp\CUST_AZ12.csv';

SET @sql = '
BULK INSERT bronze.erp_cust_az12
FROM ''' + REPLACE(@file_path, '''', '''''') + '''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2'
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT '>> Inserting Data into: bronze.erp_px_cat_g1v2 '
		SET @file_path =
    @data_path +  '\source_erp\PX_CAT_G1V2.csv';

SET @sql = '
BULK INSERT bronze.erp_px_cat_g1v2
FROM ''' + REPLACE(@file_path, '''', '''''') + '''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

		SET @end_time = SYSDATETIME();
		PRINT '>>Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>>------------------';

        COMMIT TRANSACTION;
		
		SET @batch_end_time = SYSDATETIME();
		PRINT '============================================='
		PRINT 'Loading Bronze Layer is Completed';
		PRINT '- Total Load Duration: ' + CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '============================================='
	END TRY
	BEGIN CATCH -- CHANGE: undo the whole Bronze refresh if anything fails 

	  IF @@TRANCOUNT > 0 
			ROLLBACK TRANSACTION;
			PRINT '===================================================================='; 
			PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER'; 
			PRINT 'Error Message: ' + ERROR_MESSAGE(); 
			PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR); 
			PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR); 
			PRINT '===================================================================='; 
			THROW;
	END CATCH
END
