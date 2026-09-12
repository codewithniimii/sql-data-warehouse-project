/*
===============================================================================
DDL + Load Script: Create Gold Date Dimension
===============================================================================

Purpose:
    Creates and populates gold.dim_date.

    The date dimension covers the full range of dates used in:
        - Order dates
        - Shipping dates
        - Due dates

    This allows gold.fact_sales to use:
        - order_date_key
        - shipping_date_key
        - due_date_key

===============================================================================
*/

USE DataWarehouse;
GO

-- =============================================================================
-- Drop existing date dimension
-- =============================================================================

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO


-- =============================================================================
-- Create Date Dimension
-- =============================================================================

CREATE TABLE gold.dim_date (
    date_key        INT NOT NULL PRIMARY KEY,
    full_date       DATE NOT NULL,

    year_number     INT NOT NULL,
    quarter_number  INT NOT NULL,

    month_number    INT NOT NULL,
    month_name      NVARCHAR(20) NOT NULL,

    day_number      INT NOT NULL,
    day_name        NVARCHAR(20) NOT NULL,

    week_number     INT NOT NULL,
    is_weekend      BIT NOT NULL
);
GO


-- =============================================================================
-- Determine full date range from Sales data
-- =============================================================================

DECLARE @start_date DATE;
DECLARE @end_date DATE;

SELECT
    @start_date = MIN(dt),
    @end_date = MAX(dt)
FROM (
    SELECT sls_order_date AS dt
    FROM silver.crm_sales_details

    UNION ALL

    SELECT sls_ship_date AS dt
    FROM silver.crm_sales_details

    UNION ALL

    SELECT sls_due_date AS dt
    FROM silver.crm_sales_details
) AS all_dates
WHERE dt IS NOT NULL;


-- =============================================================================
-- Generate all dates between start and end date
-- =============================================================================

;WITH DateSeries AS (

    SELECT @start_date AS full_date

    UNION ALL

    SELECT DATEADD(DAY, 1, full_date)
    FROM DateSeries
    WHERE full_date < @end_date
)


-- =============================================================================
-- Load Date Dimension
-- =============================================================================

INSERT INTO gold.dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    month_number,
    month_name,
    day_number,
    day_name,
    week_number,
    is_weekend
)

SELECT
    YEAR(full_date) * 10000
        + MONTH(full_date) * 100
        + DAY(full_date) AS date_key,

    full_date,

    YEAR(full_date) AS year_number,

    DATEPART(QUARTER, full_date) AS quarter_number,

    MONTH(full_date) AS month_number,

    DATENAME(MONTH, full_date) AS month_name,

    DAY(full_date) AS day_number,

    DATENAME(WEEKDAY, full_date) AS day_name,

    DATEPART(ISO_WEEK, full_date) AS week_number,

    CASE
        WHEN DATENAME(WEEKDAY, full_date)
             IN ('Saturday', 'Sunday')
        THEN 1
        ELSE 0
    END AS is_weekend

FROM DateSeries

OPTION (MAXRECURSION 0);
GO


-- =============================================================================
-- Validation
-- =============================================================================

SELECT
    MIN(full_date) AS minimum_date,
    MAX(full_date) AS maximum_date,
    COUNT(*) AS total_dates
FROM gold.dim_date;
GO