# Gold Layer Data Catalog

## Overview

The Gold layer provides business-ready data for analytical,
reporting, and business intelligence workloads.

The model follows a star-schema design consisting of:

- `gold.fact_sales` — product-level sales transactions
- `gold.dim_customers` — customer attributes
- `gold.dim_products` — product and category attributes
- `gold.dim_date` — calendar attributes

The Gold layer is consumed by Python/Pandas for exploratory and
business analysis and by Power BI for dashboard reporting.

---

## Data Model

                    dim_customers
                         │
                         │ customer_key
                         │
dim_products ─────── fact_sales ─────── dim_date
 product_key                            date_key
                                          │
                                    ┌─────┼─────┐
                                    │     │     │
                                  Order  Ship   Due

`dim_date` acts as a role-playing date dimension and can be used
to analyze order, shipping, and due dates.

---

## 1. gold.dim_customers

**Purpose:** Stores customer attributes enriched with demographic
and geographic information from CRM and ERP source systems.

**Grain:** One row per customer.

| Column | Data Type | Description |
|---|---|---|
| customer_key | INT | Warehouse-generated analytical key identifying the customer in the Gold model. |
| customer_id | INT | Source-system customer identifier. |
| customer_number | NVARCHAR(50) | Business identifier used to reference the customer. |
| first_name | NVARCHAR(50) | Customer first name. |
| last_name | NVARCHAR(50) | Customer last name. |
| country | NVARCHAR(50) | Standardized country associated with the customer. |
| marital_status | NVARCHAR(50) | Standardized customer marital status. |
| gender | NVARCHAR(50) | Standardized customer gender. |
| birthdate | DATE | Customer date of birth. |
| create_date | DATE | Date the customer record was created in the source system. |

**Primary analytical key:** `customer_key`

**Source:** CRM customer data enriched with ERP demographic and
location data.

---

## 2. gold.dim_products

**Purpose:** Provides business-ready product attributes and
product classifications.

**Grain:** One row per current product.

| Column | Data Type | Description |
|---|---|---|
| product_key | INT | Warehouse-generated analytical key identifying the product in the Gold model. |
| product_id | INT | Source-system product identifier. |
| product_number | NVARCHAR(50) | Business identifier for the product. |
| product_name | NVARCHAR(50) | Descriptive product name. |
| category_id | NVARCHAR(50) | Identifier linking the product to its product classification. |
| category | NVARCHAR(50) | High-level product category. |
| subcategory | NVARCHAR(50) | More detailed product classification. |
| maintenance_required | NVARCHAR(50) | Indicates whether maintenance is associated with the product classification. |
| cost | DECIMAL(18,2) | Product cost where available. |
| product_line | NVARCHAR(50) | Standardized product line. |
| start_date | DATE | Date associated with the beginning of the current product record. |

**Primary analytical key:** `product_key`

**Source:** CRM product information enriched with ERP product
category information.

Only current product records are exposed in the Gold dimension.

---

## 3. gold.dim_date

**Purpose:** Provides calendar attributes for time-based analysis.

**Grain:** One row per calendar date.

| Column | Data Type | Description |
|---|---|---|
| date_key | INT | Integer date identifier in YYYYMMDD format. |
| full_date | DATE | Calendar date. |
| year_number | INT | Calendar year. |
| quarter_number | INT | Calendar quarter from 1 to 4. |
| month_number | INT | Calendar month from 1 to 12. |
| month_name | NVARCHAR(20) | Calendar month name. |
| day_number | INT | Day of month. |
| day_name | NVARCHAR(20) | Day of week name. |
| week_number | INT | ISO week number. |
| is_weekend | BIT | Indicates whether the date falls on Saturday or Sunday. |

The date dimension covers the complete range required by order,
shipping, and due dates.

It acts as a **role-playing dimension** for:

- order date
- shipping date
- due date

---

## 4. gold.fact_sales

**Purpose:** Stores sales measures and dimension references for
analytical reporting.

**Grain:** One row represents one product line within a sales order.

| Column | Data Type | Description |
|---|---|---|
| order_number | NVARCHAR(50) | Business identifier for the sales order. Multiple rows may share the same order number. |
| product_key | INT | Analytical key referencing `gold.dim_products`. |
| customer_key | INT | Analytical key referencing `gold.dim_customers`. |
| order_date_key | INT | Date key associated with the order date. |
| shipping_date_key | INT | Date key associated with the shipping date. |
| due_date_key | INT | Date key associated with the due date. |
| order_date | DATE | Date the order was placed. |
| shipping_date | DATE | Date associated with shipment of the order. |
| due_date | DATE | Expected due date associated with the order. |
| sales_amount | DECIMAL(18,2) | Sales value for the individual sales line. |
| quantity | INT | Number of units represented by the sales line. |
| price | DECIMAL(18,2) | Unit price associated with the sales line. |

### Important Metric Definitions

Because `fact_sales` operates at product-line grain:

- **Sales Lines** = number of rows
- **Total Orders** = distinct count of `order_number`
- **Units Sold** = sum of `quantity`
- **Total Revenue** = sum of `sales_amount`

For example, validation of the current dataset identified:

- 60,398 sales lines
- 27,659 distinct orders
- 60,423 units sold
- 0 exact duplicate fact rows
- 0 duplicate `order_number + product_key` combinations

Therefore, row count should **not** be used as the total order count.

---

## Relationships

| From | Key | To | Key | Relationship |
|---|---|---|---|---|
| fact_sales | customer_key | dim_customers | customer_key | Many-to-One |
| fact_sales | product_key | dim_products | product_key | Many-to-One |
| fact_sales | order_date_key | dim_date | date_key | Many-to-One |
| fact_sales | shipping_date_key | dim_date | date_key | Many-to-One |
| fact_sales | due_date_key | dim_date | date_key | Many-to-One |