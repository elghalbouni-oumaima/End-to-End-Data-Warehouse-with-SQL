/* ============================================================
   GOLD LAYER - STAR SCHEMA IMPLEMENTATION
   Objective:
   - Create analytical views for reporting
   - Implement Star Schema (Dimensions + Fact)
   - Generate surrogate keys
   - Standardize business attributes
============================================================ */


/* ============================================================
   DIMENSION: CUSTOMERS
   View: gold.dim_customers

   Grain:
   One row per customer

   Purpose:
   - Combine CRM and ERP customer data
   - Generate surrogate key (customer_key)
   - Apply gender standardization business rule
   - Prepare clean dimension for analytics layer
============================================================ */

CREATE VIEW gold.dim_customers AS
SELECT 
    -- Surrogate Key generated for dimensional modeling
    ROW_NUMBER() OVER (ORDER BY m.cst_id) AS customer_key,

    -- Natural key from source system
    m.cst_id AS customer_id,

    -- Business identifiers
    m.cst_key AS customer_number,
    m.cst_firstname AS firstname,
    m.cst_lastname AS lastname,
    m.cst_marital_status AS marital_status,

    -- Location enrichment from ERP
    b.cntry AS country,

    -- Gender standardization rule:
    -- If CRM gender is valid, use it
    -- Otherwise fallback to ERP gender
    CASE 
        WHEN m.cst_gndr != 'n/a' 
            THEN m.cst_gndr
        ELSE COALESCE(a.gen, 'n/a') 
    END AS gender,

    -- Additional descriptive attributes
    a.bdate AS birthdate,
    m.cst_create_date AS create_date

FROM silver.crm_cust_info m
LEFT JOIN silver.erp_cust_az12 a
    ON m.cst_key = a.cid
LEFT JOIN silver.erp_loc_a101 b
    ON b.cid = m.cst_key;



/* ============================================================
   DIMENSION: PRODUCTS
   View: gold.dim_products

   Grain:
   One row per ACTIVE product

   Purpose:
   - Enrich product data with category information
   - Generate surrogate product_key
   - Exclude historical/inactive products
   - Prepare product dimension for fact joins
============================================================ */

CREATE VIEW gold.dim_products AS
SELECT 
    -- Surrogate Key for star schema joins
    ROW_NUMBER() OVER (ORDER BY m.prd_start_dt) AS product_key, 

    -- Natural identifiers
    m.prd_id AS product_id,
    m.prd_key AS product_number,

    -- Descriptive attributes
    m.prd_nm AS product_name,
    m.cat_id AS category_id,
    a.cat AS category,
    a.subcat AS subcategory,
    a.maintenance AS maintenance,
    m.prd_cost AS product_cost,
    m.prd_line AS product_line,
    m.prd_start_dt AS product_start_date

FROM silver.crm_prd_info AS m
LEFT JOIN silver.erp_px_cat_g1v2 a
    ON m.cat_id = a.id

-- Business Rule:
-- Keep only active products (exclude historical records)
WHERE m.prd_end_dt IS NULL;



/* ============================================================
   FACT TABLE: SALES
   View: gold.fact_sales

   Grain:
   One row per order line (one product per order)

   Purpose:
   - Capture transactional sales data
   - Link to Customer and Product dimensions
   - Provide measurable metrics for analytics

   Measures:
   - sales_amount
   - quantity
   - price

   Foreign Keys:
   - customer_key → dim_customers
   - product_key → dim_products
============================================================ */

CREATE VIEW gold.fact_sales AS
SELECT 
    -- Degenerate dimension (order number)
    m.sls_ord_num AS order_number,

    -- Foreign Keys to dimensions
    b.product_key,
    a.customer_key,

    -- Date attributes
    m.sls_order_dt AS order_date,
    m.sls_ship_dt AS shipping_date,
    m.sls_due_dt AS due_date,

    -- Measures
    m.sls_sales AS sales_amount,
    m.sls_quantity AS quantity,
    m.sls_price AS price

FROM silver.crm_sales_details m

-- Join to Customer Dimension using natural key
LEFT JOIN gold.dim_customers a
    ON a.customer_id = m.sls_cust_id

-- Join to Product Dimension using business product number
LEFT JOIN gold.dim_products b
    ON b.product_number = m.sls_prd_key;