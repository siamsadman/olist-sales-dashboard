-- ==========================================
-- OLIST SALES & REVENUE DASHBOARD
-- Fact Table Population
-- Run after 02_load_dimensions.sql
-- ==========================================

-- ==========================================
-- 1. fact_order_items
-- Grain: one row per order line item.
-- Joins through stg_orders and stg_customers to resolve
-- customer_unique_id (not customer_id) for the customer key.
--
-- Note: 775 orders in the raw data have zero corresponding
-- rows in stg_order_items (cancelled/unavailable before
-- fulfillment, or very early lifecycle status). These are
-- naturally excluded here since the fact grain is line item,
-- not order -- no explicit filter needed.
-- ==========================================
INSERT INTO fact_order_items (order_id, order_item_id, product_id, seller_id, customer_unique_id, order_date_key, order_status, price, freight_value)
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    c.customer_unique_id,
    CONVERT(INT, FORMAT(o.order_purchase_timestamp, 'yyyyMMdd')) AS order_date_key,
    o.order_status,
    oi.price,
    oi.freight_value
FROM stg_order_items oi
INNER JOIN stg_orders o     ON oi.order_id = o.order_id
INNER JOIN stg_customers c  ON o.customer_id = c.customer_id;
GO

-- ==========================================
-- 2. fact_payments
-- Grain: one row per payment installment record.
-- Kept as a separate fact table from fact_order_items because
-- payments are captured at the order level (one payment can
-- cover multiple line items, and one order can have multiple
-- payment records), while fact_order_items is at line-item
-- grain. Mixing these grains in one table would double-count
-- revenue. Both facts relate to dim_order, not to each other
-- directly.
-- ==========================================
INSERT INTO fact_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM stg_payments;
GO

-- ==========================================
-- Post-load validation
-- Expected approximate row counts (Olist public dataset):
--   dim_date            ~774
--   dim_customer       ~96,096
--   dim_seller          ~3,095
--   dim_product        ~32,951
--   dim_order          ~99,441
--   fact_order_items  ~112,650
--   fact_payments     ~103,886
-- ==========================================
SELECT 'dim_date' AS tbl, COUNT(*) AS row_count FROM dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_order', COUNT(*) FROM dim_order
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items
UNION ALL SELECT 'fact_payments', COUNT(*) FROM fact_payments;
