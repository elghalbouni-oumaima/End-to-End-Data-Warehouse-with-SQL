/*==============================================================================
    GOLD LAYER - STAR SCHEMA TABLES
    ==============================================================================
    Description:
        Creates the Gold layer dimensional model used for reporting and analytics.

    Tables:
        - dim_customers
        - dim_products
        - fact_sales

    Design Principles:
        - Surrogate keys generated using IDENTITY
        - Business keys stored separately
        - Optimized for analytical workloads
        - Supports incremental loading using MERGE
==============================================================================*/

------------------------------------------------------------
-- Customer Dimension
------------------------------------------------------------

IF OBJECT_ID('gold.dim_customers', 'U') IS NOT NULL
    DROP TABLE gold.dim_customers;
GO

CREATE TABLE gold.dim_customers
(
    customer_key INT IDENTITY(1,1)
        CONSTRAINT PK_dim_customers PRIMARY KEY,

    -- Business Key
    customer_id INT NOT NULL
        CONSTRAINT UQ_dim_customers_customer_id UNIQUE,

    customer_number NVARCHAR(50) NOT NULL,

    -- Customer Attributes
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    marital_status NVARCHAR(20),
    gender NVARCHAR(20),
    birth_date DATE,
    country NVARCHAR(50),

    -- Source Metadata
    created_date DATE,

    -- Audit Columns
    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_dim_customers_created_at DEFAULT SYSUTCDATETIME(),

    updated_at DATETIME2 NULL
);
GO


------------------------------------------------------------
-- Product Dimension
------------------------------------------------------------

IF OBJECT_ID('gold.dim_products', 'U') IS NOT NULL
    DROP TABLE gold.dim_products;
GO

CREATE TABLE gold.dim_products
(
    product_key INT IDENTITY(1,1)
        CONSTRAINT PK_dim_products PRIMARY KEY,

    -- Business Key
    product_id INT NOT NULL
        CONSTRAINT UQ_dim_products_product_id UNIQUE,

    product_number NVARCHAR(50) NOT NULL,

    -- Product Attributes
    product_name NVARCHAR(100),
    category_id NVARCHAR(50),
    category NVARCHAR(50),
    subcategory NVARCHAR(50),
    maintenance NVARCHAR(20),
    product_cost DECIMAL(18,2),
    product_line NVARCHAR(50),
    product_start_date DATE,

    -- Audit Columns
    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_dim_products_created_at DEFAULT SYSUTCDATETIME(),

    updated_at DATETIME2 NULL
);
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO
CREATE TABLE gold.dim_dates
(
    -- Surrogate Key
    date_key            INT PRIMARY KEY,          -- 20260806

    -- Full Date
    full_date           DATE NOT NULL UNIQUE,

    -- Day
    day_number          TINYINT NOT NULL,
    day_name            NVARCHAR(20) NOT NULL,
    day_short           CHAR(3) NOT NULL,
    day_of_week         TINYINT NOT NULL,
    day_of_year         SMALLINT NOT NULL,

    -- Week
    week_of_year        TINYINT NOT NULL,

    -- Month
    month_number        TINYINT NOT NULL,
    month_name          NVARCHAR(20) NOT NULL,
    month_short         CHAR(3) NOT NULL,

    -- Quarter
    quarter_number      TINYINT NOT NULL,
    quarter_name        CHAR(2) NOT NULL,

    -- Year
    year_number         SMALLINT NOT NULL,

    -- Reporting Columns
    year_month          CHAR(7) NOT NULL,         -- 2026-08
    month_year          CHAR(20) NOT NULL,         -- Aug 2026
    month_year_sort     INT NOT NULL,             -- 202608

    -- Flags
    is_weekend          BIT NOT NULL,
    is_business_day     BIT NOT NULL,

    is_month_start      BIT NOT NULL,
    is_month_end        BIT NOT NULL,

    is_quarter_start    BIT NOT NULL,
    is_quarter_end      BIT NOT NULL,

    is_year_start       BIT NOT NULL,
    is_year_end         BIT NOT NULL
);



------------------------------------------------------------
-- Sales Fact
------------------------------------------------------------

IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    DROP TABLE gold.fact_sales;
GO

CREATE TABLE gold.fact_sales
(
    sales_key BIGINT IDENTITY(1,1)
        CONSTRAINT PK_fact_sales PRIMARY KEY,

    -- Degenerate Dimension
    order_number NVARCHAR(50) NOT NULL,

    -- Dimension Keys
    customer_key INT NOT NULL,
    product_key INT NOT NULL,

    -- Dates
    order_date DATE,
    shipping_date DATE,
    due_date DATE,

    -- Measures
    quantity INT,
    price DECIMAL(18,2),
    sales_amount DECIMAL(18,2),

    -- Audit Columns
    created_at DATETIME2 NOT NULL
        CONSTRAINT DF_fact_sales_created_at DEFAULT SYSUTCDATETIME(),

    updated_at DATETIME2 NULL,

    CONSTRAINT FK_fact_sales_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customers(customer_key),

    CONSTRAINT FK_fact_sales_product
        FOREIGN KEY (product_key)
        REFERENCES gold.dim_products(product_key),

    CONSTRAINT FK_fact_sales_order_date
        FOREIGN KEY (order_date_key)
        REFERENCES gold.dim_dates(date_key),

    CONSTRAINT FK_fact_sales_shipping_date
        FOREIGN KEY (shipping_date_key)
        REFERENCES gold.dim_dates(date_key),

    CONSTRAINT FK_fact_sales_due_date
        FOREIGN KEY (due_date_key)
        REFERENCES gold.dim_dates(date_key)
);
GO

CREATE INDEX IX_dim_customers_customer_number
ON gold.dim_customers(customer_number);

CREATE INDEX IX_dim_customers_customer_number
ON gold.dim_customers(customer_number);

CREATE INDEX IX_fact_sales_order_date_key
ON gold.fact_sales(order_date_key);

CREATE INDEX IX_fact_sales_customer_key
ON gold.fact_sales(customer_key);

CREATE INDEX IX_fact_sales_customer_key
ON gold.fact_sales(customer_key);