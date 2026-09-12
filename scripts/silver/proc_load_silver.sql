/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME2, @end_time DATETIME2, @batch_start_time DATETIME2, @batch_end_time DATETIME2; 
    BEGIN TRY
        SET @batch_start_time = SYSDATETIME();
        BEGIN TRANSACTION;
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- Loading silver.crm_cust_info
        SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gender,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'n/a'
			END AS cst_marital_status, -- Normalize marital status values to readable format
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gender, -- Normalize gender values to readable format
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1; -- Select the most recent record per customer
		SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- Loading silver.crm_prd_info
        SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data Into: silver.crm_prd_info';
		

INSERT INTO silver.crm_prd_info(
    prd_id,
	cat_id,
	prd_key,
	prd_name,
	prd_cost,
	prd_line,
	prd_start_date,
	prd_end_date)
SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key,1,5), '-','_') AS cat_id,
	SUBSTRING(prd_key,7, LEN(prd_key)) AS prd_key,
	TRIM(prd_nm) AS prd_name,
	ISNULL(prd_cost, 0) AS prd_cost,
	CASE UPPER(TRIM(prd_line))
	     WHEN 'M' THEN 'Mountain'
    	 WHEN 'R' THEN 'Road'
		 WHEN 'S' THEN 'Other Sales'
	     WHEN 'T' THEN 'Touring' --- THIS IS QUICK FORM OF CASE-WHEN
		 ELSE 'n/a'
    END AS prd_line,
	CAST (prd_start_dt as DATE) AS prd_start_date,
--	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt this doesnt work in new S
	DATEADD(DAY, -1,LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) ) AS prd_end_date

FROM bronze.crm_prd_info
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- Loading crm_sales_details
        SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details(
    sls_order_num,
    sls_prd_key,    
    sls_cust_id,   
    sls_order_date, 
    sls_ship_date,
    sls_due_date,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT 
      sls_ord_num, 
      sls_prd_key,
      sls_cust_id,
      CASE
    WHEN sls_order_dt = 0
      OR LEN(CAST(sls_order_dt AS VARCHAR)) != 8
        THEN NULL
    ELSE TRY_CONVERT(
        DATE,
        CAST(sls_order_dt AS VARCHAR),
        112
    )
END AS sls_order_date,

CASE
    WHEN sls_ship_dt = 0
      OR LEN(CAST(sls_ship_dt AS VARCHAR)) != 8
        THEN NULL
    ELSE TRY_CONVERT(
        DATE,
        CAST(sls_ship_dt AS VARCHAR),
        112
    )
END AS sls_ship_date,

CASE
    WHEN sls_due_dt = 0
      OR LEN(CAST(sls_due_dt AS VARCHAR)) != 8
        THEN NULL
    ELSE TRY_CONVERT(
        DATE,
        CAST(sls_due_dt AS VARCHAR),
        112
    )
END AS sls_due_date,

      CASE
    
    WHEN sls_price IS NOT NULL
         AND sls_price != 0
         AND sls_quantity > 0
    THEN sls_quantity * ABS(sls_price)

    
    WHEN sls_sales IS NOT NULL
         AND sls_sales > 0
    THEN sls_sales

    
    ELSE NULL
END AS sls_sales,

sls_quantity,

CASE
    WHEN sls_price IS NOT NULL
         AND sls_price != 0
    THEN ABS(CAST(sls_price AS DECIMAL(18,2)))

    WHEN sls_sales IS NOT NULL
         AND sls_sales > 0
         AND sls_quantity > 0
    THEN CAST(sls_sales AS DECIMAL(18,2))
         / NULLIF(sls_quantity, 0)

    ELSE NULL
END AS sls_price

       FROM bronze.crm_sales_details

  
        SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';

        -- Loading erp_cust_az12
        SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- Remove 'NAS' prefix if present
				ELSE cid
			END AS cid, 
			CASE
				WHEN bdate > CAST(SYSDATETIME() AS DATE) THEN NULL
				ELSE bdate
			END AS bdate, -- Set future birthdates to NULL
			CASE
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
				ELSE 'n/a'
			END AS gen -- Normalize gender values and handle unknown cases
		FROM bronze.erp_cust_az12;

	    SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- Loading erp_loc_a101
        SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid, 
			CASE
				WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(cntry)
			END AS cntry -- Normalize and Handle missing or blank country codes
		FROM bronze.erp_loc_a101;
	    SET @end_time = SYSDATETIME();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';
		
		-- Loading erp_px_cat_g1v2
		SET @start_time = SYSDATETIME();
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = SYSDATETIME();

		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		COMMIT TRANSACTION;

		SET @batch_end_time = SYSDATETIME();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
		
	END TRY
	BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: '
            + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: '
            + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';

        THROW;

    END CATCH;
END
