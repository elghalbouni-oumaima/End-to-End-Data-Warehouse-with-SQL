/*==============================================================================
  Table: etl_control
  Purpose: Tracks every load run per table - what changed, how long it took,
           whether it succeeded. This is what lets you PROVE the pipeline
           works reliably (great for client demos / portfolio screenshots).
==============================================================================*/
CREATE TABLE etl_control (
    control_id          INT IDENTITY(1,1) PRIMARY KEY,
    table_name          VARCHAR(100)  NOT NULL,
    layer               VARCHAR(20)   NOT NULL,
    last_loaded_date    DATETIME      NULL,
    last_run_status     VARCHAR(20)   NULL,   -- SUCCESS / FAILED
    rows_inserted       INT           NULL,
    rows_updated        INT           NULL,
    error_message       NVARCHAR(MAX) NULL,
    run_started_at      DATETIME      NULL,
    run_ended_at        DATETIME      NULL,
    duration_seconds     AS DATEDIFF(SECOND, run_started_at, run_ended_at)
);
GO

INSERT INTO etl_control (table_name, layer)
VALUES
    ('crm_cust_info',     'silver'),
    ('crm_prd_info',      'silver'),
    ('crm_sales_details', 'silver'),
    ('erp_cust_az12',     'silver'),
    ('erp_loc_a101',      'silver'),
    ('erp_px_cat_g1v2',   'silver');
GO