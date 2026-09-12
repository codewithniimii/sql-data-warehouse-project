/*
===============================================================================
DDL Script: Create Gold Layer Objects
===============================================================================
Script Purpose:
    This script creates the Gold layer objects used for analytics and reporting.

    The Gold layer contains:
        - Customer dimension view
        - Product dimension view
        - Date dimension table
        - Sales fact view

    These objects form a star-schema-style analytical model built from
    cleaned and standardized Silver-layer data.

Usage:
    - Run this script after the Silver layer has been created and loaded.
    - Populate gold.dim_date using load_dim_date.sql.
    - Query the Gold objects directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key, -- Surrogate key
    ci.cst_id                          AS customer_id,
    ci.cst_key                         AS customer_number,
    ci.cst_firstname                   AS first_name,
    ci.cst_lastname                    AS last_name,
    la.cntry                           AS country,
    ci.cst_marital_status              AS marital_status,
    CASE 
        WHEN ci.cst_gender != 'n/a' THEN ci.cst_gender -- CRM is the primary source for gender
        ELSE COALESCE(ca.gen, 'n/a')  			   -- Fallback to ERP data
    END                                AS gender,
    ca.bdate                           AS birthdate,
    ci.cst_create_date                 AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_date, pn.prd_key) AS product_key, -- Surrogate key
    pn.prd_id       AS product_id,
    pn.prd_key      AS product_number,
    pn.prd_name       AS product_name,
    pn.cat_id       AS category_id,
    pc.cat          AS category,
    pc.subcat       AS subcategory,
    pc.maintenance  AS maintenance,
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,
    pn.prd_start_date AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
WHERE pn.prd_end_date IS NULL; -- Filter out all historical data
GO

-- =============================================================================
-- Create Dimension: gold.dim_date
-- =============================================================================
IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

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
-- Create Fact View: gold.fact_sales
-- Grain: one row represents one product line within a sales order
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_order_num AS order_number,
    pr.product_key AS product_key,
    cu.customer_key AS customer_key,

    CASE
        WHEN sd.sls_order_date IS NOT NULL
        THEN YEAR(sd.sls_order_date) * 10000
           + MONTH(sd.sls_order_date) * 100
           + DAY(sd.sls_order_date)
    END AS order_date_key,

    CASE
        WHEN sd.sls_ship_date IS NOT NULL
        THEN YEAR(sd.sls_ship_date) * 10000
           + MONTH(sd.sls_ship_date) * 100
           + DAY(sd.sls_ship_date)
    END AS shipping_date_key,

    CASE
        WHEN sd.sls_due_date IS NOT NULL
        THEN YEAR(sd.sls_due_date) * 10000
           + MONTH(sd.sls_due_date) * 100
           + DAY(sd.sls_due_date)
    END AS due_date_key,

    sd.sls_order_date AS order_date,
    sd.sls_ship_date AS shipping_date,
    sd.sls_due_date AS due_date,

    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price

FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO