
/*
    Script to create the DataWarehouse database and its foundational schemas.
    - Creates the 'DataWarehouse' database if it doesn't exist.
    - Creates the following schemas if they don't exist: 
        • bronze  : raw data layer
        • silver  : cleaned/processed data layer
        • gold    : aggregated/business-ready data layer
    Purpose: Sets up a structured environment for ETL processes and analytics.
*/

-- Switch to the master database, which is required for database-level operations
Use master;

-- Check if a database named 'DataWarehouse' already exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    -- If the database does not exist, create it
    CREATE DATABASE DataWarehouse;
END;

-- Switch context to the newly created (or existing) DataWarehouse database
USE DataWarehouse;

-- Check if the schema 'bronze' exists
IF SCHEMA_ID('bronze') IS NULL
BEGIN
    -- If 'bronze' schema does not exist, create it
    EXEC('CREATE SCHEMA bronze');
END;

GO  -- Batch separator, ensures that previous statements are executed before the next block

-- Check if the schema 'silver' exists
IF SCHEMA_ID('silver') IS NULL
BEGIN
    -- If 'silver' schema does not exist, create it
    EXEC('CREATE SCHEMA silver');
END

GO  -- Another batch separator

-- Check if the schema 'gold' exists
IF SCHEMA_ID('gold') IS NULL
BEGIN
    -- If 'gold' schema does not exist, create it
    EXEC('CREATE SCHEMA gold');
END