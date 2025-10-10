USE Mydatawarehouse;
--check for nulls or duplicates in primary key for crm_cust_info

SELECT * FROM bronze.crm_cust_info;

SELECT cst_id, COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*)>1 OR cst_id IS NULL;

--check for unwanted spaces in strings
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);


--check for iunvalid dates
SELECT
NULLIF(sls_order_date,0) AS sls_order_dt
FROM bronze.crm_sale_details
WHERE sls_order_date<=0 OR LEN(sls_order_date) != 8
OR sls_order_date <19000101 OR sls_order_date > 20500101

--check for invalid date orders
SELECT *
FROM bronze.crm_sale_details
WHERE sls_order_date>sls_ship_date OR sls_ship_date>sls_due_date;

--data inconsistency in sales, qty and price. sales = qty*price
SELECT DISTINCT sls_sales, sls_quantity, sls_price
FROM bronze.crm_sale_details
WHERE sls_sales != sls_price*sls_quantity
OR sls_sales<=0 OR sls_price<=0 OR sls_quantity<=0
OR sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL
ORDER BY sls_sales, sls_price, sls_quantity;



--erp cust
SELECT 
*
FROM bronze.erp_cust_az12
WHERE cid like'%AW00011000%'

SELECT
bdate
FROM bronze.erp_cust_az12
WHERE bdate <'1924-01-01' OR bdate > GETDATE();

SELECT DISTINCT cntry
FROM bronze.erp_loc_a101