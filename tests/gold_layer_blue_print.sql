/* ============================================================
   DATA WAREHOUSE - GOLD LAYER DESIGN BLUEPRINT
   Purpose:
   - Design and validate Dimension tables
   - Validate Fact table grain
   - Ensure referential integrity
   - Perform data quality checks before production load
============================================================ */


/* ============================================================
   DIMENSION: CUSTOMERS (Design Validation)
   Objective:
   - Merge CRM and ERP customer data
   - Standardize gender using fallback logic
   - Validate uniqueness at customer grain
============================================================ */

-- Preview gender resolution logic
-- Business Rule:
-- If CRM gender is NULL or 'n/a', fallback to ERP gender
SELECT DISTINCT cst_gndr, cst_gender, gen
FROM (
    SELECT 
        m.cst_id, 
        m.cst_key, 
        m.cst_gndr,

        CASE 
            WHEN m.cst_gndr IS NULL OR m.cst_gndr = 'n/a'
                THEN a.gen
            ELSE m.cst_gndr
        END AS cst_gender

    FROM silver.crm_cust_info m
    LEFT JOIN silver.erp_cust_az12 a
        ON m.cst_key = a.cid
) T;



/* ============================================================
   CUSTOMER DUPLICATE VALIDATION
   Objective:
   Ensure that joining CRM and ERP does not multiply rows.
   Expected Result:
   Each customer_id should return only one row.
============================================================ */

SELECT 
    m.cst_id,
    COUNT(*) 
FROM silver.crm_cust_info m
LEFT JOIN silver.erp_cust_az12 a
    ON m.cst_key = a.cid
GROUP BY m.cst_id
HAVING COUNT(*) > 1;



/* ============================================================
   FINAL SHAPE OF DIM_CUSTOMERS
   Objective:
   - Rename attributes to business-friendly names
   - Define final structure before CREATE TABLE
   Grain:
   One row per customer
============================================================ */

SELECT 
    m.cst_id        AS customer_id,
    m.cst_key       AS customer_number,
    m.cst_firstname AS firstname,
    m.cst_lastname  AS lastname,
    b.cntry         AS country,

    CASE 
        WHEN m.cst_gndr != 'n/a'
            THEN m.cst_gndr
        ELSE COALESCE(a.gen, 'n/a')
    END AS gender,

    a.bdate         AS birthdate,
    m.cst_create_date AS create_date
FROM silver.crm_cust_info m
LEFT JOIN silver.erp_cust_az12 a
    ON m.cst_key = a.cid
LEFT JOIN silver.erp_loc_a101 b
    ON b.cid = m.cst_key;



/* ============================================================
   DIMENSION: PRODUCTS (Design Validation)
   Objective:
   - Join product master data with category dimension
   - Exclude historical (inactive) products
   Grain:
   One row per active product
============================================================ */

SELECT 
    m.prd_id       AS product_id,
    m.prd_key      AS product_number,
    m.prd_nm       AS product_name,
    a.cat          AS category,
    a.subcat       AS subcategory,
    m.prd_cost     AS product_cost
FROM silver.crm_prd_info m
LEFT JOIN silver.erp_px_cat_g1v2 a
    ON m.cat_id = a.id
WHERE m.prd_end_dt IS NULL;



/* ============================================================
   FACT TABLE VALIDATION - GOLD.FACT_SALES
   Objective:
   - Validate foreign key integrity
   - Validate fact grain
============================================================ */


-- Foreign Key Check:
-- Every fact row must have a matching customer
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers d
    ON d.customer_key = f.customer_key
WHERE d.customer_key IS NULL;


-- Foreign Key Check:
-- Every fact row must have a matching product
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL;



/* ============================================================
   FACT GRAIN VALIDATION
   Objective:
   Confirm modeling assumptions
============================================================ */

-- Validate:
-- Each order should belong to ONE customer
SELECT order_number,
       COUNT(DISTINCT customer_key)
FROM gold.fact_sales
GROUP BY order_number
HAVING COUNT(DISTINCT customer_key) > 1;


-- Validate:
-- Orders can contain multiple products (expected behavior
-- if grain = one row per order line)
SELECT order_number,
       COUNT(DISTINCT product_key)
FROM gold.fact_sales
GROUP BY order_number
HAVING COUNT(DISTINCT product_key) > 1;