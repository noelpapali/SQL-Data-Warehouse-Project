-- data cleansing and inserting into silver layer

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- Loading silver.crm_cust_info
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_created_date)

		SELECT
		cst_id,
		cst_key,
		TRIM(cst_firstname) AS cst_firstname,
		TRIM(cst_lastname) AS cst_lastname,
		CASE WHEN UPPER(TRIM(cst_gndr)) ='S' THEN 'Single'
			 WHEN UPPER((cst_gndr)) ='M' THEN 'Married'
			 ELSE 'N/A'
			 END cst_marital_status,
		CASE WHEN UPPER(TRIM(cst_gndr)) ='F' THEN 'FEMALE'
			 WHEN UPPER((cst_gndr)) ='M' THEN 'MALE'
			 ELSE 'N/A'
			 END cst_gndr,
		cst_created_date
		FROM (
			SELECT *, ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_created_date DESC) as flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
			)t WHERE flag_last =1;
		SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


		--inserting into cust_prd_info
		SET @start_time = GETDATE();
		PRINT '>> truncating table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting table: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_name,
			prd_line,
			prd_cost,
			prd_start_date,
			prd_end_date
			)
		SELECT
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1, 5),'-', '_') AS cat_id,
		SUBSTRING(prd_key, 7, LEN(prd_key)) as prd_key,
		prd_name,
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
			 WHEN 'R' THEN 'Road'
			 WHEN 'S' THEN 'Other sales'
			 WHEN 'T' THEN 'Touring'
			 ELSE 'N/A'
			 END AS prd_line,
		ISNULL(prd_cost, 0) AS prd_cost,
		CAST(prd_start_date AS DATE) AS prd_start_date,
		CAST(LEAD(prd_start_date) OVER(PARTITION BY prd_key ORDER BY prd_start_date)-1 AS DATE) AS prd_end_date --taking the next start as previous end date
		FROM bronze.crm_prd_info;

		SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- inserting sales details
		SET @start_time = GETDATE();
		PRINT '>> truncating table: silver.crm_sale_details';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting table: silver.crm_sale_details';
		INSERT INTO silver.crm_sale_details(
			sls_ord_num,
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
		CASE WHEN sls_order_date = 0 OR LEN(sls_order_date) != 8 THEN NULL
			 ELSE CAST(CAST(sls_order_date AS VARCHAR) AS DATE) 
			 END AS sls_order_date,
		CASE WHEN sls_ship_date = 0 OR LEN(sls_ship_date) != 8 THEN NULL
			 ELSE CAST(CAST(sls_ship_date AS VARCHAR) AS DATE) 
			 END AS sls_ship_date,
		CASE WHEN sls_due_date = 0 OR LEN(sls_due_date) != 8 THEN NULL
			 ELSE CAST(CAST(sls_due_date AS VARCHAR) AS DATE) 
			 END AS sls_ship_date,
		CASE WHEN sls_sales IS NULL or sls_sales<=0 OR sls_sales!= sls_quantity *ABS(sls_price) THEN sls_quantity*ABS(sls_price)
			 ELSE sls_sales
			 END AS sls_sales,
		sls_quantity,
		CASE WHEN sls_price IS NULL or sls_price<=0 THEN sls_sales/NULLIF(sls_quantity, 0)
			 ELSE sls_price
			 END AS sls_price
		FROM bronze.crm_sale_details;
		SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		--insert into erp_cust
		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';
		SET @start_time = GETDATE();
		PRINT '>> truncating table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting table: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12
		(
		cid,
		bdate,
		gen
		)

		SELECT
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4 ,LEN(cid))
			 ELSE cid
			 END AS cid,
		CASE WHEN bdate > GETDATE() THEN NULL
			 ELSE bdate END AS bdate,
		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			 ELSE 'n/a'
			 END AS gen
		FROM bronze.erp_cust_az12;
		 SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


		--insert into erp_loc
		SET @start_time = GETDATE();
		PRINT '>> truncating table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting table: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101
		(
		cid,
		cntry
		)

		SELECT
		REPLACE(cid, '-','') AS cid,
		CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
			 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
			 WHEN TRIM(cntry) ='' OR cntry IS NULL THEN 'n/a'
			 ELSE cntry END AS cntry
		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


		-- insert into silver px_cat_g1v2
		SET @start_time = GETDATE();
		PRINT '>> truncating table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting table: silver.erp_px_cat_g1v2';
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
		FROM bronze.erp_px_cat_g1v2  --no changes in data
		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
		
	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END

EXEC silver.load_silver;