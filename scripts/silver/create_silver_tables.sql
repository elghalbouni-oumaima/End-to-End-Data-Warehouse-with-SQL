/*========================================================
  DDL - Data Definition Language
  This section creates silver layer tables.
========================================================*/

---------------------------------------------------------
-- CRM SOURCE TABLES
---------------------------------------------------------

-- Customer information from CRM system
CREATE TABLE silver.crm_cust_info (
    cst_id INT,
    cst_key NVARCHAR(50),
    cst_firstname NVARCHAR(50),
    cst_lastname NVARCHAR(50),
    cst_marital_status NVARCHAR(50),
    cst_gndr NVARCHAR(50),
    cst_create_date DATE,
    dwh__create_date DATETIME2 DEFAULT GETDATE()
);

---------------------------------------------------------

-- Product information from CRM system
CREATE TABLE silver.crm_prd_info (
    prd_id INT,
    prd_key NVARCHAR(50),
    prd_nm NVARCHAR(50),
    prd_cost FLOAT,
    prd_line NVARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt DATE,
    dwh__create_date DATETIME2 DEFAULT GETDATE()

);

---------------------------------------------------------

-- Sales transaction details from CRM system
DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt DATE,
    sls_ship_dt  DATE,
    sls_due_dt   DATE,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT,    
    dwh__create_date DATETIME2 DEFAULT GETDATE()
);

---------------------------------------------------------
-- ERP SOURCE TABLES
---------------------------------------------------------

-- ERP customer demographic data
DROP TABLE silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid NVARCHAR(50),
    bdate DATE,
    gen NVARCHAR(50),  
    dwh__create_date DATETIME2 DEFAULT GETDATE()

   
);

---------------------------------------------------------

-- ERP customer location data
CREATE TABLE silver.erp_loc_a101 (
    cid NVARCHAR(50),
    cntry NVARCHAR(50),
    dwh__create_date DATETIME2 DEFAULT GETDATE()

);

---------------------------------------------------------

-- ERP product category data

CREATE TABLE silver.erp_px_cat_g1v2 (
    id NVARCHAR(50),
    cat NVARCHAR(50),
    subcat NVARCHAR(50),
    maintenance NVARCHAR(20) ,
    dwh__create_date DATETIME2 DEFAULT GETDATE()

);