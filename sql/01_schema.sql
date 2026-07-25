-- ==========================================
-- OLIST SALES & REVENUE DASHBOARD
-- Star Schema DDL
-- ==========================================
-- Fact tables sit at two grains:
--   fact_order_items  -> one row per order line item
--   fact_payments     -> one row per payment installment record
-- dim_order acts as a bridge dimension between the two facts,
-- avoiding a direct many-to-many relationship between them.
-- ==========================================

-- ==========================================
-- DIMENSION: Date
-- ==========================================
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,           -- format YYYYMMDD
    full_date DATE NOT NULL,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day INT,
    day_name VARCHAR(20),
    week_of_year INT,
    is_weekend BIT,
    year_month VARCHAR(7),              -- e.g. '2018-04', for chronological charting
    is_complete_month BIT               -- flags months with full data (excludes partial final month)
);

-- ==========================================
-- DIMENSION: Customer (deduplicated on real person via customer_unique_id)
-- ==========================================
CREATE TABLE dim_customer (
    customer_unique_id VARCHAR(50) PRIMARY KEY,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),
    customer_zip_prefix VARCHAR(10)
    -- Note: State Full Name and Customer Type (New/Repeat) are added
    -- as calculated columns in Power BI, not in SQL, since they
    -- depend on DAX-level logic (lifetime order counts).
);

-- ==========================================
-- DIMENSION: Seller
-- ==========================================
CREATE TABLE dim_seller (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),
    seller_zip_prefix VARCHAR(10)
);

-- ==========================================
-- DIMENSION: Product
-- ==========================================
CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    category_name_pt VARCHAR(100),
    category_name_en VARCHAR(100),
    product_weight_g DECIMAL(10,2),
    product_length_cm DECIMAL(10,2),
    product_height_cm DECIMAL(10,2),
    product_width_cm DECIMAL(10,2)
);

-- ==========================================
-- DIMENSION: Order (bridge between the two fact tables)
-- ==========================================
CREATE TABLE dim_order (
    order_id VARCHAR(50) PRIMARY KEY,
    order_status VARCHAR(20),
    order_date_key INT REFERENCES dim_date(date_key)
);

-- ==========================================
-- FACT: Order Items (grain = one row per line item)
-- ==========================================
CREATE TABLE fact_order_items (
    order_id VARCHAR(50) REFERENCES dim_order(order_id),
    order_item_id INT,
    product_id VARCHAR(50) REFERENCES dim_product(product_id),
    seller_id VARCHAR(50) REFERENCES dim_seller(seller_id),
    customer_unique_id VARCHAR(50) REFERENCES dim_customer(customer_unique_id),
    order_date_key INT REFERENCES dim_date(date_key),
    order_status VARCHAR(20),
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- ==========================================
-- FACT: Payments (grain = one row per payment installment record)
-- ==========================================
CREATE TABLE fact_payments (
    order_id VARCHAR(50) REFERENCES dim_order(order_id),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);
