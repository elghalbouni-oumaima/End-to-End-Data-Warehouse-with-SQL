/*==============================================================================
    GOLD LAYER - STAR SCHEMA TABLES (CORRECTED)
==============================================================================*/

------------------------------------------------------------
-- Drop in dependency order: fact table FIRST (it references
-- every dimension), then dimensions in any order.
------------------------------------------------------------
IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    DROP TABLE gold.fact_sales;
GO

IF OBJECT_ID('gold.dim_customers', 'U') IS NOT NULL
    DROP TABLE gold.dim_customers;
GO

IF OBJECT_ID('gold.dim_products', 'U') IS NOT NULL
    DROP TABLE gold.dim_products;
GO

IF OBJECT_ID('gold.dim_dates', 'U') IS NOT NULL
    DROP TABLE gold.dim_dates;
GO

------------------------------------------------------------
-- Customer Dimension
------------------------------------------------------------
CREATE TABLE gold.dim_customers
(
    customer_key INT IDENTITY(1,1)
        CONSTRAINT PK_dim_customers PRIMARY KEY,

    customer_id INT NOT NULL
        CONSTRAINT UQ_dim_customers_customer_id UNIQUE,

    customer_number NVARCHAR(50) NOT NULL,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    marital_status NVARCHAR(20),
    gender NVARCHAR(20),
    birth_date DATE,
    country NVARCHAR(50),
    created_date DATE,

    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_dim_customers_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NULL
);
GO

------------------------------------------------------------
-- Product Dimension
------------------------------------------------------------
CREATE TABLE gold.dim_products
(
    product_key INT IDENTITY(1,1)
        CONSTRAINT PK_dim_products PRIMARY KEY,

    product_id INT NOT NULL
        CONSTRAINT UQ_dim_products_product_id UNIQUE,

    product_number NVARCHAR(50) NOT NULL,
    product_name NVARCHAR(100),
    category_id NVARCHAR(50),
    category NVARCHAR(50),
    subcategory NVARCHAR(50),
    maintenance NVARCHAR(20),
    product_cost DECIMAL(18,2),
    product_line NVARCHAR(50),
    product_start_date DATE,

    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_dim_products_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NULL
);
GO

------------------------------------------------------------
-- Date Dimension
------------------------------------------------------------
CREATE TABLE gold.dim_dates
(
    date_key            INT PRIMARY KEY,          -- e.g. 20260806
    full_date           DATE NOT NULL UNIQUE,

    day_number          TINYINT NOT NULL,
    day_name            NVARCHAR(20) NOT NULL,
    day_short           CHAR(3) NOT NULL,
    day_of_week         TINYINT NOT NULL,
    day_of_year         SMALLINT NOT NULL,

    week_of_year        TINYINT NOT NULL,

    month_number        TINYINT NOT NULL,
    month_name          NVARCHAR(20) NOT NULL,
    month_short         CHAR(3) NOT NULL,

    quarter_number      TINYINT NOT NULL,
    quarter_name        CHAR(2) NOT NULL,

    year_number          SMALLINT NOT NULL,

    year_month           CHAR(7) NOT NULL,          -- 2026-08
    month_year            CHAR(20) NOT NULL,          -- Aug 2026
    month_year_sort        INT NOT NULL,              -- 202608

    is_weekend            BIT NOT NULL,
    is_business_day         BIT NOT NULL,

    is_month_start            BIT NOT NULL,
    is_month_end                BIT NOT NULL,

    is_quarter_start              BIT NOT NULL,
    is_quarter_end                  BIT NOT NULL,

    is_year_start                     BIT NOT NULL,
    is_year_end                         BIT NOT NULL
);
GO

------------------------------------------------------------
-- Sales Fact
-- order_date / shipping_date / due_date are now surrogate
-- INT keys into dim_dates, matching what the FK constraints
-- actually reference. customer_key / product_key are
-- nullable, matching the LEFT JOIN behavior in load_gold and
-- the "unmatched lookup" checks in the DQ framework.
------------------------------------------------------------
CREATE TABLE gold.fact_sales
(
    sales_key BIGINT IDENTITY(1,1)
        CONSTRAINT PK_fact_sales PRIMARY KEY,

    order_number NVARCHAR(50) NOT NULL,

    customer_key INT NULL,
    product_key  INT NULL,

    order_date_key    INT NULL,
    shipping_date_key INT NULL,
    due_date_key      INT NULL,

    quantity      INT,
    price         DECIMAL(18,2),
    sales_amount  DECIMAL(18,2),

    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_fact_sales_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NULL,

    CONSTRAINT UQ_fact_sales_order_product UNIQUE (order_number, product_key),

    CONSTRAINT FK_fact_sales_customer
        FOREIGN KEY (customer_key) REFERENCES gold.dim_customers(customer_key),

    CONSTRAINT FK_fact_sales_product
        FOREIGN KEY (product_key) REFERENCES gold.dim_products(product_key),

    CONSTRAINT FK_fact_sales_order_date
        FOREIGN KEY (order_date_key) REFERENCES gold.dim_dates(date_key),

    CONSTRAINT FK_fact_sales_shipping_date
        FOREIGN KEY (shipping_date_key) REFERENCES gold.dim_dates(date_key),

    CONSTRAINT FK_fact_sales_due_date
        FOREIGN KEY (due_date_key) REFERENCES gold.dim_dates(date_key)
);
GO

------------------------------------------------------------
-- Indexes (each created once)
------------------------------------------------------------
CREATE INDEX IX_dim_customers_customer_number ON gold.dim_customers(customer_number);
CREATE INDEX IX_fact_sales_order_date_key      ON gold.fact_sales(order_date_key);
CREATE INDEX IX_fact_sales_customer_key         ON gold.fact_sales(customer_key);
CREATE INDEX IX_fact_sales_product_key           ON gold.fact_sales(product_key);
GO