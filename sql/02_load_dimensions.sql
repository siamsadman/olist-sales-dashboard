-- ==========================================
-- OLIST SALES & REVENUE DASHBOARD
-- Dimension Table Population
-- Run after 01_schema.sql, and after staging tables (stg_*)
-- have been imported from the raw/cleaned Olist CSVs.
-- Run order matters: dim_date -> dim_customer -> dim_seller
-- -> dim_product -> dim_order (dim_order depends on dim_date).
-- ==========================================

-- ==========================================
-- 1. dim_date
-- Generated dynamically from the actual order date range,
-- so it's reusable if the underlying data range changes.
-- ==========================================
;WITH DateRange AS (
    SELECT MIN(CAST(order_purchase_timestamp AS DATE)) AS start_date,
           MAX(CAST(order_purchase_timestamp AS DATE)) AS end_date
    FROM stg_orders
),
Numbers AS (
    SELECT TOP (DATEDIFF(DAY, (SELECT start_date FROM DateRange), (SELECT end_date FROM DateRange)) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, day, day_name, week_of_year, is_weekend)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))            AS date_key,
    d                                                AS full_date,
    YEAR(d)                                          AS year,
    DATEPART(QUARTER, d)                             AS quarter,
    MONTH(d)                                         AS month,
    DATENAME(MONTH, d)                               AS month_name,
    DAY(d)                                           AS day,
    DATENAME(WEEKDAY, d)                             AS day_name,
    DATEPART(WEEK, d)                                AS week_of_year,
    CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 1 ELSE 0 END AS is_weekend
FROM DateRange
CROSS APPLY (
    SELECT DATEADD(DAY, n, start_date) AS d FROM Numbers
) AS Dates;
GO

-- Add year_month for chronological (non-collapsing) monthly charting in Power BI
ALTER TABLE dim_date ADD year_month VARCHAR(7);
GO
UPDATE dim_date SET year_month = FORMAT(full_date, 'yyyy-MM');
GO

-- Flag complete months only (Olist's final month, Sept 2018, is a partial
-- data extract and is excluded from trend visuals to avoid a misleading
-- "revenue cliff" that doesn't reflect a real business decline)
ALTER TABLE dim_date ADD is_complete_month BIT;
GO
UPDATE dim_date
SET is_complete_month = CASE WHEN full_date <= '2018-08-31' THEN 1 ELSE 0 END;
GO

-- ==========================================
-- 2. dim_customer
-- Deduplicated on customer_unique_id, since raw Olist data
-- assigns a NEW customer_id to every order, even for the same
-- real person. customer_unique_id is the true person-level key.
-- ==========================================
INSERT INTO dim_customer (customer_unique_id, customer_city, customer_state, customer_zip_prefix)
SELECT
    customer_unique_id,
    MAX(customer_city)             AS customer_city,
    MAX(customer_state)            AS customer_state,
    MAX(customer_zip_code_prefix)  AS customer_zip_prefix
FROM stg_customers
GROUP BY customer_unique_id;
GO

-- ==========================================
-- 3. dim_seller
-- ==========================================
INSERT INTO dim_seller (seller_id, seller_city, seller_state, seller_zip_prefix)
SELECT DISTINCT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM stg_sellers;
GO

-- ==========================================
-- 4. dim_product
-- Joined to the category translation table. A handful of
-- categories (including the 'Unknown' placeholder introduced
-- during Python cleaning) were missing from the official Olist
-- translation file and were manually mapped beforehand.
-- ==========================================
INSERT INTO dim_product (product_id, category_name_pt, category_name_en, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM stg_products p
LEFT JOIN stg_category_translation t
    ON p.product_category_name = t.product_category_name;
GO

-- ==========================================
-- 5. dim_order
-- Bridge dimension between fact_order_items and fact_payments,
-- avoiding a direct many-to-many relationship between the two
-- fact tables (order_id is not unique in either).
-- ==========================================
INSERT INTO dim_order (order_id, order_status, order_date_key)
SELECT DISTINCT
    o.order_id,
    o.order_status,
    CONVERT(INT, FORMAT(o.order_purchase_timestamp, 'yyyyMMdd')) AS order_date_key
FROM stg_orders o;
GO
